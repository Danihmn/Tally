import datetime
import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from domain.entities import User
from domain.read_models import TransactionFilters, TransactionWithOwner
from infra.database.session import get_db
from presentation.dependencies.auth import get_current_user
from presentation.schemas.common_schemas import Page
from presentation.schemas.transaction_schemas import (
    BalanceResponse,
    TotalResponse,
    TransactionPeriodQuery,
    TransactionQuery,
    TransactionResponse,
)
from services.transactions_service import (
    get_balance,
    get_total_expenses,
    get_total_revenues,
    get_transaction_with_owner,
    search_transactions,
)
from utils.dates import (
    default_analysis_period,
    end_of_day_utc,
    start_of_day_utc,
    today_local,
)

# Both people of the household see every transaction (the app is private, for two people).
router = APIRouter(
    prefix="/transactions",
    tags=["transactions"],
    dependencies=[Depends(get_current_user)],
)


def _to_response(item: TransactionWithOwner) -> TransactionResponse:
    t = item.transaction
    assert t.id is not None
    return TransactionResponse(
        id=t.id,
        bank_account_id=t.bank_account_id,
        user_id=item.user_id,
        date=t.date,
        description=t.description,
        amount=t.amount,
        currency_code=t.currency_code,
        type=t.type,
        status=t.status,
        category=t.category,
        category_id=t.category_id,
        merchant=t.merchant,
        balance=t.balance,
    )


@router.get("", response_model=Page[TransactionResponse])
def list_transactions_endpoint(
    query: Annotated[TransactionQuery, Query()],
    session: Annotated[Session, Depends(get_db)],
) -> Page[TransactionResponse]:
    items, total = search_transactions(
        session, query.to_filters(), limit=query.limit, offset=query.offset
    )
    return Page[TransactionResponse](
        items=[_to_response(item) for item in items],
        total=total,
        limit=query.limit,
        offset=query.offset,
    )


def _period_filters(
    query: TransactionPeriodQuery, user: User
) -> tuple[datetime.date, datetime.date, TransactionFilters]:
    """The period (the default one when the query has none) and the filters for it.

    The household always comes from the logged user, never from the request.
    """
    if query.date_from is not None and query.date_to is not None:
        date_from, date_to = query.date_from, query.date_to
    else:
        date_from, date_to = default_analysis_period(today_local())
    filters = TransactionFilters(
        household_id=user.household_id,
        user_id=query.user_id,
        date_from=start_of_day_utc(date_from),
        date_to=end_of_day_utc(date_to),
    )
    return date_from, date_to, filters


# The fixed paths below must stay before "/{transaction_id}"
@router.get("/total-expenses", response_model=TotalResponse)
def total_expenses_endpoint(
    query: Annotated[TransactionPeriodQuery, Query()],
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TotalResponse:
    date_from, date_to, filters = _period_filters(query, current_user)
    return TotalResponse(
        date_from=date_from,
        date_to=date_to,
        total=get_total_expenses(session, filters),
    )


@router.get("/total-revenues", response_model=TotalResponse)
def total_revenues_endpoint(
    query: Annotated[TransactionPeriodQuery, Query()],
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TotalResponse:
    date_from, date_to, filters = _period_filters(query, current_user)
    return TotalResponse(
        date_from=date_from,
        date_to=date_to,
        total=get_total_revenues(session, filters),
    )


@router.get("/balance", response_model=BalanceResponse)
def balance_endpoint(
    query: Annotated[TransactionPeriodQuery, Query()],
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> BalanceResponse:
    date_from, date_to, filters = _period_filters(query, current_user)
    return BalanceResponse(
        date_from=date_from,
        date_to=date_to,
        balance=get_balance(session, filters),
    )


@router.get("/{transaction_id}", response_model=TransactionResponse)
def get_transaction_endpoint(
    transaction_id: uuid.UUID,
    session: Annotated[Session, Depends(get_db)],
) -> TransactionResponse:
    return _to_response(get_transaction_with_owner(session, transaction_id))
