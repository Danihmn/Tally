import datetime
import uuid

from dateutil.relativedelta import relativedelta
from sqlalchemy.orm import Session

from domain.entities import Recurrence
from domain.read_models import ProvisioningResult, RecurrenceFilters
from domain.recurrence_provisioning import build_entry
from infra.repositories import recurrences_repository
from services.common.exceptions import translate_repository_errors
from services.common.mappers import to_entity, to_values
from services.financial_entries_service import (
    create_financial_entry,
    list_financial_entries_by_household,
)


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
def list_recurrences_by_household(
    session: Session, household_id: uuid.UUID
) -> list[Recurrence]:
    rows = recurrences_repository.list_recurrences_by_household(session, household_id)
    return [to_entity(Recurrence, r) for r in rows]


@translate_repository_errors
def create_recurrence(session: Session, recurrence: Recurrence) -> Recurrence:
    created = recurrences_repository.create_recurrence(session, to_values(recurrence))
    return to_entity(Recurrence, created)


def provision_entries_from_recurrences(
    session: Session,
    household_id: uuid.UUID,
    reference_month: datetime.date,
    fallback_user_id: uuid.UUID,
) -> ProvisioningResult:
    """Creates the PLANNED entries of the month for the household recurrences that have none yet.

    A recurrence already has an entry when an entry of the month (any status, CANCELLED included,
    so cancelling an entry skips that month) points to it. Soft deleted entries do not count.
    `fallback_user_id` owns the entries of recurrences without a user. It does not commit.
    """
    month = reference_month.replace(day=1)
    recurrences = list_recurrences_by_household(session, household_id)
    result = ProvisioningResult(reference_month=month)
    if not recurrences:
        return result

    entries = list_financial_entries_by_household(
        session,
        household_id,
        reference_month_from=month,
        reference_month_to=month + relativedelta(months=1),
    )
    provisioned = {e.recurrence_id for e in entries if e.recurrence_id is not None}

    for recurrence in recurrences:
        if recurrence.id in provisioned:
            result.skipped_count += 1
            continue
        entry = build_entry(recurrence, month, fallback_user_id)
        result.created.append(create_financial_entry(session, entry))
    return result
