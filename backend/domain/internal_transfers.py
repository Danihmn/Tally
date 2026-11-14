"""Pure rules to find transfers between two accounts of the household (no database access).

Only unambiguous pairs are returned. A transaction with more than one possible partner is
left out, to be reviewed by hand: a wrong pair would hide real spending from the totals.
"""

import uuid
from collections import defaultdict
from collections.abc import Mapping
from decimal import Decimal

from domain.entities import Transaction
from domain.transfer_documents import EXTERNAL, SAME_HOUSEHOLD, SAME_PERSON
from utils.dates import to_local_date

# A TED or a DOC can land a day or two after it left the other account.
MAX_DAYS_APART = 2

# (debit, credit, SAME_PERSON | SAME_HOUSEHOLD)
Pair = tuple[Transaction, Transaction, str]


def _days_apart(debit: Transaction, credit: Transaction) -> int:
    return abs((to_local_date(debit.date) - to_local_date(credit.date)).days)


def _kind(
    debit: Transaction,
    credit: Transaction,
    owner_by_account: Mapping[uuid.UUID, uuid.UUID],
) -> str | None:
    """SAME_PERSON when both accounts have the same owner, SAME_HOUSEHOLD when they do not.
    None when an account has no known owner."""
    debit_owner = owner_by_account.get(debit.bank_account_id)
    credit_owner = owner_by_account.get(credit.bank_account_id)
    if debit_owner is None or credit_owner is None:
        return None
    return SAME_PERSON if debit_owner == credit_owner else SAME_HOUSEHOLD


def _candidates(
    debits: list[Transaction],
    credits: list[Transaction],
    owner_by_account: Mapping[uuid.UUID, uuid.UUID],
    verdicts: Mapping[uuid.UUID, str | None],
) -> list[tuple[Transaction, Transaction, int, str]]:
    """Every (debit, credit, days apart, kind) that could be the two legs of one transfer.

    A verdict taken from the documents of a leg (SAME_PERSON or SAME_HOUSEHOLD) must agree
    with the kind the owners of the accounts say: the documents rule out wrong partners
    before any tie is looked at."""
    found = []
    for debit in debits:
        for credit in credits:
            if debit.bank_account_id == credit.bank_account_id:
                continue
            if debit.currency_code != credit.currency_code:
                continue
            gap = _days_apart(debit, credit)
            if gap > MAX_DAYS_APART:
                continue
            kind = _kind(debit, credit, owner_by_account)
            if kind is None:
                continue
            if any(
                verdicts.get(leg.id) not in (None, kind)  # type: ignore[arg-type]
                for leg in (debit, credit)
            ):
                continue
            found.append((debit, credit, gap, kind))
    return found


def _pair_same_amount(
    group: list[Transaction],
    owner_by_account: Mapping[uuid.UUID, uuid.UUID],
    verdicts: Mapping[uuid.UUID, str | None],
) -> list[Pair]:
    debits = [t for t in group if t.type == "DEBIT"]
    credits = [t for t in group if t.type == "CREDIT"]
    candidates = _candidates(debits, credits, owner_by_account, verdicts)

    # The closest date each transaction can have with a partner
    closest: dict[uuid.UUID, int] = {}
    for debit, credit, gap, _ in candidates:
        for transaction in (debit, credit):
            closest[transaction.id] = min(gap, closest.get(transaction.id, gap))  # type: ignore[index]

    # Only the pairs that are the best choice of both legs...
    best = [
        (debit, credit, kind)
        for debit, credit, gap, kind in candidates
        if gap == closest[debit.id] == closest[credit.id]  # type: ignore[index]
    ]

    # ...and where neither leg has a second best choice (a tie is ambiguous)
    uses: defaultdict[uuid.UUID, int] = defaultdict(int)
    for debit, credit, _ in best:
        uses[debit.id] += 1  # type: ignore[index]
        uses[credit.id] += 1  # type: ignore[index]
    return [
        (debit, credit, kind)
        for debit, credit, kind in best
        if uses[debit.id] == 1 and uses[credit.id] == 1  # type: ignore[index]
    ]


def find_internal_pairs(
    transactions: list[Transaction],
    owner_by_account: Mapping[uuid.UUID, uuid.UUID],
    verdicts: Mapping[uuid.UUID, str | None] | None = None,
) -> list[Pair]:
    """(debit, credit, kind) pairs among the transactions of the household.

    A pair is a DEBIT and a CREDIT of the same amount and currency, in different accounts,
    at most MAX_DAYS_APART local days apart. The direction comes from `type`, never from the
    sign of the amount. The kind comes from the owners of the two accounts: the same person
    (SAME_PERSON) or two people of the household (SAME_HOUSEHOLD).

    `verdicts` (transaction id -> what the documents said) narrows it: a transaction known to
    be EXTERNAL is never paired, and one known to be SAME_PERSON / SAME_HOUSEHOLD only pairs
    with a partner of that kind. Each transaction is in at most one pair, and a transaction
    with more than one equally good partner is not paired at all.
    """
    verdicts = verdicts or {}
    by_amount: defaultdict[Decimal, list[Transaction]] = defaultdict(list)
    for transaction in transactions:
        if transaction.id is None or verdicts.get(transaction.id) == EXTERNAL:
            continue
        by_amount[abs(transaction.amount)].append(transaction)

    pairs: list[Pair] = []
    for group in by_amount.values():
        pairs.extend(_pair_same_amount(group, owner_by_account, verdicts))
    return pairs
