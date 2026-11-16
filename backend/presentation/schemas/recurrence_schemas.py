from __future__ import annotations

import datetime
import decimal
import uuid
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from domain.entities import Recurrence
from domain.read_models import RecurrenceFilters

_Money = Annotated[decimal.Decimal, Field(gt=0, max_digits=16, decimal_places=2)]
_Description = Annotated[str, Field(min_length=1, max_length=200)]
_Category = Annotated[str, Field(min_length=1, max_length=100)]
_Notes = Annotated[str, Field(min_length=1, max_length=1000)]
_DueDay = Annotated[int, Field(ge=1, le=31)]
_Status = Literal["ACTIVE", "CANCELLED"]


class RecurrenceQuery(BaseModel):
    """Query string of GET /recurrences. The household comes from the logged user.

    `status` defaults to ACTIVE: the cancelled ones are listed only when asked."""

    model_config = ConfigDict(extra="forbid")

    status: _Status = "ACTIVE"
    type: Literal["REVENUES", "EXPENSES"] | None = None
    search: str | None = Field(default=None, min_length=1, max_length=100)
    limit: int = Field(default=50, ge=1, le=200)
    offset: int = Field(default=0, ge=0)

    def to_filters(self, household_id: uuid.UUID) -> RecurrenceFilters:
        return RecurrenceFilters(
            household_id=household_id,
            type=self.type,
            search=self.search,
            status=self.status,
        )


class RecurrenceCreate(BaseModel):
    """Body of POST /recurrences. `user_id` is the owner, a person of the house of the
    logged user (the household comes from the login).

    `due_day` 29 to 31 falls on the last day of the shorter months."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    user_id: uuid.UUID
    description: _Description
    type: Literal["REVENUES", "EXPENSES"]
    amount: _Money
    due_day: _DueDay | None = None
    payment_type: Literal["DEBIT", "CREDIT"] | None = None
    category: _Category | None = None
    notes: _Notes | None = None

    def to_entity(self, household_id: uuid.UUID) -> Recurrence:
        return Recurrence(
            description=self.description,
            type=self.type,
            amount=self.amount,
            household_id=household_id,
            user_id=self.user_id,
            due_day=self.due_day,
            payment_type=self.payment_type,
            category=self.category,
            notes=self.notes,
        )


class RecurrenceUpdate(BaseModel):
    """Body of PATCH /recurrences/{id}. Send only what changes; the optional columns accept null.

    Cancel or reactivate with `status`. `user_id` changes the owner (a person of the house)."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    user_id: uuid.UUID | None = None
    status: _Status | None = None
    description: _Description | None = None
    type: Literal["REVENUES", "EXPENSES"] | None = None
    amount: _Money | None = None
    due_day: _DueDay | None = None
    payment_type: Literal["DEBIT", "CREDIT"] | None = None
    category: _Category | None = None
    notes: _Notes | None = None

    @model_validator(mode="after")
    def _check_fields(self) -> RecurrenceUpdate:
        if not self.model_fields_set:
            raise ValueError("send at least one field")
        for name in ("description", "type", "amount", "user_id", "status"):
            if name in self.model_fields_set and getattr(self, name) is None:
                raise ValueError(f"{name} cannot be null")
        return self


class RecurrenceResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID | None
    description: str
    type: str  # REVENUES | EXPENSES
    amount: decimal.Decimal
    currency_code: str
    source: str  # MANUAL | AI
    status: str  # ACTIVE | CANCELLED
    category: str | None
    payment_type: str | None  # DEBIT | CREDIT
    notes: str | None
    due_day: int | None  # 1..31
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
            amount=r.amount,
            currency_code=r.currency_code,
            source=r.source,
            status=r.status,
            category=r.category,
            payment_type=r.payment_type,
            notes=r.notes,
            due_day=r.due_day,
            created_at=r.created_at,
            updated_at=r.updated_at,
        )


class ProvisionResponse(BaseModel):
    reference_month: datetime.date  # First day of the provisioned month
    created: int  # Entries created now
    skipped: int  # Recurrences that already had their entry in that month
