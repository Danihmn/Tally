import datetime
import uuid
from typing import Annotated

from fastapi import APIRouter, Body, Depends, Query, status
from sqlalchemy.orm import Session

from domain.entities import Recurrence, User
from infra.database.session import get_db
from presentation.dependencies.auth import get_current_user
from presentation.schemas.common_schemas import Page
from presentation.schemas.recurrence_schemas import (
    RecurrenceCreate,
    RecurrenceProvisionRequest,
    RecurrenceProvisionResponse,
    RecurrenceQuery,
    RecurrenceResponse,
)
from services.common.exceptions import NotFoundError
from services.recurrences_service import (
    create_recurrence,
    get_recurrence_by_id,
    provision_entries_from_recurrences,
    search_recurrences,
)
from services.users_service import get_user_by_id
from utils.dates import first_day_of_month

# Both people of the household see every recurrence of the household (the app is private, for two
# people). Recurrences of other households are not found.
router = APIRouter(
    prefix="/recurrences",
    tags=["recurrences"],
    dependencies=[Depends(get_current_user)],
)


@router.get("", response_model=Page[RecurrenceResponse])
def list_recurrences_endpoint(
    query: Annotated[RecurrenceQuery, Query()],
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> Page[RecurrenceResponse]:
    items, total = search_recurrences(
        session,
        query.to_filters(current_user.household_id),
        limit=query.limit,
        offset=query.offset,
    )
    return Page[RecurrenceResponse](
        items=[RecurrenceResponse.from_entity(r) for r in items],
        total=total,
        limit=query.limit,
        offset=query.offset,
    )


@router.post("/provision", response_model=RecurrenceProvisionResponse)
def provision_recurrences_endpoint(
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    body: Annotated[RecurrenceProvisionRequest | None, Body()] = None,
) -> RecurrenceProvisionResponse:
    """Creates the PLANNED entries of the month for the recurrences that have none yet.

    Safe to call more than once: a recurrence that already has an entry in the month is skipped.
    """
    assert current_user.id is not None
    reference_month = (body.reference_month if body else None) or datetime.datetime.now(
        datetime.UTC
    ).date()
    result = provision_entries_from_recurrences(
        session,
        current_user.household_id,
        first_day_of_month(reference_month),
        fallback_user_id=current_user.id,
    )
    session.commit()
    return RecurrenceProvisionResponse.from_result(result)


@router.get("/{recurrence_id}", response_model=RecurrenceResponse)
def get_recurrence_endpoint(
    recurrence_id: uuid.UUID,
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> RecurrenceResponse:
    recurrence = get_recurrence_by_id(session, recurrence_id)
    if recurrence.household_id != current_user.household_id:
        raise NotFoundError("Recurrence not found")
    return RecurrenceResponse.from_entity(recurrence)


@router.post("", response_model=RecurrenceResponse, status_code=status.HTTP_201_CREATED)
def create_recurrence_endpoint(
    body: RecurrenceCreate,
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> RecurrenceResponse:
    assert current_user.id is not None
    if body.user_id is not None and body.user_id != current_user.id:
        # A recurrence can only be assigned to someone of the same household
        if (
            get_user_by_id(session, body.user_id).household_id
            != current_user.household_id
        ):
            raise NotFoundError("User not found")
    recurrence = Recurrence(
        household_id=current_user.household_id,
        user_id=body.user_id or current_user.id,
        description=body.description,
        type=body.type,
        payment_type=body.payment_type,
        category=body.category,
        amount=body.amount,
        currency_code=body.currency_code.upper(),
        due_day=body.due_day,
        notes=body.notes,
        source="MANUAL",
    )
    created = create_recurrence(session, recurrence)
    session.commit()
    return RecurrenceResponse.from_entity(created)
