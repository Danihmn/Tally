import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from domain.entities import FinancialEntry, User
from infra.database.session import get_db
from presentation.dependencies.auth import get_current_user
from presentation.schemas.common_schemas import Page, first_day_of_month
from presentation.schemas.financial_entry_schemas import (
    FinancialEntryCreate,
    FinancialEntryQuery,
    FinancialEntryResponse,
)
from services.common.exceptions import NotFoundError
from services.financial_entries_service import (
    create_financial_entry,
    get_active_financial_entry_by_id,
    search_financial_entries,
)
from services.users_service import get_user_by_id

# Both people of the household see every entry (the app is private, for two people).
router = APIRouter(
    prefix="/financial-entries",
    tags=["financial-entries"],
    dependencies=[Depends(get_current_user)],
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
        items=[FinancialEntryResponse.from_entity(e) for e in items],
        total=total,
        limit=query.limit,
        offset=query.offset,
    )


@router.get("/{entry_id}", response_model=FinancialEntryResponse)
def get_financial_entry_endpoint(
    entry_id: uuid.UUID,
    session: Annotated[Session, Depends(get_db)],
) -> FinancialEntryResponse:
    return FinancialEntryResponse.from_entity(
        get_active_financial_entry_by_id(session, entry_id)
    )


@router.post(
    "", response_model=FinancialEntryResponse, status_code=status.HTTP_201_CREATED
)
def create_financial_entry_endpoint(
    body: FinancialEntryCreate,
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> FinancialEntryResponse:
    assert current_user.id is not None
    if body.user_id is not None and body.user_id != current_user.id:
        # An entry can only be assigned to someone of the same household
        if get_user_by_id(session, body.user_id).household_id != current_user.household_id:
            raise NotFoundError("User not found")
    entry = FinancialEntry(
        household_id=current_user.household_id,
        user_id=body.user_id or current_user.id,
        description=body.description,
        type=body.type,
        payment_type=body.payment_type,
        category=body.category,
        amount=body.amount,
        currency_code=body.currency_code.upper(),
        reference_month=first_day_of_month(body.reference_month),
        due_date=body.due_date,
        bank_account_id=body.bank_account_id,
        installment_number=body.installment_number,
        installment_total=body.installment_total,
        notes=body.notes,
    )
    created = create_financial_entry(session, entry)
    session.commit()
    return FinancialEntryResponse.from_entity(created)
