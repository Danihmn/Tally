import datetime
import uuid
from typing import Any

from sqlalchemy import Select, func, select
from sqlalchemy.orm import Session

from domain.read_models import RecurrenceFilters
from infra.database.models import Recurrences
from infra.repositories.common.exceptions import translate_db_errors
from infra.repositories.common.like import ilike_contains


def _apply_filters(stmt: Select, filters: RecurrenceFilters) -> Select:
    stmt = stmt.where(Recurrences.deleted_at.is_(None))
    if filters.household_id is not None:
        stmt = stmt.where(Recurrences.household_id == filters.household_id)
    if filters.type is not None:
        stmt = stmt.where(Recurrences.type == filters.type)
    if filters.search:
        stmt = stmt.where(ilike_contains(Recurrences.description, filters.search))
    return stmt


@translate_db_errors("recurrences")
def search_recurrences(
    session: Session, filters: RecurrenceFilters, limit: int = 50, offset: int = 0
) -> list[Recurrences]:
    """Filtered page of recurrences that were not soft deleted (by description)."""
    stmt = (
        _apply_filters(select(Recurrences), filters)
        .order_by(Recurrences.description, Recurrences.id)
        .limit(limit)
        .offset(offset)
    )
    return list(session.scalars(stmt).all())


@translate_db_errors("recurrences")
def count_recurrences(session: Session, filters: RecurrenceFilters) -> int:
    stmt = _apply_filters(select(func.count(Recurrences.id)), filters)
    return session.scalar(stmt) or 0


@translate_db_errors("recurrences")
def list_recurrences(session: Session, household_id: uuid.UUID) -> list[Recurrences]:
    """Every active recurrence of the household, with no pagination (few rows)."""
    stmt = _apply_filters(
        select(Recurrences), RecurrenceFilters(household_id=household_id)
    ).order_by(Recurrences.description, Recurrences.id)
    return list(session.scalars(stmt).all())


@translate_db_errors("recurrences")
def get_recurrence(
    session: Session, recurrence_id: uuid.UUID, household_id: uuid.UUID
) -> Recurrences | None:
    """The recurrence when it is in the household and was not soft deleted, else None."""
    stmt = (
        select(Recurrences)
        .where(Recurrences.id == recurrence_id)
        .where(Recurrences.household_id == household_id)
        .where(Recurrences.deleted_at.is_(None))
    )
    return session.scalars(stmt).first()


@translate_db_errors("recurrences")
def create_recurrence(session: Session, values: dict[str, Any]) -> Recurrences:
    recurrence = Recurrences(**values)
    session.add(recurrence)
    session.flush()
    return recurrence


@translate_db_errors("recurrences")
def update_recurrence(
    session: Session, recurrence: Recurrences, values: dict[str, Any]
) -> Recurrences:
    """Writes the given columns of a loaded recurrence (and its updated_at)."""
    for column, value in values.items():
        setattr(recurrence, column, value)
    recurrence.updated_at = datetime.datetime.now(datetime.UTC)
    session.flush()
    return recurrence


@translate_db_errors("recurrences")
def soft_delete_recurrence(session: Session, recurrence: Recurrences) -> Recurrences:
    """The entries it already created stay: they keep pointing to it."""
    now = datetime.datetime.now(datetime.UTC)
    recurrence.deleted_at = now
    recurrence.updated_at = now
    session.flush()
    return recurrence
