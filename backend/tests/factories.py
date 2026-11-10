"""Builders with safe defaults for the tests. Pass only the fields the test cares about."""

import dataclasses
import datetime
import uuid
from contextlib import contextmanager
from decimal import Decimal
from types import SimpleNamespace
from typing import Any
from unittest.mock import MagicMock

from domain.entities import (
    FinancialEntry,
    PluggyItem,
    Reconciliation,
    Transaction,
    User,
)
from integrations.pluggy.schemas.transaction.transaction_response_schema import (
    TransactionResponseSchema,
)
from integrations.pluggy.schemas.webhook.webhook_response_schema import (
    WebhookResponseSchema,
)

UTC = datetime.UTC
ACCOUNT_ID = uuid.UUID("00000000-0000-0000-0000-00000000a001")
USER_ID = uuid.UUID("00000000-0000-0000-0000-00000000b001")


def utc(year: int, month: int, day: int, hour: int = 12) -> datetime.datetime:
    return datetime.datetime(year, month, day, hour, tzinfo=UTC)


def make_transaction(**overrides: Any) -> Transaction:
    values: dict[str, Any] = {
        "id": uuid.uuid4(),
        "bank_account_id": ACCOUNT_ID,
        "pluggy_transaction_id": uuid.uuid4(),
        "date": utc(2026, 11, 5),
        "currency_code": "BRL",
        "amount": Decimal("-100.00"),
        "status": "POSTED",
        "type": "DEBIT",
        "description": "Market",
    }
    values.update(overrides)
    return Transaction(**values)


def make_incoming(stored: Transaction, **overrides: Any) -> Transaction:
    """The same transaction as Pluggy returns it: no id of ours, same Pluggy fields."""
    values = {
        field.name: getattr(stored, field.name)
        for field in dataclasses.fields(Transaction)
        if field.name not in ("id", "created_at", "updated_at", "deleted_at")
    }
    values.update(overrides)
    return Transaction(**values)


def make_entry(**overrides: Any) -> FinancialEntry:
    values: dict[str, Any] = {
        "id": uuid.uuid4(),
        "user_id": USER_ID,
        "description": "Market",
        "type": "EXPENSES",
        "amount": Decimal("100.00"),
        "reference_month": datetime.date(2026, 11, 1),
        "currency_code": "BRL",
    }
    values.update(overrides)
    return FinancialEntry(**values)


def make_reconciliation(**overrides: Any) -> Reconciliation:
    values: dict[str, Any] = {
        "id": uuid.uuid4(),
        "financial_entry_id": uuid.uuid4(),
        "transaction_id": uuid.uuid4(),
        "source": "AUTO",
    }
    values.update(overrides)
    return Reconciliation(**values)


def make_user(**overrides: Any) -> User:
    values: dict[str, Any] = {
        "id": USER_ID,
        "first_name": "Test",
        "email": "test@example.com",
        "hashed_password": "hash",
        "pluggy_client_id": uuid.uuid4(),
        "pluggy_client_secret_crypto": "secret-crypto",
    }
    values.update(overrides)
    return User(**values)


def make_pluggy_item(**overrides: Any) -> PluggyItem:
    values: dict[str, Any] = {
        "id": uuid.uuid4(),
        "user_id": USER_ID,
        "pluggy_item_id": uuid.uuid4(),
    }
    values.update(overrides)
    return PluggyItem(**values)


def make_transaction_schema(**overrides: Any) -> TransactionResponseSchema:
    values: dict[str, Any] = {
        "id": uuid.uuid4(),
        "account_id": uuid.uuid4(),
        "created_at": utc(2026, 11, 5),
        "updated_at": utc(2026, 11, 5),
        "date": utc(2026, 11, 5),
        "description": "Market",
        "currency_code": "BRL",
        "amount": Decimal("-100.00"),
        "status": "POSTED",
        "type": "DEBIT",
    }
    values.update(overrides)
    return TransactionResponseSchema.model_validate(values)


def make_webhook(**overrides: Any) -> WebhookResponseSchema:
    values: dict[str, Any] = {
        "id": uuid.uuid4(),
        "url": "https://api.test/webhooks/pluggy/items/created",
        "event": "item/created",
        "headers": {},
    }
    values.update(overrides)
    return WebhookResponseSchema.model_validate(values)


def page(results: list[Any], next: str | None = None) -> SimpleNamespace:
    """A Pluggy V2 list response (only `results` and `next` are read)."""
    return SimpleNamespace(results=results, next=next)


def fake_get_session(session: MagicMock):
    """Replaces `get_session()`: yields the given mock instead of opening a database session."""

    @contextmanager
    def _get_session():
        yield session

    return _get_session
