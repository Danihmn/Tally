import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.orm import Session

from domain.entities import User
from infra.database.session import get_db
from presentation.dependencies.auth import get_current_user
from presentation.schemas.common_schemas import Page
from presentation.schemas.recurrence_schemas import (
    ProvisionResponse,
    RecurrenceCreate,
    RecurrenceQuery,
    RecurrenceResponse,
    RecurrenceUpdate,
)
from services.recurrences_service import (
    create_recurrence,
    delete_recurrence,
    get_recurrence,
    provision_next_month,
    search_recurrences,
    update_recurrence,
)
from utils.dates import today_local
from utils.ids import require_id

# Both people of the household see every recurrence (the app is private, for two people).
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


@router.post("", response_model=RecurrenceResponse, status_code=status.HTTP_201_CREATED)
def create_recurrence_endpoint(
    body: RecurrenceCreate,
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> RecurrenceResponse:
    """Creates a MANUAL recurrence owned by the logged user, in the user's household."""
    recurrence = create_recurrence(
        session,
        body.to_entity(require_id(current_user, "User"), current_user.household_id),
    )
    session.commit()
    return RecurrenceResponse.from_entity(recurrence)


# The fixed paths below must stay before "/{recurrence_id}"
@router.post("/provision", response_model=ProvisionResponse)
def provision_next_month_endpoint(
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> ProvisionResponse:
    """Creates the entries of next month from the recurrences of the household.

    A recurrence that already has its entry in that month is skipped, so it can be called again
    without duplicating anything. 422 with code NO_RECURRENCES when there is none to use."""
    result = provision_next_month(
        session,
        current_user.household_id,
        require_id(current_user, "User"),
        today_local(),
    )
    session.commit()
    return ProvisionResponse(
        reference_month=result.reference_month,
        created=result.created,
        skipped=result.skipped,
    )


@router.get("/{recurrence_id}", response_model=RecurrenceResponse)
def get_recurrence_endpoint(
    recurrence_id: uuid.UUID,
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> RecurrenceResponse:
    """404 when the recurrence does not exist or is in another household."""
    return RecurrenceResponse.from_entity(
        get_recurrence(session, current_user.household_id, recurrence_id)
    )


@router.patch("/{recurrence_id}", response_model=RecurrenceResponse)
def update_recurrence_endpoint(
    recurrence_id: uuid.UUID,
    body: RecurrenceUpdate,
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> RecurrenceResponse:
    """Changes only the fields sent. The entries already created from it are not changed."""
    recurrence = update_recurrence(
        session,
        current_user.household_id,
        recurrence_id,
        body.model_dump(exclude_unset=True),
    )
    session.commit()
    return RecurrenceResponse.from_entity(recurrence)


@router.delete("/{recurrence_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_recurrence_endpoint(
    recurrence_id: uuid.UUID,
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> Response:
    """Soft delete. The entries it already created stay."""
    delete_recurrence(session, current_user.household_id, recurrence_id)
    session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
