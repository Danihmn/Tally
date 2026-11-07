import datetime
import logging
import uuid

from dateutil.relativedelta import relativedelta
from sqlalchemy.orm import Session

from domain.entities import FinancialEntry, Reconciliation, Transaction
from domain.read_models import TransactionFilters
from domain.reconciliation_matching import find_matches
from infra.database.session import get_session
from services.exceptions import ServiceError
from services.financial_entries_service import (
    list_financial_entries_by_user,
    mark_financial_entries_status,
)
from services.reconciliations_service import (
    create_reconciliation,
    list_reconciliations_by_transactions,
)
from services.transactions_service import search_transactions

logger = logging.getLogger(__name__)

_MONTHS_WINDOW = 2
_TRANSACTIONS_PAGE_SIZE = 200


def _window_start() -> datetime.date:
    """First day of the month, _MONTHS_WINDOW months ago (UTC). Used by both loaders."""
    today = datetime.datetime.now(datetime.UTC).date()
    return today.replace(day=1) - relativedelta(months=_MONTHS_WINDOW)


def _load_transactions(
    session: Session, user_id: uuid.UUID, window_start: datetime.date
) -> list[Transaction]:
    """Every POSTED transaction of the user since the window start (all pages)."""
    filters = TransactionFilters(
        user_id=user_id,
        date_from=datetime.datetime.combine(
            window_start, datetime.time.min, tzinfo=datetime.UTC
        ),
        status="POSTED",
    )

    transactions: list[Transaction] = []
    offset = 0
    while True:
        page, total = search_transactions(
            session, filters, limit=_TRANSACTIONS_PAGE_SIZE, offset=offset
        )
        transactions.extend(item.transaction for item in page)

        offset += _TRANSACTIONS_PAGE_SIZE
        if not page or offset >= total:
            break

    return transactions


def _load_financial_entries(
    session: Session, user_id: uuid.UUID, window_start: datetime.date
) -> list[FinancialEntry]:
    """Entries still waiting for a bank transaction, since the window start."""
    return list_financial_entries_by_user(
        session,
        user_id,
        reference_month_from=window_start,
        status="PLANNED",
    )


def _without_reconciled(
    session: Session, transactions: list[Transaction]
) -> list[Transaction]:
    """Drops the transactions that already have an active reconciliation."""
    ids = [t.id for t in transactions if t.id is not None]
    used = {
        r.transaction_id for r in list_reconciliations_by_transactions(session, ids)
    }
    return [t for t in transactions if t.id not in used]


def reconciliate_financial_entries(user_id: uuid.UUID) -> None:
    """
    Pairs PLANNED financial entries with POSTED bank transactions.

    Only unambiguous matches (same amount, type, account and date within the
    tolerance, one candidate on each side) are reconciled: a row is added to
    `reconciliations` (source AUTO) and the entry becomes RECONCILED.
    Everything else stays PLANNED, to be handled by the AI agent.
    """
    with get_session() as session:
        try:
            window_start = _window_start()
            entries = _load_financial_entries(session, user_id, window_start)
            if not entries:
                return

            transactions = _without_reconciled(
                session, _load_transactions(session, user_id, window_start)
            )
            pairs = find_matches(entries, transactions)
            if not pairs:
                return

            for entry, transaction in pairs:
                if entry.id is None or transaction.id is None:
                    continue
                create_reconciliation(
                    session,
                    Reconciliation(
                        financial_entry_id=entry.id,
                        transaction_id=transaction.id,
                        source="AUTO",
                    ),
                )

            mark_financial_entries_status(
                session,
                [entry.id for entry, _ in pairs if entry.id is not None],
                "RECONCILED",
            )
            session.commit()
        except ServiceError:
            # Nothing is half-written: the whole run is undone
            session.rollback()
            logger.exception("Reconciliation job failed for user %s", user_id)
