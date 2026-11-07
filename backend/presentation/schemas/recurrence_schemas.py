from __future__ import annotations

import datetime
import decimal
import uuid
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from domain.read_models import RecurrenceFilters
from presentation.schemas._validators import check_amount_range


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

    def to_filters(self) -> RecurrenceFilters:
        return RecurrenceFilters(
            user_id=self.user_id,
            type=self.type,
            payment_type=self.payment_type,
            category=self.category,
            min_amount=self.min_amount,
            max_amount=self.max_amount,
        )


class RecurrenceCreate(BaseModel):
    """Body of POST /recurrences. `user_id` defaults to the logged user."""

    model_config = ConfigDict(extra="forbid")

    type: Literal["REVENUES", "EXPENSES"]
    payment_type: Literal["DEBIT", "CREDIT"] | None = None
    category: str | None = Field(default=None, min_length=1, max_length=100)
    amount: decimal.Decimal = Field(gt=0, max_digits=18, decimal_places=2)
    currency_code: str = Field(default="BRL", min_length=3, max_length=3)
    user_id: uuid.UUID | None = None


class RecurrenceResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID | None
    type: str  # REVENUES | EXPENSES
    payment_type: str | None  # DEBIT | CREDIT
    category: str | None
    amount: decimal.Decimal
    currency_code: str
    created_at: datetime.datetime
    updated_at: datetime.datetime | None
