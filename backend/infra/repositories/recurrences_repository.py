import uuid
from typing import Any

from sqlalchemy import Select, func, select
from sqlalchemy.orm import Session

from domain.read_models import RecurrenceFilters
from infra.database.models import Recurrences
from infra.repositories.common.exceptions import (
    RecordNotFoundError,
    translate_db_errors,
)


def _apply_filters(stmt: Select, filters: RecurrenceFilters) -> Select:
    stmt = stmt.where(Recurrences.deleted_at.is_(None))
    if filters.household_id is not None:
        stmt = stmt.where(Recurrences.household_id == filters.household_id)
    if filters.user_id is not None:
        stmt = stmt.where(Recurrences.user_id == filters.user_id)
    if filters.type is not None:
        stmt = stmt.where(Recurrences.type == filters.type)
    if filters.payment_type is not None:
        stmt = stmt.where(Recurrences.payment_type == filters.payment_type)
    if filters.category is not None:
        stmt = stmt.where(Recurrences.category == filters.category)
    if filters.min_amount is not None:
        stmt = stmt.where(Recurrences.amount >= filters.min_amount)
    if filters.max_amount is not None:
        stmt = stmt.where(Recurrences.amount <= filters.max_amount)
    return stmt


@translate_db_errors("recurrences")
def get_recurrence_by_id(session: Session, recurrence_id: uuid.UUID) -> Recurrences:
    """A recurrence that was not soft deleted."""
    recurrence = session.get(Recurrences, recurrence_id)
    if recurrence is None or recurrence.deleted_at is not None:
        raise RecordNotFoundError("recurrences", "get_recurrence_by_id")
    return recurrence


@translate_db_errors("recurrences")
def search_recurrences(
    session: Session,
    filters: RecurrenceFilters,
    limit: int = 50,
    offset: int = 0,
) -> list[Recurrences]:
    stmt = _apply_filters(select(Recurrences), filters)
    stmt = (
        stmt.order_by(Recurrences.created_at.desc(), Recurrences.id)
        .limit(limit)
        .offset(offset)
    )
    return list(session.scalars(stmt).all())


@translate_db_errors("recurrences")
def list_recurrences_by_household(
    session: Session, household_id: uuid.UUID
) -> list[Recurrences]:
    """Every recurrence of the household that was not soft deleted, with no pagination (few rows)."""
    stmt = (
        select(Recurrences)
        .where(Recurrences.household_id == household_id)
        .where(Recurrences.deleted_at.is_(None))
        .order_by(Recurrences.created_at, Recurrences.id)
    )
    return list(session.scalars(stmt).all())


@translate_db_errors("recurrences")
def count_recurrences(session: Session, filters: RecurrenceFilters) -> int:
    stmt = _apply_filters(select(func.count(Recurrences.id)), filters)
    return session.scalar(stmt) or 0


@translate_db_errors("recurrences")
def create_recurrence(session: Session, values: dict[str, Any]) -> Recurrences:
    """`values` uses Recurrences column names."""
    recurrence = Recurrences(**values)
    session.add(recurrence)
    session.flush()
    return recurrence
