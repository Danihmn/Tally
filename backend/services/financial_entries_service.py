import dataclasses
import datetime
import decimal
import uuid

from sqlalchemy.orm import Session

from domain.entities import FinancialEntry
from domain.read_models import (
    FinancialEntryFilters,
    FinancialEntrySummary,
    FinancialEntryTotals,
)
from infra.repositories import financial_entries_repository
from services.common.exceptions import translate_repository_errors
from services.common.mappers import to_entities, to_entity, to_values


@translate_repository_errors
def get_financial_entry_by_id(session: Session, entry_id: uuid.UUID) -> FinancialEntry:
    entry = financial_entries_repository.get_financial_entry_by_id(session, entry_id)
    return to_entity(FinancialEntry, entry)


@translate_repository_errors
def list_financial_entries_by_user(
    session: Session,
    user_id: uuid.UUID,
    reference_month_from: datetime.date | None = None,
    reference_month_to: datetime.date | None = None,
    status: str | None = None,
    bank_account_id: uuid.UUID | None = None,
) -> list[FinancialEntry]:
    entries = financial_entries_repository.list_financial_entries_by_user(
        session,
        user_id,
        reference_month_from,
        reference_month_to,
        status,
        bank_account_id,
    )
    return to_entities(FinancialEntry, entries)


@translate_repository_errors
def list_financial_entries_by_household(
    session: Session,
    household_id: uuid.UUID,
    reference_month_from: datetime.date | None = None,
    reference_month_to: datetime.date | None = None,
    status: str | None = None,
    bank_account_id: uuid.UUID | None = None,
) -> list[FinancialEntry]:
    entries = financial_entries_repository.list_financial_entries_by_household(
        session,
        household_id,
        reference_month_from,
        reference_month_to,
        status,
        bank_account_id,
    )
    return to_entities(FinancialEntry, entries)


@translate_repository_errors
def create_financial_entry(session: Session, entry: FinancialEntry) -> FinancialEntry:
    created = financial_entries_repository.create_financial_entry(
        session, to_values(entry)
    )
    return to_entity(FinancialEntry, created)


@translate_repository_errors
def update_financial_entry(
    session: Session, entry_id: uuid.UUID, entry: FinancialEntry
) -> FinancialEntry:
    """Overwrites every column with the entity's values (id and created_at are kept)."""
    values = to_values(entry, exclude=("id", "created_at"))
    updated = financial_entries_repository.update_financial_entry(
        session, entry_id, values
    )
    return to_entity(FinancialEntry, updated)


@translate_repository_errors
def mark_financial_entries_status(
    session: Session,
    ids: list[uuid.UUID],
    status: str,
    only_from: str | None = None,
) -> None:
    financial_entries_repository.update_financial_entries_status(
        session, ids, status, only_from
    )


@translate_repository_errors
def mark_financial_entry_deleted(
    session: Session, entry_id: uuid.UUID
) -> FinancialEntry:
    entry = financial_entries_repository.soft_delete_financial_entry(session, entry_id)
    return to_entity(FinancialEntry, entry)


@translate_repository_errors
def get_active_financial_entry_by_id(
    session: Session, entry_id: uuid.UUID
) -> FinancialEntry:
    entry = financial_entries_repository.get_active_financial_entry_by_id(
        session, entry_id
    )
    return to_entity(FinancialEntry, entry)


@translate_repository_errors
def search_financial_entries(
    session: Session,
    filters: FinancialEntryFilters,
    limit: int = 50,
    offset: int = 0,
) -> tuple[list[FinancialEntry], int]:
    """A page of entries and the total that match the filters."""
    rows = financial_entries_repository.search_financial_entries(
        session, filters, limit, offset
    )
    total = financial_entries_repository.count_financial_entries(session, filters)
    return to_entities(FinancialEntry, rows), total


# The status decides what is reconciled: the reconciliation job and the undo keep it in sync with
# the `reconciliations` table. CANCELLED entries are in none of the numbers below.
@translate_repository_errors
def get_total_reconciled(
    session: Session, filters: FinancialEntryFilters
) -> decimal.Decimal:
    """Sum of the amounts of the entries already matched with a bank transaction."""
    return financial_entries_repository.sum_financial_entries_amount(
        session, dataclasses.replace(filters, status="RECONCILED")
    )


@translate_repository_errors
def get_total_not_reconciled(
    session: Session, filters: FinancialEntryFilters
) -> decimal.Decimal:
    """Sum of the amounts of the entries still waiting for a bank transaction."""
    return financial_entries_repository.sum_financial_entries_amount(
        session, dataclasses.replace(filters, status="PLANNED")
    )


def get_total_planned(session: Session, filters: FinancialEntryFilters) -> decimal.Decimal:
    """Everything that was planned and not cancelled: reconciled plus not reconciled."""
    return get_total_reconciled(session, filters) + get_total_not_reconciled(
        session, filters
    )


@translate_repository_errors
def count_reconciled_entries(session: Session, filters: FinancialEntryFilters) -> int:
    return financial_entries_repository.count_financial_entries(
        session, dataclasses.replace(filters, status="RECONCILED")
    )


@translate_repository_errors
def count_not_reconciled_entries(
    session: Session, filters: FinancialEntryFilters
) -> int:
    return financial_entries_repository.count_financial_entries(
        session, dataclasses.replace(filters, status="PLANNED")
    )


@translate_repository_errors
def list_upcoming_entries(
    session: Session, filters: FinancialEntryFilters
) -> list[FinancialEntry]:
    """Entries still waiting for a bank transaction (PLANNED), the nearest due date first."""
    entries = financial_entries_repository.list_financial_entries_by_due_date(
        session, dataclasses.replace(filters, status="PLANNED")
    )
    return to_entities(FinancialEntry, entries)


_STATUS_FIELDS = {
    "PLANNED": ("planned_total", "planned_count"),
    "RECONCILED": ("reconciled_total", "reconciled_count"),
    "CANCELLED": ("cancelled_total", "cancelled_count"),
}


@translate_repository_errors
def summarize_financial_entries(
    session: Session, filters: FinancialEntryFilters
) -> FinancialEntrySummary:
    """Totals and counts per type and status of everything the filters match."""
    summary = FinancialEntrySummary()
    for (
        type_,
        status,
        total,
        count,
    ) in financial_entries_repository.summarize_financial_entries(session, filters):
        totals: FinancialEntryTotals | None = {
            "REVENUES": summary.revenues,
            "EXPENSES": summary.expenses,
        }.get(type_)
        fields = _STATUS_FIELDS.get(status)
        if totals is None or fields is None:
            continue
        setattr(totals, fields[0], total)
        setattr(totals, fields[1], count)
    return summary
