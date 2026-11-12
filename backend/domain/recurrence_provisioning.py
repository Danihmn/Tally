"""Pure rules to turn a recurrence into the financial entry of a month (no database)."""

import calendar
import datetime
import uuid

from domain.entities import FinancialEntry, Recurrence
from utils.ids import require_id


def due_date_for(
    reference_month: datetime.date, due_day: int | None
) -> datetime.date | None:
    """The due day inside the month, moved to the last day when the month is shorter (31 -> Feb 28)."""
    if due_day is None:
        return None
    last_day = calendar.monthrange(reference_month.year, reference_month.month)[1]
    return reference_month.replace(day=min(due_day, last_day))


def build_entry(
    recurrence: Recurrence,
    reference_month: datetime.date,
    fallback_user_id: uuid.UUID,
) -> FinancialEntry:
    """A PLANNED entry of `reference_month` (first day of the month) for the recurrence.

    A recurrence without a user (the user was deleted, or it is for the household) gives the entry
    to `fallback_user_id`, the user who asked for the provisioning.
    """
    recurrence_id = require_id(recurrence, "Recurrence")
    return FinancialEntry(
        household_id=recurrence.household_id,
        user_id=recurrence.user_id or fallback_user_id,
        recurrence_id=recurrence_id,
        description=recurrence.description,
        notes=recurrence.notes,
        category=recurrence.category,
        type=recurrence.type,
        payment_type=recurrence.payment_type,
        amount=recurrence.amount,
        currency_code=recurrence.currency_code,
        reference_month=reference_month,
        due_date=due_date_for(reference_month, recurrence.due_day),
        status="PLANNED",
    )
