import datetime
import decimal
import uuid
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from domain.read_models import TransactionFilters
from presentation.schemas._validators import check_amount_range, check_date_range
from utils.dates import end_of_day_utc, start_of_day_utc


class TransactionQuery(BaseModel):
    """Query string of GET /transactions. Dates are UTC days: both ends are inclusive."""

    model_config = ConfigDict(extra="forbid")

    user_id: uuid.UUID | None = None
    bank_account_id: uuid.UUID | None = None
    date_from: datetime.date | None = None
    date_to: datetime.date | None = None
    type: Literal["DEBIT", "CREDIT"] | None = None
    status: Literal["POSTED", "PENDING"] | None = None
    category: str | None = Field(default=None, min_length=1, max_length=100)
    search: str | None = Field(default=None, min_length=1, max_length=100)
    min_amount: decimal.Decimal | None = Field(default=None, ge=0)
    max_amount: decimal.Decimal | None = Field(default=None, ge=0)
    # UNCLASSIFIED: the ones that were not classified yet
    internal_transfer: (
        Literal[
            "SAME_PERSON", "SAME_HOUSEHOLD", "NOT_INTERNAL_TRANSFER", "UNCLASSIFIED"
        ]
        | None
    ) = None
    limit: int = Field(default=50, ge=1, le=200)
    offset: int = Field(default=0, ge=0)

    @model_validator(mode="after")
    def _check_ranges(self) -> TransactionQuery:
        check_date_range(self.date_from, self.date_to, "date_from", "date_to")
        check_amount_range(self.min_amount, self.max_amount)
        return self

    def to_filters(self, household_id: uuid.UUID) -> TransactionFilters:
        """The filters of the query, always inside the household of the logged user."""
        return TransactionFilters(
            household_id=household_id,
            user_id=self.user_id,
            bank_account_id=self.bank_account_id,
            date_from=start_of_day_utc(self.date_from) if self.date_from else None,
            date_to=end_of_day_utc(self.date_to) if self.date_to else None,
            type=self.type,
            status=self.status,
            category=self.category,
            search=self.search,
            min_amount=self.min_amount,
            max_amount=self.max_amount,
            internal_transfer=self.internal_transfer,
        )


class TransactionPeriodQuery(BaseModel):
    """Query string of the period analysis endpoints (total-expenses, total-revenues, balance).

    `date_from` and `date_to` come together or not at all: without them the server uses the
    default period (day 1 of the month until yesterday). Both ends are inclusive UTC days.
    """

    model_config = ConfigDict(extra="forbid")

    user_id: uuid.UUID | None = None
    date_from: datetime.date | None = None
    date_to: datetime.date | None = None

    @model_validator(mode="after")
    def _check_period(self) -> TransactionPeriodQuery:
        if (self.date_from is None) != (self.date_to is None):
            raise ValueError("date_from and date_to must be sent together")
        check_date_range(self.date_from, self.date_to, "date_from", "date_to")
        return self


class TopExpensesQuery(TransactionPeriodQuery):
    """Same period filters as the totals, plus how many transactions to list."""

    limit: int = Field(default=5, ge=1, le=50)


class TopExpenseItem(BaseModel):
    date: datetime.date  # UTC day
    amount: decimal.Decimal
    description: str | None


class TopExpensesResponse(BaseModel):
    date_from: datetime.date
    date_to: datetime.date
    items: list[TopExpenseItem]  # Biggest amount first


class DailyExpenseItem(BaseModel):
    date: datetime.date  # UTC day
    total: decimal.Decimal


class DailyExpensesResponse(BaseModel):
    date_from: datetime.date
    date_to: datetime.date
    items: list[
        DailyExpenseItem
    ]  # Every day of the period, oldest first. 0 when nothing was spent


class AverageResponse(BaseModel):
    date_from: datetime.date
    date_to: datetime.date
    average: decimal.Decimal


class TotalResponse(BaseModel):
    date_from: (
        datetime.date
    )  # The period that was used (the default one when none was sent)
    date_to: datetime.date
    total: decimal.Decimal


class BalanceResponse(BaseModel):
    date_from: datetime.date
    date_to: datetime.date
    balance: decimal.Decimal  # Revenues minus expenses. Negative when it spent more


class TransactionResponse(BaseModel):
    """`payment_data` is left out on purpose: it carries the other party's document numbers."""

    id: uuid.UUID
    bank_account_id: uuid.UUID
    user_id: uuid.UUID  # The owner of the account
    date: datetime.datetime
    description: str | None
    amount: decimal.Decimal  # Signed as Pluggy sends it. Use `type` for the direction
    currency_code: str
    type: str
    status: str
    category: str | None
    category_id: str | None
    merchant: Any | None
    balance: decimal.Decimal | None
    # None = not classified yet
    internal_transfer: (
        Literal["SAME_PERSON", "SAME_HOUSEHOLD", "NOT_INTERNAL_TRANSFER"] | None
    )
    internal_transfer_classification_source: Literal["MANUAL", "AUTO"] | None
