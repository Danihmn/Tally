"""Finds recurrence candidates in the household's transactions and creates the confirmed ones.

The rules are in `domain/recurrence_detection.py`; this module only reads what they need."""

import datetime
import uuid

from dateutil.relativedelta import relativedelta
from sqlalchemy.orm import Session

from domain.entities import Recurrence
from domain.read_models import (
    RecurrenceFilters,
    TransactionFilters,
    TransactionWithOwner,
)
from domain.recurrence_detection import (
    DetectionSettings,
    RecurrenceCandidate,
    detect_recurrences,
)
from services.bank_accounts_service import search_bank_accounts
from services.common.exceptions import NotFoundError, translate_repository_errors
from services.recurrences_service import create_recurrence, search_recurrences
from services.transactions_service import search_transactions
from utils.dates import end_of_day_utc, start_of_day_utc

# How far back the transactions are read
LOOKBACK_MONTHS = 12
PAGE_SIZE = 500
# A safety cap: two people do not have this many transactions in a year
MAX_TRANSACTIONS = 20_000
# A household has few accounts and recurrences: read them all in one page
ACCOUNTS_LIMIT = 500
RECURRENCES_LIMIT = 500


def _load_transactions(
    session: Session, filters: TransactionFilters
) -> list[TransactionWithOwner]:
    """Every transaction of the filters, page by page (the search returns one page)."""
    items: list[TransactionWithOwner] = []
    while len(items) < MAX_TRANSACTIONS:
        page, total = search_transactions(
            session, filters, limit=PAGE_SIZE, offset=len(items)
        )
        items.extend(page)
        if not page or len(items) >= total:
            break
    return items


@translate_repository_errors
def find_recurrence_candidates(
    session: Session,
    household_id: uuid.UUID,
    today: datetime.date,
    user_id: uuid.UUID | None = None,
    settings: DetectionSettings | None = None,
) -> list[RecurrenceCandidate]:
    """The monthly patterns of the household that are not a recurrence yet, best first.

    The whole household is always analysed (the internal transfers between the couple need
    both sides); `user_id` keeps only that person's candidates."""
    filters = TransactionFilters(
        household_id=household_id,
        status="POSTED",
        exclude_internal_transfers=True,
        date_from=start_of_day_utc(today - relativedelta(months=LOOKBACK_MONTHS)),
        date_to=end_of_day_utc(today),
    )
    transactions = _load_transactions(session, filters)
    accounts = search_bank_accounts(
        session, household_id=household_id, limit=ACCOUNTS_LIMIT
    )
    existing, _ = search_recurrences(
        session,
        RecurrenceFilters(household_id=household_id, status="ACTIVE"),
        limit=RECURRENCES_LIMIT,
    )

    candidates = detect_recurrences(
        transactions,
        today,
        owner_by_account={
            a.account.id: a.user_id for a in accounts if a.account.id is not None
        },
        credit_card_accounts={
            a.account.id for a in accounts if a.account.type == "CREDIT"
        },  # type: ignore[misc]
        existing=existing,
        settings=settings,
    )
    if user_id is not None:
        candidates = [c for c in candidates if c.user_id == user_id]
    return candidates


@translate_repository_errors
def create_recurrence_from_candidate(
    session: Session,
    household_id: uuid.UUID,
    candidate_id: str,
    today: datetime.date,
) -> Recurrence:
    """Creates the recurrence of a current candidate of the household (source AI).

    The detection runs again, so nothing comes from the caller but the id. Raises NotFoundError
    when the id is not a candidate any more (it may already be a recurrence)."""
    candidates = find_recurrence_candidates(session, household_id, today)
    candidate = next((c for c in candidates if c.candidate_id == candidate_id), None)
    if candidate is None:
        raise NotFoundError("Recurrence candidate not found")
    return create_recurrence(session, candidate.to_recurrence())
