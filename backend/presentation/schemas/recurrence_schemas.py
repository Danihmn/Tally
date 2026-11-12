from __future__ import annotations

import datetime
import decimal
import uuid
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from domain.entities import Recurrence
from domain.read_models import ProvisioningResult, RecurrenceFilters
from presentation.schemas._validators import check_amount_range
from presentation.schemas.financial_entry_schemas import FinancialEntryResponse


class RecurrenceQuery(BaseModel):
    """Query string of GET /recurrences."""

    model_config = ConfigDict(extra="forbid")

    user_id: uuid.UUID | None = None
    type: Literal["REVENUES", "EXPENSES"] | None = None
    payment_type: Literal["DEBIT", "CREDIT"] | None = None
    category: str | None = Field(default=None, min_length=1, max_length=100)
    min_amount: decimal.Decimal | None = Field(default=None, ge=0)
    max_amount: decimal.Decimal | None = Field(default=None, ge=0)
    limit: int = Field(default=50, ge=1, le=200)
    offset: int = Field(default=0, ge=0)

    @model_validator(mode="after")
    def _check_ranges(self) -> RecurrenceQuery:
        check_amount_range(self.min_amount, self.max_amount)
        return self

    def to_filters(self, household_id: uuid.UUID) -> RecurrenceFilters:
        return RecurrenceFilters(
            household_id=household_id,
            user_id=self.user_id,
            type=self.type,
            payment_type=self.payment_type,
            category=self.category,
            min_amount=self.min_amount,
            max_amount=self.max_amount,
        )


class RecurrenceCreate(BaseModel):
    """Body of POST /recurrences. `user_id` defaults to the logged user.

    The recurrence belongs to the household of the logged user and its source is always MANUAL
    (AI created recurrences do not come through this endpoint).
    """

    model_config = ConfigDict(extra="forbid")

    description: str = Field(min_length=1, max_length=255)
    type: Literal["REVENUES", "EXPENSES"]
    payment_type: Literal["DEBIT", "CREDIT"] | None = None
    category: str | None = Field(default=None, min_length=1, max_length=100)
    amount: decimal.Decimal = Field(gt=0, max_digits=18, decimal_places=2)
    currency_code: str = Field(default="BRL", min_length=3, max_length=3)
    due_day: int | None = Field(default=None, ge=1, le=31)
    notes: str | None = Field(default=None, min_length=1, max_length=1000)
    user_id: uuid.UUID | None = None


class RecurrenceResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID | None
    description: str
    type: str  # REVENUES | EXPENSES
    payment_type: str | None  # DEBIT | CREDIT
    category: str | None
    amount: decimal.Decimal
    currency_code: str
    due_day: int | None
    notes: str | None
    source: str  # MANUAL | AI
    created_at: datetime.datetime
    updated_at: datetime.datetime | None

    @classmethod
    def from_entity(cls, r: Recurrence) -> RecurrenceResponse:
        assert r.id is not None and r.created_at is not None
        return cls(
            id=r.id,
            user_id=r.user_id,
            description=r.description,
            type=r.type,
            payment_type=r.payment_type,
            category=r.category,
            amount=r.amount,
            currency_code=r.currency_code,
            due_day=r.due_day,
            notes=r.notes,
            source=r.source,
            created_at=r.created_at,
            updated_at=r.updated_at,
        )


class RecurrenceProvisionRequest(BaseModel):
    """Body of POST /recurrences/provision.

    `reference_month` accepts any day of the month (it is moved to the 1st). Without it, the
    current month (UTC) is used.
    """

    model_config = ConfigDict(extra="forbid")

    reference_month: datetime.date | None = None


class RecurrenceProvisionResponse(BaseModel):
    reference_month: datetime.date
    created: list[FinancialEntryResponse]
    skipped_count: int  # recurrences that already had an entry in the month

    @classmethod
    def from_result(cls, result: ProvisioningResult) -> RecurrenceProvisionResponse:
        return cls(
            reference_month=result.reference_month,
            created=[FinancialEntryResponse.from_entity(e) for e in result.created],
            skipped_count=result.skipped_count,
        )
