import datetime
import decimal
import uuid
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from domain.read_models import AccountBalance


class BankAccountQuery(BaseModel):
    model_config = ConfigDict(extra="forbid")

    user_id: uuid.UUID | None = None
    type: Literal["BANK", "CREDIT"] | None = None
    limit: int = Field(default=50, ge=1, le=100)
    offset: int = Field(default=0, ge=0)


class BankAccountResponse(BaseModel):
    """`tax_number` (the holder's CPF) is left out on purpose."""

    id: uuid.UUID
    user_id: (
        uuid.UUID
    )  # The owner: the user who connected the item this account belongs to
    pluggy_item_id: uuid.UUID  # Our own pluggy_items.id, not Pluggy's item id
    type: str
    subtype: str
    name: str
    marketing_name: str | None
    number: str
    currency_code: str
    owner: str | None
    balance: decimal.Decimal | None
    created_at: datetime.datetime | None
    updated_at: datetime.datetime | None


class BalanceQuery(BaseModel):
    """Query string of GET /bank-accounts/balances. The household comes from the logged user."""

    model_config = ConfigDict(extra="forbid")

    user_id: uuid.UUID | None = None
    type: Literal["BANK", "CREDIT"] | None = None


class TotalBalanceQuery(BaseModel):
    """Query string of GET /bank-accounts/total-balance.

    `type` is required: the balance of the accounts and the open bills of the cards are never
    added together."""

    model_config = ConfigDict(extra="forbid")

    type: Literal["BANK", "CREDIT"]
    user_id: uuid.UUID | None = None


class TotalBalanceResponse(BaseModel):
    type: str  # BANK | CREDIT
    total: decimal.Decimal


class CreditInfoResponse(BaseModel):
    """What Pluggy tells about a card. Every field may be missing."""

    credit_limit: decimal.Decimal | None
    available_credit_limit: decimal.Decimal | None
    balance_due_date: datetime.datetime | None
    balance_close_date: datetime.datetime | None


class AccountBalanceResponse(BaseModel):
    """`tax_number` (the holder's CPF) is left out on purpose."""

    id: uuid.UUID
    user_id: uuid.UUID  # The owner: the user who connected the item
    type: str  # BANK | CREDIT
    subtype: str
    name: str
    marketing_name: str | None
    number: str
    currency_code: str
    balance: decimal.Decimal | None
    updated_at: datetime.datetime | None
    credit: CreditInfoResponse | None  # Only for cards that have credit data

    @classmethod
    def from_read_model(cls, item: AccountBalance) -> "AccountBalanceResponse":
        account = item.account
        assert account.id is not None
        credit = item.credit_data
        return cls(
            id=account.id,
            user_id=item.user_id,
            type=account.type,
            subtype=account.subtype,
            name=account.name,
            marketing_name=account.marketing_name,
            number=account.number,
            currency_code=account.currency_code,
            balance=account.balance,
            updated_at=account.updated_at,
            credit=None
            if credit is None
            else CreditInfoResponse(
                credit_limit=credit.credit_limit,
                available_credit_limit=credit.available_credit_limit,
                balance_due_date=credit.balance_due_date,
                balance_close_date=credit.balance_close_date,
            ),
        )
