"""Pure rules to find monthly patterns in the transactions (no database access).

The same transactions always give the same candidates: the model never guesses a recurrence,
it only shows these ones and asks the person to confirm them. The rule is explained in
`docs/recurrence-detection.md`.
"""

import hashlib
import re
import statistics
import unicodedata
import uuid
from collections import Counter, defaultdict
from collections.abc import Collection, Iterable, Mapping
from dataclasses import dataclass, field
from datetime import date
from decimal import Decimal
from itertools import pairwise

from domain.credit_card_bills import installment_of, is_bill_payment
from domain.entities import Recurrence
from domain.internal_transfers import find_internal_pairs
from domain.read_models import TransactionWithOwner
from domain.transaction_amounts import amount_in_currency
from domain.transfer_documents import SAME_HOUSEHOLD, SAME_PERSON
from utils.dates import to_local_date
from utils.money import round_to_cents

CURRENCY = "BRL"
DESCRIPTION_MAX_LENGTH = 200  # the same limit as the recurrences endpoint
CANDIDATE_ID_LENGTH = 8

# Weights of the confidence score (they add up to 1)
MONTHS_WEIGHT = Decimal("0.4")
AMOUNT_WEIGHT = Decimal("0.3")
TIMING_WEIGHT = Decimal("0.3")
# With this many months the "months" part of the score is full
FULL_SCORE_MONTHS = 6

_TYPE_BY_DIRECTION = {"DEBIT": "EXPENSES", "CREDIT": "REVENUES"}

# "PARC 03/10", "parcela 3 de 10": the installment of a purchase (it ends: not a recurrence)
_INSTALLMENT_MARKER = re.compile(
    r"\bparc(?:ela)?s?\.?\s*\d{1,3}\s*(?:/|de)\s*\d{1,3}\b", re.IGNORECASE
)
# 2026-11-05, 05/11/2026, 05/11, 05-11-26
_DATE = re.compile(
    r"\b\d{4}-\d{1,2}-\d{1,2}\b|\b\d{1,2}[/.-]\d{1,2}(?:[/.-]\d{2,4})?\b"
)
_NOT_LETTER = re.compile(r"[^a-z]+")


@dataclass(frozen=True, slots=True)
class DetectionSettings:
    """The knobs of the rule. The defaults are the ones the agent uses."""

    # Two amounts are "the same" when they differ by at most this fraction (0.10 = 10%)
    amount_tolerance: Decimal = Decimal("0.10")
    # Distinct months a pattern needs
    min_months: int = 3
    # Expected gap between two transactions, and how far a gap may be from it (days)
    interval_days: int = 30
    interval_tolerance_days: int = 7
    # The last transaction must be at most this old, or the pattern stopped
    max_days_since_last: int = 45


@dataclass(frozen=True, slots=True)
class Evidence:
    """One transaction behind a candidate. `date` is the local day, `amount` is absolute."""

    transaction_id: uuid.UUID
    date: date
    amount: Decimal
    description: str | None


@dataclass(slots=True)
class RecurrenceCandidate:
    """A monthly pattern found in the transactions: a recurrence that does not exist yet."""

    candidate_id: str
    household_id: uuid.UUID
    user_id: uuid.UUID
    description: str
    normalized_description: str
    type: str  # REVENUES | EXPENSES
    amount: Decimal  # median of the evidence
    due_day: int
    category: str | None
    payment_type: str  # DEBIT | CREDIT
    confidence: Decimal  # 0.00 to 1.00
    evidence: list[Evidence] = field(default_factory=list)

    @property
    def months(self) -> int:
        return len({(e.date.year, e.date.month) for e in self.evidence})

    def to_recurrence(self) -> Recurrence:
        """The recurrence to create after the person confirms the candidate."""
        first, last = self.evidence[0].date, self.evidence[-1].date
        return Recurrence(
            description=self.description,
            type=self.type,
            amount=self.amount,
            household_id=self.household_id,
            currency_code=CURRENCY,
            source="AI",
            status="ACTIVE",
            user_id=self.user_id,
            category=self.category,
            payment_type=self.payment_type,
            due_day=self.due_day,
            notes=(
                f"Detected from {len(self.evidence)} transactions between "
                f"{first.isoformat()} and {last.isoformat()}."
            ),
        )


