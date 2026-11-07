"""Read-only shapes used by the query endpoints.

They are not tables: they join a stored entity with its owner (the user of the Pluggy item),
or hold the filters of a query.
"""

import datetime
import decimal
import uuid
from dataclasses import dataclass

from domain.entities import BankAccount, Transaction


@dataclass(slots=True)
class BankAccountWithOwner:
    account: BankAccount
    user_id: uuid.UUID


@dataclass(slots=True)
class TransactionWithOwner:
    transaction: Transaction
    user_id: uuid.UUID


@dataclass(slots=True)
class TransactionFilters:
    """Every field is optional: None means "do not filter by it"."""

    user_id: uuid.UUID | None = None
    bank_account_id: uuid.UUID | None = None
    date_from: datetime.datetime | None = None  # inclusive
    date_to: datetime.datetime | None = None  # exclusive
    type: str | None = None  # DEBIT | CREDIT
    status: str | None = None  # POSTED | PENDING
    category: str | None = None
    search: str | None = None  # case-insensitive, inside the description
    min_amount: decimal.Decimal | None = None  # compared with abs(amount)
    max_amount: decimal.Decimal | None = None


@dataclass(slots=True)
class RecurrenceFilters:
    """Every field is optional: None means "do not filter by it"."""

    user_id: uuid.UUID | None = None
    type: str | None = None  # REVENUES | EXPENSES
    payment_type: str | None = None  # DEBIT | CREDIT
    category: str | None = None
    min_amount: decimal.Decimal | None = None
    max_amount: decimal.Decimal | None = None


@dataclass(slots=True)
class FinancialEntryFilters:
    """Every field is optional: None means "do not filter by it"."""

    user_id: uuid.UUID | None = None
    bank_account_id: uuid.UUID | None = None
    type: str | None = None  # REVENUES | EXPENSES
    payment_type: str | None = None  # DEBIT | CREDIT
    status: str | None = None  # PLANNED | RECONCILED | CANCELLED
    category: str | None = None
    search: str | None = None  # case-insensitive, inside the description
    reference_month_from: datetime.date | None = None  # inclusive, first day of month
    reference_month_to: datetime.date | None = None  # inclusive, first day of month
    due_date_from: datetime.date | None = None  # inclusive
    due_date_to: datetime.date | None = None  # inclusive
    min_amount: decimal.Decimal | None = None
    max_amount: decimal.Decimal | None = None
