from datetime import datetime
from decimal import Decimal
from enum import StrEnum
from typing import Annotated, Any
from uuid import UUID

from pydantic import Field, field_validator

from integrations.pluggy.schemas.pluggy_model import PluggyModel
from utils.money import round_to_cents_or_none


class TransactionStatus(StrEnum):
    POSTED = "POSTED"
    PENDING = "PENDING"


class TransactionType(StrEnum):
    DEBIT = "DEBIT"
    CREDIT = "CREDIT"


class TransactionResponseSchema(PluggyModel):
    id: UUID
    account_id: UUID
    created_at: datetime
    updated_at: datetime
    date: datetime
    description: str
    description_raw: str | None = None
    currency_code: Annotated[str, Field(min_length=3, max_length=3)]
    amount: Decimal
    balance: Decimal | None = None
    category: str | None = None
    provider_code: str | None = None
    provider_id: str | None = None
    status: TransactionStatus
    type: TransactionType
    category_id: str | None = None
    operation_type: str | None = None
    operation_type_additional_info: str | None = None
    amount_in_account_currency: Decimal | None = None
    payment_data: dict[str, Any] | None = None
    credit_card_metadata: dict[str, Any] | None = None
    merchant: dict[str, Any] | None = None

    @field_validator("amount", "balance", "amount_in_account_currency")
    @classmethod
    def _round_to_cents(cls, value: Decimal | None) -> Decimal | None:
        # The database columns are numeric(18, 2); keeping the same scale (and the
        # same tie rounding as Postgres) avoids false differences when comparing.
        return round_to_cents_or_none(value)