def normalize_description(value: str | None) -> str:
    """Lowercase, no accents, dates, installment markers, digits or punctuation, single spaces.

    "NETFLIX.COM 05/11" and "Netflix.com 12/12" both become "netflix com"."""
    if not value:
        return ""
    value = _INSTALLMENT_MARKER.sub(" ", value)
    value = _DATE.sub(" ", value)
    value = unicodedata.normalize("NFKD", value.lower())
    value = "".join(c for c in value if not unicodedata.combining(c))
    return _NOT_LETTER.sub(" ", value).strip()


def _is_installment(item: TransactionWithOwner) -> bool:
    _, total = installment_of(item.transaction)
    if total is not None and total > 1:
        return True
    return bool(_INSTALLMENT_MARKER.search(item.transaction.description or ""))


def _amounts_match(a: Decimal, b: Decimal, tolerance: Decimal) -> bool:
    """True when the two (positive) amounts differ by at most `tolerance` of the bigger one."""
    bigger = max(a, b)
    return bigger == 0 or abs(a - b) <= bigger * tolerance


@dataclass(frozen=True, slots=True)
class _Row:
    item: TransactionWithOwner
    day: date
    amount: Decimal


def _eligible_rows(
    items: Iterable[TransactionWithOwner],
    owner_by_account: Mapping[uuid.UUID, uuid.UUID],
) -> list[_Row]:
    """The transactions that can be part of a recurrence (see "Left out" in the docs)."""
    items = [i for i in items if i.transaction.id is not None]
    unclassified = [
        i.transaction for i in items if i.transaction.internal_transfer is None
    ]
    paired = {
        leg.id
        for debit, credit, _ in find_internal_pairs(unclassified, owner_by_account)
        for leg in (debit, credit)
    }

    rows = []
    for item in items:
        t = item.transaction
        if t.internal_transfer in (SAME_PERSON, SAME_HOUSEHOLD) or t.id in paired:
            continue
        if t.type not in _TYPE_BY_DIRECTION or t.status != "POSTED":
            continue
        if is_bill_payment(t) or _is_installment(item):
            continue
        amount = amount_in_currency(t, CURRENCY)
        if amount is None or amount == 0:
            continue
        rows.append(_Row(item=item, day=to_local_date(t.date), amount=amount))
    return rows


def _split_by_amount(rows: list[_Row], tolerance: Decimal) -> list[list[_Row]]:
    """Sorted by amount, a new group starts where two amounts in a row stop matching."""
    groups: list[list[_Row]] = []
    for row in sorted(rows, key=lambda r: (r.amount, r.day)):
        if groups and _amounts_match(groups[-1][-1].amount, row.amount, tolerance):
            groups[-1].append(row)
        else:
            groups.append([row])
    return groups


def _longest_monthly_chain(rows: list[_Row], settings: DetectionSettings) -> list[_Row]:
    """The longest run of transactions (date order) whose gaps are all about one month.

    A gap outside the window breaks the run. On a tie, the newest run wins."""
    low = settings.interval_days - settings.interval_tolerance_days
    high = settings.interval_days + settings.interval_tolerance_days
    ordered = sorted(rows, key=lambda r: (r.day, str(r.item.transaction.id)))
    best: list[_Row] = []
    current: list[_Row] = []
    for row in ordered:
        if current and low <= (row.day - current[-1].day).days <= high:
            current.append(row)
        else:
            current = [row]
        if len(current) >= len(best):
            best = list(current)
    return best


def _months(rows: list[_Row]) -> int:
    return len({(r.day.year, r.day.month) for r in rows})


def _clamp(value: Decimal) -> Decimal:
    return max(Decimal(0), min(Decimal(1), value))


def _confidence(
    chain: list[_Row], median: Decimal, settings: DetectionSettings
) -> Decimal:
    months = _clamp(Decimal(_months(chain)) / FULL_SCORE_MONTHS)

    amounts = [r.amount for r in chain]
    spread = (max(amounts) - min(amounts)) / median
    amount = _clamp(1 - spread / settings.amount_tolerance)

    gaps = [(b.day - a.day).days for a, b in pairwise(chain)]
    error = Decimal(sum(abs(g - settings.interval_days) for g in gaps)) / len(gaps)
    timing = _clamp(1 - error / max(settings.interval_tolerance_days, 1))

    score = MONTHS_WEIGHT * months + AMOUNT_WEIGHT * amount + TIMING_WEIGHT * timing
    return score.quantize(Decimal("0.01"))


