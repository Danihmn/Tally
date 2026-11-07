import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from domain.entities import Recurrence
from infra.database.session import get_db
from presentation.schemas.common_schemas import Page
from presentation.schemas.recurrence_schemas import RecurrenceQuery, RecurrenceResponse
from services.recurrences_service import get_recurrence_by_id, search_recurrences
from services.token_service import get_current_user

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
