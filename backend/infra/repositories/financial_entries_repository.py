import datetime
import decimal
import uuid
from typing import Any

from sqlalchemy import Select, exists, func, select, update
from sqlalchemy.orm import Session

from domain.read_models import FinancialEntryFilters
from infra.database.models import FinancialEntries, Reconciliations
from infra.repositories.common.exceptions import (
    RecordNotFoundError,
    translate_db_errors,
)
from infra.repositories.common.like import ilike_contains

# Ids per UPDATE statement.
_CHUNK_SIZE = 500


@translate_db_errors("financial_entries")
def get_financial_entry_by_id(
    session: Session, entry_id: uuid.UUID
) -> FinancialEntries:
    entry = session.get(FinancialEntries, entry_id)
    if entry is None:
        raise RecordNotFoundError("financial_entries", "get_financial_entry_by_id")
    return entry


@translate_db_errors("financial_entries")
def list_financial_entries_by_user(
    session: Session,
    user_id: uuid.UUID,
    reference_month_from: datetime.date | None = None,  # inclusive
    reference_month_to: datetime.date | None = None,  # exclusive
    status: str | None = None,
    bank_account_id: uuid.UUID | None = None,
) -> list[FinancialEntries]:
    """Entries that were not soft deleted, with no pagination (few rows per user)."""
    stmt = (
        select(FinancialEntries)
        .where(FinancialEntries.user_id == user_id)
        .where(FinancialEntries.deleted_at.is_(None))
    )
    if reference_month_from is not None:
        stmt = stmt.where(FinancialEntries.reference_month >= reference_month_from)
    if reference_month_to is not None:
        stmt = stmt.where(FinancialEntries.reference_month < reference_month_to)
    if status is not None:
        stmt = stmt.where(FinancialEntries.status == status)
    if bank_account_id is not None:
        stmt = stmt.where(FinancialEntries.bank_account_id == bank_account_id)
    stmt = stmt.order_by(
        FinancialEntries.reference_month,
        FinancialEntries.due_date,
        FinancialEntries.id,
    )
    return list(session.scalars(stmt).all())


@translate_db_errors("financial_entries")
def list_financial_entries_by_household(
    session: Session,
    household_id: uuid.UUID,
    reference_month_from: datetime.date | None = None,  # inclusive
    reference_month_to: datetime.date | None = None,  # exclusive
    status: str | None = None,
    bank_account_id: uuid.UUID | None = None,
) -> list[FinancialEntries]:
    """Entries of the whole household that were not soft deleted, with no pagination."""
    stmt = (
        select(FinancialEntries)
        .where(FinancialEntries.household_id == household_id)
        .where(FinancialEntries.deleted_at.is_(None))
    )
    if reference_month_from is not None:
        stmt = stmt.where(FinancialEntries.reference_month >= reference_month_from)
    if reference_month_to is not None:
        stmt = stmt.where(FinancialEntries.reference_month < reference_month_to)
    if status is not None:
        stmt = stmt.where(FinancialEntries.status == status)
    if bank_account_id is not None:
        stmt = stmt.where(FinancialEntries.bank_account_id == bank_account_id)
    stmt = stmt.order_by(
        FinancialEntries.reference_month,
        FinancialEntries.due_date,
        FinancialEntries.id,
    )
    return list(session.scalars(stmt).all())


@translate_db_errors("financial_entries")
def create_financial_entry(
    session: Session, values: dict[str, Any]
) -> FinancialEntries:
    """`values` uses FinancialEntries column names."""
    entry = FinancialEntries(**values)
    session.add(entry)
    session.flush()
    return entry


@translate_db_errors("financial_entries")
def update_financial_entry(
    session: Session, entry_id: uuid.UUID, values: dict[str, Any]
) -> FinancialEntries:
    """Sets only the given columns. `values` uses FinancialEntries column names."""
    entry = get_financial_entry_by_id(session, entry_id)
    for key, value in values.items():
        setattr(entry, key, value)
    entry.updated_at = datetime.datetime.now(datetime.UTC)
    session.flush()
    return entry


@translate_db_errors("financial_entries")
def update_financial_entries_status(
    session: Session,
    ids: list[uuid.UUID],
    status: str,
    only_from: str | None = None,
) -> None:
    """`only_from`: touch only the entries currently in this status (others are left as they are)."""
    now = datetime.datetime.now(datetime.UTC)
    for start in range(0, len(ids), _CHUNK_SIZE):
        chunk = ids[start : start + _CHUNK_SIZE]
        stmt = update(FinancialEntries).where(FinancialEntries.id.in_(chunk))
        if only_from is not None:
            stmt = stmt.where(FinancialEntries.status == only_from)
        session.execute(stmt.values(status=status, updated_at=now))


@translate_db_errors("financial_entries")
def soft_delete_financial_entry(
    session: Session, entry_id: uuid.UUID
) -> FinancialEntries:
    entry = get_financial_entry_by_id(session, entry_id)
    now = datetime.datetime.now(datetime.UTC)
    entry.deleted_at = now
    entry.updated_at = now
    session.flush()
    return entry