def _most_common(values: list[str | None]) -> str | None:
    """The most common non empty value; on a tie, the one seen last (the newest)."""
    present = [v for v in values if v]
    if not present:
        return None
    counts = Counter(present)
    top = max(counts.values())
    return next(v for v in reversed(present) if counts[v] == top)


def _candidate_id(user_id: uuid.UUID, type_: str, normalized: str, first: _Row) -> str:
    """Stable while the pattern goes on: a new month adds to the end of the chain."""
    key = f"{user_id}|{type_}|{normalized}|{first.item.transaction.id}"
    return hashlib.sha256(key.encode()).hexdigest()[:CANDIDATE_ID_LENGTH]


def _build_candidate(
    chain: list[_Row],
    normalized: str,
    credit_card_accounts: Collection[uuid.UUID],
    settings: DetectionSettings,
) -> RecurrenceCandidate:
    newest = chain[-1].item
    type_ = _TYPE_BY_DIRECTION[newest.transaction.type]
    median = round_to_cents(statistics.median(r.amount for r in chain))
    on_card = sum(
        1 for r in chain if r.item.transaction.bank_account_id in credit_card_accounts
    )
    description = (newest.transaction.description or normalized).strip()
    return RecurrenceCandidate(
        candidate_id=_candidate_id(newest.user_id, type_, normalized, chain[0]),
        household_id=newest.transaction.household_id,
        user_id=newest.user_id,
        description=description[:DESCRIPTION_MAX_LENGTH],
        normalized_description=normalized,
        type=type_,
        amount=median,
        due_day=statistics.median_low(r.day.day for r in chain),
        category=_most_common([r.item.transaction.category for r in chain]),
        payment_type="CREDIT" if on_card * 2 > len(chain) else "DEBIT",
        confidence=_confidence(chain, median, settings),
        evidence=[
            Evidence(
                transaction_id=r.item.transaction.id,  # type: ignore[arg-type]
                date=r.day,
                amount=r.amount,
                description=r.item.transaction.description,
            )
            for r in chain
        ],
    )


def matches_recurrence(
    candidate: RecurrenceCandidate, recurrence: Recurrence, tolerance: Decimal
) -> bool:
    """True when the ACTIVE recurrence already covers the candidate (same type, a matching
    description and an amount inside the tolerance). The owner is not compared: a bill kept
    under the partner's name is still the same bill."""
    if recurrence.status != "ACTIVE" or recurrence.type != candidate.type:
        return False
    if not _amounts_match(recurrence.amount, candidate.amount, tolerance):
        return False
    existing = normalize_description(recurrence.description)
    found = candidate.normalized_description
    if not existing:
        return False
    return existing == found or existing in found or found in existing


def detect_recurrences(
    items: Iterable[TransactionWithOwner],
    today: date,
    owner_by_account: Mapping[uuid.UUID, uuid.UUID] | None = None,
    credit_card_accounts: Collection[uuid.UUID] = (),
    existing: Iterable[Recurrence] = (),
    settings: DetectionSettings | None = None,
) -> list[RecurrenceCandidate]:
    """The monthly patterns in the transactions of one household, best confidence first.

    `owner_by_account` (account id -> person) finds the internal transfers that are not
    classified yet; `credit_card_accounts` gives the payment type; `existing` are the
    recurrences of the household (an ACTIVE one that matches drops the candidate)."""
    settings = settings or DetectionSettings()
    rows = _eligible_rows(items, owner_by_account or {})

    groups: defaultdict[tuple[uuid.UUID, str, str], list[_Row]] = defaultdict(list)
    for row in rows:
        normalized = normalize_description(row.item.transaction.description)
        if normalized:
            key = (row.item.user_id, row.item.transaction.type, normalized)
            groups[key].append(row)

    existing = list(existing)
    candidates = []
    for (_, _, normalized), group in groups.items():
        for same_amount in _split_by_amount(group, settings.amount_tolerance):
            chain = _longest_monthly_chain(same_amount, settings)
            if _months(chain) < settings.min_months:
                continue
            if (today - chain[-1].day).days > settings.max_days_since_last:
                continue
            candidate = _build_candidate(
                chain, normalized, credit_card_accounts, settings
            )
            if any(
                matches_recurrence(candidate, r, settings.amount_tolerance)
                for r in existing
            ):
                continue
            candidates.append(candidate)

    candidates.sort(key=lambda c: (-c.confidence, -c.amount, c.candidate_id))
    return candidates
