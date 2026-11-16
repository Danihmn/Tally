import datetime
import uuid
from typing import Any

from sqlalchemy.orm import Session

from domain.entities import FinancialEntry, Recurrence
from domain.read_models import ProvisionResult, RecurrenceFilters
from infra.repositories import recurrences_repository, users_repository
from services.common.exceptions import (
    AlreadyExistsError,
    InvalidDataError,
    NoRecurrencesError,
    NotFoundError,
    translate_repository_errors,
)
from services.common.mappers import to_entities, to_entity, to_values
from services.financial_entries_service import (
    create_financial_entry,
    list_provisioned_recurrence_ids,
)
from utils.dates import clamp_day_to_month, next_month_start


def _load_recurrence(
    session: Session, household_id: uuid.UUID, recurrence_id: uuid.UUID
):
    """The stored recurrence of the household. Another household's one is "not found"."""
    recurrence = recurrences_repository.get_recurrence(
        session, recurrence_id, household_id
    )
    if recurrence is None:
        raise NotFoundError("Recurrence not found")
    return recurrence


def _check_owner(
    session: Session, household_id: uuid.UUID, user_id: uuid.UUID
) -> None:
    """The owner of a recurrence must be a person of the same household."""
    if users_repository.get_user_in_household(session, user_id, household_id) is None:
        raise InvalidDataError("The owner is not a person of the household")


@translate_repository_errors
def search_recurrences(
    session: Session, filters: RecurrenceFilters, limit: int = 50, offset: int = 0
) -> tuple[list[Recurrence], int]:
    """A page of recurrences and the total that match the filters."""
    rows = recurrences_repository.search_recurrences(session, filters, limit, offset)
    total = recurrences_repository.count_recurrences(session, filters)
    return to_entities(Recurrence, rows), total


@translate_repository_errors
def get_recurrence(
    session: Session, household_id: uuid.UUID, recurrence_id: uuid.UUID
) -> Recurrence:
    return to_entity(Recurrence, _load_recurrence(session, household_id, recurrence_id))


@translate_repository_errors
def create_recurrence(session: Session, recurrence: Recurrence) -> Recurrence:
    assert recurrence.user_id is not None
    _check_owner(session, recurrence.household_id, recurrence.user_id)
    created = recurrences_repository.create_recurrence(session, to_values(recurrence))
    return to_entity(Recurrence, created)


@translate_repository_errors
def update_recurrence(
    session: Session,
    household_id: uuid.UUID,
    recurrence_id: uuid.UUID,
    values: dict[str, Any],
) -> Recurrence:
    """Changes only the given columns. Entries already created from it are not touched."""
    stored = _load_recurrence(session, household_id, recurrence_id)
    if values.get("user_id") is not None:
        _check_owner(session, household_id, values["user_id"])
    updated = recurrences_repository.update_recurrence(session, stored, values)
    return to_entity(Recurrence, updated)


@translate_repository_errors
def delete_recurrence(
    session: Session, household_id: uuid.UUID, recurrence_id: uuid.UUID
) -> None:
    """Soft delete: it stops generating entries, the ones it created stay."""
    stored = _load_recurrence(session, household_id, recurrence_id)
    recurrences_repository.soft_delete_recurrence(session, stored)


def _entry_from_recurrence(
    recurrence: Recurrence,
    reference_month: datetime.date,
    fallback_user_id: uuid.UUID,
) -> FinancialEntry:
    return FinancialEntry(
        # The entry always has an owner: the recurrence may have lost its user (SET NULL)
        user_id=recurrence.user_id or fallback_user_id,
        household_id=recurrence.household_id,
        description=recurrence.description,
        type=recurrence.type,
        amount=recurrence.amount,
        currency_code=recurrence.currency_code,
        reference_month=reference_month,
        status="PLANNED",
        category=recurrence.category,
        payment_type=recurrence.payment_type,
        notes=recurrence.notes,
        due_date=(
            None
            if recurrence.due_day is None
            else clamp_day_to_month(reference_month, recurrence.due_day)
        ),
        recurrence_id=recurrence.id,
    )


@translate_repository_errors
def provision_next_month(
    session: Session,
    household_id: uuid.UUID,
    user_id: uuid.UUID,
    today: datetime.date,
) -> ProvisionResult:
    """Creates the PLANNED entries of next month from the ACTIVE recurrences of the household.

    A recurrence that already has an entry in that month (not CANCELLED) is skipped, so calling
    it again creates nothing. Raises NoRecurrencesError when the household has no active one."""
    recurrences = to_entities(
        Recurrence, recurrences_repository.list_recurrences(session, household_id)
    )
    if not recurrences:
        raise NoRecurrencesError("The household has no recurrences")

    reference_month = next_month_start(today)
    provisioned = list_provisioned_recurrence_ids(
        session, household_id, reference_month
    )
    result = ProvisionResult(reference_month=reference_month)
    for recurrence in recurrences:
        if recurrence.id in provisioned:
            result.skipped += 1
            continue
        entry = _entry_from_recurrence(recurrence, reference_month, user_id)
        try:
            # A savepoint: a concurrent call that got there first only loses this one entry
            with session.begin_nested():
                create_financial_entry(session, entry)
        except AlreadyExistsError:
            result.skipped += 1
            continue
        result.created += 1
    return result
