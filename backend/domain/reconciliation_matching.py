"""Pure rules to pair financial entries with bank transactions (no database access).

Only unambiguous pairs are returned. Anything else is left for the AI agent.
"""

import datetime
import uuid
from collections import defaultdict

from domain.entities import FinancialEntry, Transaction
from domain.transaction_amounts import amount_in_currency

DATE_TOLERANCE_DAYS = 3

# The direction of the money: an expense leaves the account (DEBIT), a revenue enters it (CREDIT).
ENTRY_TYPE_TO_TRANSACTION_TYPE = {"EXPENSES": "DEBIT", "REVENUES": "CREDIT"}


def is_match(entry: FinancialEntry, transaction: Transaction) -> bool:
    """True when the transaction looks like the payment/receipt of the entry."""
    # A purchase in another currency is compared by the value the bank converted (what was charged)
    amount = amount_in_currency(transaction, entry.currency_code)
    if amount is None or amount != entry.amount:
        return False
    if transaction.type != ENTRY_TYPE_TO_TRANSACTION_TYPE.get(entry.type):
        return False
    if (
        entry.bank_account_id is not None
        and transaction.bank_account_id != entry.bank_account_id
    ):
        return False

    transaction_date = transaction.date.date()
    if entry.due_date is not None:
        tolerance = datetime.timedelta(days=DATE_TOLERANCE_DAYS)
        return abs(transaction_date - entry.due_date) <= tolerance
    return (transaction_date.year, transaction_date.month) == (
        entry.reference_month.year,
        entry.reference_month.month,
    )


def find_matches(
    entries: list[FinancialEntry], transactions: list[Transaction]
) -> list[tuple[FinancialEntry, Transaction]]:
    """Pairs where the entry has exactly one candidate transaction and that
    transaction is the candidate of exactly one entry (both directions)."""
    candidates: dict[uuid.UUID, list[Transaction]] = {}
    entries_per_transaction: defaultdict[uuid.UUID, int] = defaultdict(int)

    for entry in entries:
        if entry.id is None:
            continue
        found = [t for t in transactions if t.id is not None and is_match(entry, t)]
        candidates[entry.id] = found
        for transaction in found:
            entries_per_transaction[transaction.id] += 1  # type: ignore[index]

    pairs: list[tuple[FinancialEntry, Transaction]] = []
    for entry in entries:
        if entry.id is None:
            continue
        found = candidates[entry.id]
        if len(found) == 1 and entries_per_transaction[found[0].id] == 1:  # type: ignore[index]
            pairs.append((entry, found[0]))
    return pairs
