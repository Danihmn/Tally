from datetime import UTC, datetime
from decimal import Decimal

from pydantic import field_validator

from integrations.pluggy.schemas.pluggy_model import PluggyModel
from utils.money import round_to_cents, round_to_cents_or_none

# Amounts are rounded to cents: the database columns are numeric(18, 2), and keeping the same
# scale (and the same tie rounding as Postgres) avoids false differences when comparing.


class AccountResponseSchemaBankData(PluggyModel):
    transfer_number: str | None = None
    closing_balance: Decimal | None = None
    automatically_invested_balance: Decimal | None = None
    overdraft_contracted_limit: Decimal | None = None
    overdraft_used_limit: Decimal | None = None
    unarranged_overdraft_amount: Decimal | None = None

    @field_validator(
        "closing_balance",
        "automatically_invested_balance",
        "overdraft_contracted_limit",
        "overdraft_used_limit",
        "unarranged_overdraft_amount",
    )
    @classmethod
    def _round(cls, value: Decimal | None) -> Decimal | None:
        return round_to_cents_or_none(value)


class AccountResponseSchemaCreditData(PluggyModel):
    level: str | None = None
    brand: str | None = None
    balance_close_date: datetime | None = None
    balance_due_date: datetime | None = None
    available_credit_limit: Decimal | None = None
    balance_foreign_currency: Decimal | None = None
    minimum_payment: Decimal | None = None
    credit_limit: Decimal | None = None
    status: str | None = None
    holder_type: str | None = None

    @field_validator(
        "available_credit_limit",
        "balance_foreign_currency",
        "minimum_payment",
        "credit_limit",
    )
    @classmethod
    def _round(cls, value: Decimal | None) -> Decimal | None:
        return round_to_cents_or_none(value)

    @field_validator("balance_close_date", "balance_due_date")
    @classmethod
    def _as_utc(cls, value: datetime | None) -> datetime | None:
        # Pluggy may send a plain date ("2022-01-03"); the column is timestamptz,
        # so an aware value avoids false differences when comparing.
        if value is not None and value.tzinfo is None:
            return value.replace(tzinfo=UTC)
        return value


class AccountResponseSchema(PluggyModel):
    id: str
    created_at: datetime
    updated_at: datetime
    type: str
    subtype: str
    number: str
    name: str
    marketing_name: str | None = None
    balance: Decimal
    item_id: str
    tax_number: str | None = None
    owner: str | None = None
    currency_code: str
    bank_data: AccountResponseSchemaBankData | None = None
    credit_data: AccountResponseSchemaCreditData | None = None

    @field_validator("balance")
    @classmethod
    def _round_balance(cls, value: Decimal) -> Decimal:
        return round_to_cents(value)