def _apply_search_filters(stmt: Select, filters: FinancialEntryFilters) -> Select:
    stmt = stmt.where(FinancialEntries.deleted_at.is_(None))
    if filters.household_id is not None:
        stmt = stmt.where(FinancialEntries.household_id == filters.household_id)
    if filters.user_id is not None:
        stmt = stmt.where(FinancialEntries.user_id == filters.user_id)
    if filters.bank_account_id is not None:
        stmt = stmt.where(FinancialEntries.bank_account_id == filters.bank_account_id)
    if filters.type is not None:
        stmt = stmt.where(FinancialEntries.type == filters.type)
    if filters.payment_type is not None:
        stmt = stmt.where(FinancialEntries.payment_type == filters.payment_type)
    if filters.status is not None:
        stmt = stmt.where(FinancialEntries.status == filters.status)
    if filters.category is not None:
        stmt = stmt.where(FinancialEntries.category == filters.category)
    if filters.search:
        stmt = stmt.where(ilike_contains(FinancialEntries.description, filters.search))
    if filters.reference_month_from is not None:
        stmt = stmt.where(
            FinancialEntries.reference_month >= filters.reference_month_from
        )
    if filters.reference_month_to is not None:
        stmt = stmt.where(
            FinancialEntries.reference_month <= filters.reference_month_to
        )
    if filters.due_date_from is not None:
        stmt = stmt.where(FinancialEntries.due_date >= filters.due_date_from)
    if filters.due_date_to is not None:
        stmt = stmt.where(FinancialEntries.due_date <= filters.due_date_to)
    if filters.min_amount is not None:
        stmt = stmt.where(FinancialEntries.amount >= filters.min_amount)
    if filters.max_amount is not None:
        stmt = stmt.where(FinancialEntries.amount <= filters.max_amount)
    if filters.transaction_id is not None:
        stmt = stmt.where(
            exists(
                select(Reconciliations.id).where(
                    Reconciliations.financial_entry_id == FinancialEntries.id,
                    Reconciliations.transaction_id == filters.transaction_id,
                    Reconciliations.deleted_at.is_(None),
                )
            )
        )
    return stmt


@translate_db_errors("financial_entries")
def search_financial_entries(
    session: Session,
    filters: FinancialEntryFilters,
    limit: int = 50,
    offset: int = 0,
) -> list[FinancialEntries]:
    """Filtered page of entries that were not soft deleted (newest month first)."""
    stmt = _apply_search_filters(select(FinancialEntries), filters)
    stmt = (
        stmt
        .order_by(
            FinancialEntries.reference_month.desc(),
            FinancialEntries.due_date,
            FinancialEntries.id,
        )
        .limit(limit)
        .offset(offset)
    )
    return list(session.scalars(stmt).all())


@translate_db_errors("financial_entries")
def count_financial_entries(session: Session, filters: FinancialEntryFilters) -> int:
    stmt = _apply_search_filters(select(func.count(FinancialEntries.id)), filters)
    return session.scalar(stmt) or 0


@translate_db_errors("financial_entries")
def list_financial_entries_by_due_date(
    session: Session, filters: FinancialEntryFilters
) -> list[FinancialEntries]:
    """Every entry the filters match (no pagination), the nearest due date first."""
    stmt = _apply_search_filters(select(FinancialEntries), filters).order_by(
        FinancialEntries.due_date, FinancialEntries.id
    )
    return list(session.scalars(stmt).all())


@translate_db_errors("financial_entries")
def sum_financial_entries_amount(
    session: Session, filters: FinancialEntryFilters
) -> decimal.Decimal:
    """Sum of amount of everything the filters match (0 when nothing matches)."""
    stmt = _apply_search_filters(
        select(func.coalesce(func.sum(FinancialEntries.amount), 0)), filters
    )
    return session.scalar(stmt) or decimal.Decimal("0.00")


@translate_db_errors("financial_entries")
def summarize_financial_entries(
    session: Session, filters: FinancialEntryFilters
) -> list[tuple[str, str, decimal.Decimal, int]]:
    """(type, status, sum of amount, count) per type and status, over everything the filters match."""
    stmt = _apply_search_filters(
        select(
            FinancialEntries.type,
            FinancialEntries.status,
            func.coalesce(func.sum(FinancialEntries.amount), 0),
            func.count(FinancialEntries.id),
        ),
        filters,
    ).group_by(FinancialEntries.type, FinancialEntries.status)
    return [
        (type_, status, total, count)
        for type_, status, total, count in session.execute(stmt)
    ]


@translate_db_errors("financial_entries")
def get_active_financial_entry_by_id(
    session: Session, entry_id: uuid.UUID
) -> FinancialEntries:
    """Like get_financial_entry_by_id, but a soft deleted entry counts as not found."""
    entry = session.get(FinancialEntries, entry_id)
    if entry is None or entry.deleted_at is not None:
        raise RecordNotFoundError(
            "financial_entries", "get_active_financial_entry_by_id"
        )
    return entry
