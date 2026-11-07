import uuid

from sqlalchemy.orm import Session

from domain.entities import Recurrence
from domain.read_models import RecurrenceFilters
from infra.repositories import recurrences_repository
from services._mappers import to_entity, to_values
from services.exceptions import translate_repository_errors


@translate_repository_errors
def get_recurrence_by_id(session: Session, recurrence_id: uuid.UUID) -> Recurrence:
    recurrence = recurrences_repository.get_recurrence_by_id(session, recurrence_id)
    return to_entity(Recurrence, recurrence)


@translate_repository_errors
def search_recurrences(
    session: Session,
    filters: RecurrenceFilters,
    limit: int = 50,
    offset: int = 0,
) -> tuple[list[Recurrence], int]:
    """A page of recurrences (newest first) and the total that match the filters."""
    rows = recurrences_repository.search_recurrences(session, filters, limit, offset)
    total = recurrences_repository.count_recurrences(session, filters)
    return [to_entity(Recurrence, r) for r in rows], total


@translate_repository_errors
def create_recurrence(session: Session, recurrence: Recurrence) -> Recurrence:
    created = recurrences_repository.create_recurrence(session, to_values(recurrence))
    return to_entity(Recurrence, created)
