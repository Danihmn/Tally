import datetime
import decimal
import uuid
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from domain.credit_card_bills import installment_of
from domain.read_models import AccountBalance, CardBill


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
    # The TEDs that leave this account to the owner's other accounts count as income
    outgoing_transfers_are_income: bool
    bank_code: str | None  # COMPE code, set by the user
    created_at: datetime.datetime | None
    updated_at: datetime.datetime | None


class BankAccountUpdate(BaseModel):
    """Body of PATCH /bank-accounts/{id}: the settings the user chooses. Send only what changes."""

    model_config = ConfigDict(extra="forbid")

    outgoing_transfers_are_income: bool | None = None
    # COMPE code of the bank (3 digits). null removes it
    bank_code: str | None = Field(default=None, pattern=r"^[0-9]{3}$")

    @model_validator(mode="after")
    def _check_fields(self) -> "BankAccountUpdate":  # noqa: UP037
        if not self.model_fields_set:
            raise ValueError("send at least one field")
        if (
            "outgoing_transfers_are_income" in self.model_fields_set
            and self.outgoing_transfers_are_income is None
        ):
            raise ValueError("outgoing_transfers_are_income cannot be null")
        return self


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
    outgoing_transfers_are_income: bool
    bank_code: str | None
    updated_at: datetime.datetime | None
    credit: CreditInfoResponse | None  # Only for cards that have credit data

    @classmethod
    def from_read_model(cls, item: AccountBalance) -> "AccountBalanceResponse":  # noqa: UP037
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
            outgoing_transfers_are_income=account.outgoing_transfers_are_income,
            bank_code=account.bank_code,
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


class CardBillQuery(BaseModel):
    """Query string of GET /bank-accounts/{id}/bill. `month` is the due month ("YYYY-MM").

    Without `month`, the bill due next month (the one the user pays next month)."""

    model_config = ConfigDict(extra="forbid")

    month: str | None = Field(default=None, pattern=r"^[0-9]{4}-(0[1-9]|1[0-2])$")

    def month_start(self) -> datetime.date | None:
        if self.month is None:
            return None
        return datetime.date(int(self.month[:4]), int(self.month[5:7]), 1)


class CardBillTransactionResponse(BaseModel):
    id: uuid.UUID
    date: datetime.datetime
    description: str | None
    amount: decimal.Decimal  # Signed as Pluggy sends it. Use `type` for the direction
    currency_code: str
    type: str  # DEBIT (purchase) | CREDIT (refund, credit or bill payment)
    status: str
    category: str | None
    operation_type: str | None
    installment_number: int | None
    total_installments: int | None


class CardBillResponse(BaseModel):
    """The bill of one card for one due month: only the installment of that month counts."""

    account_id: uuid.UUID
    month: str  # Due month, "YYYY-MM"
    total: decimal.Decimal  # Purchases minus refunds. Payments of other bills are left out
    # True when some transaction had no bill forecast from Pluggy and its bill was estimated
    # with the card's closing day
    estimated: bool
    transactions: list[CardBillTransactionResponse]

    @classmethod
    def from_read_model(cls, bill: CardBill) -> "CardBillResponse":  # noqa: UP037
        assert bill.account.id is not None
        items = []
        for t in bill.transactions:
            assert t.id is not None
            number, total = installment_of(t)
            items.append(
                CardBillTransactionResponse(
                    id=t.id,
                    date=t.date,
                    description=t.description,
                    amount=t.amount,
                    currency_code=t.currency_code,
                    type=t.type,
                    status=t.status,
                    category=t.category,
                    operation_type=t.operation_type,
                    installment_number=number,
                    total_installments=total,
                )
            )
        return cls(
            account_id=bill.account.id,
            month=bill.month.strftime("%Y-%m"),
            total=bill.total,
            estimated=bill.estimated,
            transactions=items,
        )
