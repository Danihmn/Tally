import logging
import uuid

from sqlalchemy.orm import Session

from domain.internal_transfers import find_same_person_pairs
from infra.database.session import get_session
from services.bank_accounts_service import list_bank_accounts_by_user
from services.common.exceptions import ServiceError
from services.transactions_service import (
    list_unclassified_transactions,
    mark_internal_transfer,
)
from services.users_service import list_users_by_household
from utils.ids import require_id

logger = logging.getLogger(__name__)

SAME_PERSON = "SAME_PERSON"
AUTO = "AUTO"


def _classificate_same_person(session: Session, user_id: uuid.UUID) -> int:
    """Marks the transfers between two bank accounts of the user. Returns how many
    transactions were marked (two for each transfer)."""
    accounts = list_bank_accounts_by_user(session, user_id)
    if len(accounts) < 2:
        return 0  # A transfer needs two accounts

    account_ids = [require_id(account, "Bank account") for account in accounts]
    transactions = list_unclassified_transactions(session, account_ids)

    ids = [
        require_id(transaction, "Transaction")
        for pair in find_same_person_pairs(transactions)
        for transaction in pair
    ]
    return mark_internal_transfer(session, ids, SAME_PERSON, AUTO)


def classificate_internal_transfers(session: Session, household_id: uuid.UUID) -> int:
    """Classifies the transfers of the household. Does not commit: the caller does.

    Returns how many transactions were marked."""
    marked = 0
    for person in list_users_by_household(session, household_id):
        marked += _classificate_same_person(session, require_id(person, "User"))
    return marked


def launch_internal_transfers_classification(household_id: uuid.UUID) -> None:
    """Runs the classification in its own session, after the sync was committed.

    It never raises: a failure here must not break the sync that called it."""
    with get_session() as session:
        try:
            marked = classificate_internal_transfers(session, household_id)
            session.commit()
        except ServiceError, ValueError:
            session.rollback()
            logger.exception(
                "Internal transfers classification failed for household %s",
                household_id,
            )
            return

    logger.info(
        "Internal transfers of household %s: %s transactions marked",
        household_id,
        marked,
    )
