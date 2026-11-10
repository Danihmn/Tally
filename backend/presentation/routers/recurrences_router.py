import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from domain.entities import Recurrence, User
from infra.database.session import get_db
from presentation.dependencies.auth import get_current_user
from presentation.schemas.common_schemas import Page
from presentation.schemas.recurrence_schemas import (
    RecurrenceCreate,
    RecurrenceQuery,
    RecurrenceResponse,
)
from services.recurrences_service import (
    create_recurrence,
    get_recurrence_by_id,
    search_recurrences,
)

# Both people of the household see every recurrence (the app is private, for two people).
router = APIRouter(
    prefix="/recurrences",
    tags=["recurrences"],
    dependencies=[Depends(get_current_user)],
)


def _to_response(r: Recurrence) -> RecurrenceResponse:
    assert r.id is not None and r.created_at is not None
    return RecurrenceResponse(
        id=r.id,
        user_id=r.user_id,
        type=r.type,
        payment_type=r.payment_type,
        category=r.category,
        amount=r.amount,
        currency_code=r.currency_code,
        created_at=r.created_at,
        updated_at=r.updated_at,
    )


@router.get("", response_model=Page[RecurrenceResponse])
def list_recurrences_endpoint(
    query: Annotated[RecurrenceQuery, Query()],
    session: Annotated[Session, Depends(get_db)],
) -> Page[RecurrenceResponse]:
    items, total = search_recurrences(
        session, query.to_filters(), limit=query.limit, offset=query.offset
    )
    return Page[RecurrenceResponse](
        items=[_to_response(r) for r in items],
        total=total,
        limit=query.limit,
        offset=query.offset,
    )


@router.get("/{recurrence_id}", response_model=RecurrenceResponse)
def get_recurrence_endpoint(
    recurrence_id: uuid.UUID,
    session: Annotated[Session, Depends(get_db)],
) -> RecurrenceResponse:
    return _to_response(get_recurrence_by_id(session, recurrence_id))


@router.post("", response_model=RecurrenceResponse, status_code=status.HTTP_201_CREATED)
def create_recurrence_endpoint(
    body: RecurrenceCreate,
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> RecurrenceResponse:
    recurrence = Recurrence(
        type=body.type,
        payment_type=body.payment_type,
        category=body.category,
        amount=body.amount,
        currency_code=body.currency_code.upper(),
        user_id=body.user_id or current_user.id,
    )
    created = create_recurrence(session, recurrence)
    session.commit()
    return _to_response(created)
