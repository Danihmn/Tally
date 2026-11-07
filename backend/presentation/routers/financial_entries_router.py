import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from domain.entities import FinancialEntry
from infra.database.session import get_db
from presentation.schemas.common_schemas import Page
from presentation.schemas.financial_entry_schemas import (
    FinancialEntryQuery,
    FinancialEntryResponse,
)
from services.financial_entries_service import (
    get_active_financial_entry_by_id,
    search_financial_entries,
)
from services.token_service import get_current_user

# Both people of the household see every entry (the app is private, for two people).
router = APIRouter(
    prefix="/financial-entries",
    tags=["financial-entries"],
    dependencies=[Depends(get_current_user)],
)


def _to_response(e: FinancialEntry) -> FinancialEntryResponse:
    assert e.id is not None and e.created_at is not None
    return FinancialEntryResponse(
        id=e.id,
        user_id=e.user_id,
        bank_account_id=e.bank_account_id,
        description=e.description,
        category=e.category,
        type=e.type,
        payment_type=e.payment_type,
        amount=e.amount,
        currency_code=e.currency_code,
        reference_month=e.reference_month,
        due_date=e.due_date,
        status=e.status,
        installment_number=e.installment_number,
        installment_total=e.installment_total,
        notes=e.notes,
        created_at=e.created_at,
        updated_at=e.updated_at,
    )


@router.get("", response_model=Page[FinancialEntryResponse])
def list_financial_entries_endpoint(
    query: Annotated[FinancialEntryQuery, Query()],
    session: Annotated[Session, Depends(get_db)],
) -> Page[FinancialEntryResponse]:
    items, total = search_financial_entries(
        session, query.to_filters(), limit=query.limit, offset=query.offset
    )
    return Page[FinancialEntryResponse](
        items=[_to_response(e) for e in items],
        total=total,
        limit=query.limit,
        offset=query.offset,
    )


@router.get("/{entry_id}", response_model=FinancialEntryResponse)
def get_financial_entry_endpoint(
    entry_id: uuid.UUID,
    session: Annotated[Session, Depends(get_db)],
) -> FinancialEntryResponse:
    return _to_response(get_active_financial_entry_by_id(session, entry_id))
