from __future__ import annotations

import datetime
import decimal
import uuid
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from domain.entities import FinancialEntry
from domain.read_models import FinancialEntryFilters
from presentation.schemas._validators import check_amount_range, check_date_range
from utils.dates import first_day_of_month


class FinancialEntryQuery(BaseModel):
    """Query string of GET /financial-entries.

    reference_month_* accept any day of the month (it is moved to the 1st); both ends are inclusive.
    """

    model_config = ConfigDict(extra="forbid")

    user_id: uuid.UUID | None = None
    bank_account_id: uuid.UUID | None = None
    type: Literal["REVENUES", "EXPENSES"] | None = None
    payment_type: Literal["DEBIT", "CREDIT"] | None = None
    status: Literal["PLANNED", "RECONCILED", "CANCELLED"] | None = None
    category: str | None = Field(default=None, min_length=1, max_length=100)
    search: str | None = Field(default=None, min_length=1, max_length=100)
    reference_month_from: datetime.date | None = None
    reference_month_to: datetime.date | None = None
    due_date_from: datetime.date | None = None
    due_date_to: datetime.date | None = None
    min_amount: decimal.Decimal | None = Field(default=None, ge=0)
    max_amount: decimal.Decimal | None = Field(default=None, ge=0)
    # Only the entries reconciled with this transaction
    transaction_id: uuid.UUID | None = None
    limit: int = Field(default=50, ge=1, le=200)
    offset: int = Field(default=0, ge=0)

    @model_validator(mode="after")
    def _check_ranges(self) -> FinancialEntryQuery:
        check_date_range(
            first_day_of_month(self.reference_month_from)
            if self.reference_month_from
            else None,
            first_day_of_month(self.reference_month_to)
            if self.reference_month_to
            else None,
            "reference_month_from",
            "reference_month_to",
        )
        check_date_range(
            self.due_date_from, self.due_date_to, "due_date_from", "due_date_to"
        )
        check_amount_range(self.min_amount, self.max_amount)
        return self

    def to_filters(self, household_id: uuid.UUID) -> FinancialEntryFilters:
        """The filters of the query, always inside the household of the logged user."""
        return FinancialEntryFilters(
            household_id=household_id,
            user_id=self.user_id,
            bank_account_id=self.bank_account_id,
            type=self.type,
            payment_type=self.payment_type,
            status=self.status,
            category=self.category,
            search=self.search,
            reference_month_from=(
                first_day_of_month(self.reference_month_from)
                if self.reference_month_from
                else None
            ),
            reference_month_to=(
                first_day_of_month(self.reference_month_to)
                if self.reference_month_to
                else None
            ),
            due_date_from=self.due_date_from,
            due_date_to=self.due_date_to,
            min_amount=self.min_amount,
            max_amount=self.max_amount,
            transaction_id=self.transaction_id,
        )


class EntryPeriodQuery(BaseModel):
    """Query string of the planning endpoints (total-planned, total-reconciled, reconciliation-counts).

    The period is in months (`reference_month`): any day of a month picks that month. `date_from`
    and `date_to` come together or not at all; without them the current month is used.
    `type` is required: revenues and expenses are never mixed.
    """

    model_config = ConfigDict(extra="forbid")

    type: Literal["REVENUES", "EXPENSES"]
    user_id: uuid.UUID | None = None
    date_from: datetime.date | None = None
    date_to: datetime.date | None = None

    @model_validator(mode="after")
    def _check_period(self) -> EntryPeriodQuery:
        if (self.date_from is None) != (self.date_to is None):
            raise ValueError("date_from and date_to must be sent together")
        check_date_range(self.date_from, self.date_to, "date_from", "date_to")
        return self


class EntryTotalResponse(BaseModel):
    reference_month_from: datetime.date  # First day of the first month that was used
    reference_month_to: datetime.date  # First day of the last month that was used
    type: str  # REVENUES | EXPENSES
    total: decimal.Decimal


class ReconciliationCountsResponse(BaseModel):
    reference_month_from: datetime.date
    reference_month_to: datetime.date
    type: str  # REVENUES | EXPENSES
    reconciled: int
    not_reconciled: int


class UpcomingEntriesQuery(BaseModel):
    """Query string of GET /financial-entries/upcoming: the entries due from today until today + days."""

    model_config = ConfigDict(extra="forbid")

    days: int = Field(default=7, ge=1, le=90)
    user_id: uuid.UUID | None = None


class UpcomingEntryItem(BaseModel):
    description: str
    amount: decimal.Decimal
    type: str  # REVENUES | EXPENSES
    category: str | None  # The entry may have no category
    due_date: datetime.date


class UpcomingEntriesResponse(BaseModel):
    date_from: datetime.date  # Today
    date_to: datetime.date  # Today + days (inclusive)
    items: list[UpcomingEntryItem]  # The nearest due date first


class FinancialEntryCreate(BaseModel):
    """Body of POST /financial-entries. `user_id` defaults to the logged user.

    `reference_month` accepts any day of the month (it is moved to the 1st).
    The status of a new entry is always PLANNED.
    """

    model_config = ConfigDict(extra="forbid")

    description: str = Field(min_length=1, max_length=255)
    type: Literal["REVENUES", "EXPENSES"]
    payment_type: Literal["DEBIT", "CREDIT"] | None = None
    category: str | None = Field(default=None, min_length=1, max_length=100)
    amount: decimal.Decimal = Field(gt=0, max_digits=18, decimal_places=2)
    currency_code: str = Field(default="BRL", min_length=3, max_length=3)
    reference_month: datetime.date
    due_date: datetime.date | None = None
    bank_account_id: uuid.UUID | None = None
    installment_number: int | None = Field(default=None, ge=1, le=32767)
    installment_total: int | None = Field(default=None, ge=1, le=32767)
    notes: str | None = Field(default=None, min_length=1, max_length=1000)
    user_id: uuid.UUID | None = None

    @model_validator(mode="after")
    def _check_installments(self) -> FinancialEntryCreate:
        if (self.installment_number is None) != (self.installment_total is None):
            raise ValueError(
                "installment_number and installment_total must be sent together"
            )
        if (
            self.installment_number is not None
            and self.installment_total is not None
            and self.installment_total < self.installment_number
        ):
            raise ValueError(
                "installment_total must not be less than installment_number"
            )
        return self


class FinancialEntryResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    bank_account_id: uuid.UUID | None
    description: str
    category: str | None
    type: str  # REVENUES | EXPENSES
    payment_type: str | None  # DEBIT | CREDIT
    amount: decimal.Decimal
    currency_code: str
    reference_month: datetime.date
    due_date: datetime.date | None
    status: str
    installment_number: int | None
    installment_total: int | None
    notes: str | None
    recurrence_id: uuid.UUID | None
    created_at: datetime.datetime
    updated_at: datetime.datetime | None

    @classmethod
    def from_entity(cls, e: FinancialEntry) -> FinancialEntryResponse:
        assert e.id is not None and e.created_at is not None
        return cls(
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
            recurrence_id=e.recurrence_id,
            created_at=e.created_at,
            updated_at=e.updated_at,
        )
