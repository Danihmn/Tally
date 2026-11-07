from __future__ import annotations

import datetime
import decimal
import uuid
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from domain.read_models import FinancialEntryFilters
from presentation.schemas._validators import check_amount_range, check_date_range
from presentation.schemas.common_schemas import first_day_of_month


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

    def to_filters(self) -> FinancialEntryFilters:
        return FinancialEntryFilters(
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
        )


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
    created_at: datetime.datetime
    updated_at: datetime.datetime | None
