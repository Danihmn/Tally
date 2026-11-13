"""Pure rules to find transfers between two accounts of the same person (no database access).

Only unambiguous pairs are returned. A transaction with more than one possible partner is
left out, to be reviewed by hand: a wrong pair would hide real spending from the totals.
"""

import uuid
from collections import defaultdict
from decimal import Decimal

from domain.entities import Transaction
from utils.dates import to_local_date

# A TED or a DOC can land a day or two after it left the other account.
MAX_DAYS_APART = 2


def _days_apart(debit: Transaction, credit: Transaction) -> int:
    return abs((to_local_date(debit.date) - to_local_date(credit.date)).days)


def _candidates(
    debits: list[Transaction], credits: list[Transaction]
) -> list[tuple[Transaction, Transaction, int]]:
    """Every (debit, credit, days apart) that could be the two legs of one transfer."""
    found = []
    for debit in debits:
        for credit in credits:
            if debit.bank_account_id == credit.bank_account_id:
                continue
            if debit.currency_code != credit.currency_code:
                continue
            gap = _days_apart(debit, credit)
            if gap <= MAX_DAYS_APART:
                found.append((debit, credit, gap))
    return found


def _pair_same_amount(
    group: list[Transaction],
) -> list[tuple[Transaction, Transaction]]:
    debits = [t for t in group if t.type == "DEBIT"]
    credits = [t for t in group if t.type == "CREDIT"]
    candidates = _candidates(debits, credits)

    # The closest date each transaction can have with a partner
    closest: dict[uuid.UUID, int] = {}
    for debit, credit, gap in candidates:
        for transaction in (debit, credit):
            closest[transaction.id] = min(gap, closest.get(transaction.id, gap))  # type: ignore[index]

    # Only the pairs that are the best choice of both legs...
    best = [
        (debit, credit)
        for debit, credit, gap in candidates
        if gap == closest[debit.id] == closest[credit.id]  # type: ignore[index]
    ]

    # ...and where neither leg has a second best choice (a tie is ambiguous)
    uses: defaultdict[uuid.UUID, int] = defaultdict(int)
    for debit, credit in best:
        uses[debit.id] += 1  # type: ignore[index]
        uses[credit.id] += 1  # type: ignore[index]
    return [
        (debit, credit)
        for debit, credit in best
        if uses[debit.id] == 1 and uses[credit.id] == 1  # type: ignore[index]
    ]


def find_same_person_pairs(
    transactions: list[Transaction],
) -> list[tuple[Transaction, Transaction]]:
    """(debit, credit) pairs among the transactions of one person.

    A pair is a DEBIT and a CREDIT of the same amount and currency, in different accounts,
    at most MAX_DAYS_APART local days apart. The direction comes from `type`, never from the
    sign of the amount. Each transaction is in at most one pair, and a transaction that has
    more than one equally good partner is not paired at all.
    """
    by_amount: defaultdict[Decimal, list[Transaction]] = defaultdict(list)
    for transaction in transactions:
        if transaction.id is not None:
            by_amount[abs(transaction.amount)].append(transaction)

    pairs: list[tuple[Transaction, Transaction]] = []
    for group in by_amount.values():
        pairs.extend(_pair_same_amount(group))
    return pairs
