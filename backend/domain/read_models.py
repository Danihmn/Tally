"""Read-only shapes used by the query endpoints.

They are not tables: they join a stored entity with its owner (the user of the Pluggy item),
or hold the filters of a query.
"""

import datetime
import decimal
import uuid
from dataclasses import dataclass, field

from domain.entities import BankAccount, CreditData, Transaction


@dataclass(slots=True)
class BankAccountWithOwner:
    account: BankAccount
    user_id: uuid.UUID


@dataclass(slots=True)
class AccountBalance:
    """An account with its owner and, for a credit card, the limits that come with it."""

    account: BankAccount
    user_id: uuid.UUID
    credit_data: CreditData | None = None


@dataclass(slots=True)
class TransactionWithOwner:
    transaction: Transaction
    user_id: uuid.UUID


@dataclass(slots=True)
class TransactionSummary:
    """Totals of every transaction that matches a filter (not just one page). Absolute values."""

    debit_total: decimal.Decimal = decimal.Decimal("0.00")
    credit_total: decimal.Decimal = decimal.Decimal("0.00")
    debit_count: int = 0
    credit_count: int = 0


@dataclass(slots=True)
class TransactionGroupTotal:
    """Totals of one group (owner and/or category) of transactions. Absolute values.

    `user_id` is None when the query was not grouped by owner; `category` is None when it was not
    grouped by category, or for the transactions that have no category.
    """

    user_id: uuid.UUID | None = None
    category: str | None = None
    debit_total: decimal.Decimal = decimal.Decimal("0.00")
    credit_total: decimal.Decimal = decimal.Decimal("0.00")
    debit_count: int = 0
    credit_count: int = 0


@dataclass(slots=True)
class TopExpense:
    """One of the biggest expenses of a period. `date` is the UTC day. Absolute value."""

    date: datetime.date
    description: str | None
    amount: decimal.Decimal


@dataclass(slots=True)
class DailyTotal:
    """What was spent in one UTC day. Absolute value."""

    day: datetime.date
    total: decimal.Decimal


@dataclass(slots=True)
class TransactionFilters:
    """Every field is optional: None means "do not filter by it"."""

    household_id: uuid.UUID | None = None
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
    # SAME_PERSON | SAME_HOUSEHOLD | NOT_INTERNAL_TRANSFER | UNCLASSIFIED (not classified yet)
    internal_transfer: str | None = None
    # Leaves internal transfers out of the totals: SAME_PERSON always, SAME_HOUSEHOLD only
    # when there is no user_id (the household view). Not classified rows still count.
    exclude_internal_transfers: bool = False
    # Only the transactions with an active reconciliation with this entry
    financial_entry_id: uuid.UUID | None = None


@dataclass(slots=True)
class FinancialEntryFilters:
    """Every field is optional: None means "do not filter by it"."""

    household_id: uuid.UUID | None = None
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
    # Only the entries with an active reconciliation with this transaction
    transaction_id: uuid.UUID | None = None


@dataclass(slots=True)
class FinancialEntryTotals:
    """Totals and counts of the entries of one type (REVENUES or EXPENSES), per status."""

    planned_total: decimal.Decimal = decimal.Decimal("0.00")
    planned_count: int = 0
    reconciled_total: decimal.Decimal = decimal.Decimal("0.00")
    reconciled_count: int = 0
    cancelled_total: decimal.Decimal = decimal.Decimal("0.00")
    cancelled_count: int = 0


@dataclass(slots=True)
class FinancialEntrySummary:
    """Totals of every entry that matches a filter (not just one page)."""

    revenues: FinancialEntryTotals = field(default_factory=FinancialEntryTotals)
    expenses: FinancialEntryTotals = field(default_factory=FinancialEntryTotals)
