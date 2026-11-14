import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from domain.entities import User
from domain.read_models import BankAccountWithOwner
from infra.database.session import get_db
from jobs.transaction_internal_transfers_classification import (
    reclassify_internal_transfers,
)
from presentation.dependencies.auth import get_current_user
from presentation.schemas.bank_account_schemas import (
    AccountBalanceResponse,
    BalanceQuery,
    BankAccountQuery,
    BankAccountResponse,
    BankAccountUpdate,
    TotalBalanceQuery,
    TotalBalanceResponse,
)
from services.bank_accounts_service import (
    get_total_balance,
    list_account_balances,
    search_bank_accounts,
    update_bank_account_settings,
)

# Both people of the household see every account of the household (the app is private, for two
# people). Accounts of other households are never listed.
router = APIRouter(
    prefix="/bank-accounts",
    tags=["bank-accounts"],
    dependencies=[Depends(get_current_user)],
)


def _to_response(item: BankAccountWithOwner) -> BankAccountResponse:
    account = item.account
    assert account.id is not None
    return BankAccountResponse(
        id=account.id,
        user_id=item.user_id,
        pluggy_item_id=account.pluggy_item_id,
        type=account.type,
        subtype=account.subtype,
        name=account.name,
        marketing_name=account.marketing_name,
        number=account.number,
        currency_code=account.currency_code,
        owner=account.owner,
        balance=account.balance,
        outgoing_transfers_are_income=account.outgoing_transfers_are_income,
        bank_code=account.bank_code,
        created_at=account.created_at,
        updated_at=account.updated_at,
    )


@router.get("", response_model=list[BankAccountResponse])
def list_bank_accounts_endpoint(
    query: Annotated[BankAccountQuery, Query()],
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> list[BankAccountResponse]:
    # The household always comes from the logged user, never from the request. Accounts of
    # removed connections are kept in the list: their transactions are still stored.
    items = search_bank_accounts(
        session,
        user_id=query.user_id,
        account_type=query.type,
        limit=query.limit,
        offset=query.offset,
        household_id=current_user.household_id,
    )
    return [_to_response(item) for item in items]


# The fixed paths below must stay before "/{account_id}". They only look at accounts of connected
# items, and the balance is the one Pluggy gave in the last sync.
@router.get("/total-balance", response_model=TotalBalanceResponse)
def total_balance_endpoint(
    query: Annotated[TotalBalanceQuery, Query()],
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TotalBalanceResponse:
    return TotalBalanceResponse(
        type=query.type,
        total=get_total_balance(
            session, current_user.household_id, query.type, query.user_id
        ),
    )


@router.get("/balances", response_model=list[AccountBalanceResponse])
def list_balances_endpoint(
    query: Annotated[BalanceQuery, Query()],
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> list[AccountBalanceResponse]:
    items = list_account_balances(
        session, current_user.household_id, query.type, query.user_id
    )
    return [AccountBalanceResponse.from_read_model(item) for item in items]


@router.patch("/{account_id}", response_model=BankAccountResponse)
def update_bank_account_endpoint(
    account_id: uuid.UUID,
    body: BankAccountUpdate,
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> BankAccountResponse:
    """Changes the settings of a bank account of the household (not a card).

    A change reclassifies the internal transfers of the household, so the totals follow it
    for the past months too. Turning the flag on without a bank code takes it from the
    account's transfer number. 404 outside the household, 422 for a card or the flag on
    when no bank code is sent, stored or found in the transfer number."""
    item, changed = update_bank_account_settings(
        session,
        current_user.household_id,
        account_id,
        body.model_dump(exclude_unset=True),
    )
    if changed:
        reclassify_internal_transfers(session, current_user.household_id)
    session.commit()
    return _to_response(item)
