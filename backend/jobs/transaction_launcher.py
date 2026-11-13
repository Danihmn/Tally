import logging
import uuid
from datetime import UTC, date, datetime

from dateutil.relativedelta import relativedelta
from sqlalchemy.orm import Session

from domain.entities import Transaction, User
from infra.database.session import get_session
from integrations.pluggy.exceptions.pluggy_exception_error import PluggyExceptionError
from integrations.pluggy.http_clients.account.account_client import get_all_accounts
from integrations.pluggy.http_clients.transaction.transaction_client import (
    get_all_transactions,
)
from integrations.pluggy.schemas.base_error_schema import BaseErrorSchema
from jobs._common import JOB_ERRORS
from jobs.reconciliation_registration import reconciliate_financial_entries
from jobs.transaction_internal_transfers_classification import (
    launch_internal_transfers_classification,
)
from services.bank_accounts_sync_service import sync_bank_account
from services.common.exceptions import ServiceError
from services.pluggy_auth_service import authenticate_user
from services.pluggy_items_service import (
    list_pluggy_items_by_user,
    update_pluggy_item_sync_info,
)
from services.transactions_sync_service import (
    sync_account_transactions,
    to_transaction_entity,
)
from services.users_service import get_user_by_id
from utils.dates import start_of_day_utc
from utils.ids import require_id

logger = logging.getLogger(__name__)


def _sync_user_transactions(session: Session, user: User) -> None:
    user_id = require_id(user, "User")

    api_key = authenticate_user(user)
    pluggy_items = list_pluggy_items_by_user(session, user_id)

    for pluggy_item in pluggy_items:
        try:
            item_id = require_id(pluggy_item, "Pluggy item")

            # Both BANK and CREDIT accounts: the transactions logic is the same
            accounts = get_all_accounts(api_key, str(pluggy_item.pluggy_item_id))
            for account in accounts.results:
                # Our own pluggy_items id, not Pluggy's item id
                stored_account, _ = sync_bank_account(
                    session, item_id, account, user.household_id
                )
                account_id = require_id(stored_account, "Bank account")

                next = None  # Pluggy's pagination approach
                date_from = date.today() - relativedelta(
                    days=1, months=6
                )  # Last 6 months (and D-1, recommended by Pluggy)
                incoming: list[Transaction] = []
                seen_cursors: set[str] = set()
                seen_ids: set[str] = set()
                while True:
                    transactions_response = get_all_transactions(
                        api_key,
                        account.id,
                        date_from=date_from.strftime("%Y-%m-%d"),  # 'yyyy-mm-dd' format
                        next=next,
                    )
                    incoming.extend(
                        to_transaction_entity(
                            t, account_id, stored_account.household_id
                        )
                        for t in transactions_response.results
                    )

                    next = transactions_response.next
                    if not next:
                        break

                    # No page limit (a busy account can have many pages): only a cursor that does
                    # not advance is an error. Syncing a partial list would mark the missing
                    # transactions as deleted, so the account is skipped instead
                    page_ids = {t.id for t in transactions_response.results}
                    if next in seen_cursors or (page_ids and page_ids <= seen_ids):
                        raise PluggyExceptionError(
                            BaseErrorSchema.model_validate({
                                "code": 0,
                                "codeDescription": "PAGINATION_NOT_ADVANCING",
                                "message": f"Pagination of account {account.id} is not advancing",
                            })
                        )
                    seen_cursors.add(next)
                    seen_ids |= page_ids

                sync_account_transactions(
                    session,
                    account_id,
                    incoming,
                    start_of_day_utc(date_from),
                )
        except PluggyExceptionError:
            logger.warning(
                "Pluggy error on item %s, skipping it",
                pluggy_item.pluggy_item_id,
                exc_info=True,
            )
            return

        update_pluggy_item_sync_info(
            session, pluggy_item.pluggy_item_id, datetime.now(UTC), None
        )


def _sync_and_commit_user(session: Session, user: User) -> None:
    try:
        _sync_user_transactions(session, user)
        session.commit()
    except JOB_ERRORS:
        # One user failing must not stop the others
        session.rollback()
        logger.exception("Transactions job failed for user %s", user.id)
        return

    # Once per user and only after the commit: the job opens its own session, so it only sees
    # the transactions that are already committed
    if user.id is not None:
        reconciliate_financial_entries(user.id)
    launch_internal_transfers_classification(user.household_id)


def launch_user_transactions(user_id: uuid.UUID) -> None:
    """Syncs a single user. Opens its own session: it runs after the request's session is closed"""
    with get_session() as session:
        try:
            user = get_user_by_id(session, user_id)
        except ServiceError:
            logger.exception("Transactions job could not load user %s", user_id)
            return

        _sync_and_commit_user(session, user)
