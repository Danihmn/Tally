import dataclasses
import datetime
import decimal
import uuid

from sqlalchemy.orm import Session

from domain.entities import Transaction
from domain.read_models import (
    DailyTotal,
    TopExpense,
    TransactionFilters,
    TransactionGroupTotal,
    TransactionSummary,
    TransactionWithOwner,
)
from infra.repositories import transactions_repository
from services.common.exceptions import translate_repository_errors
from services.common.mappers import to_entities, to_entity, to_values
from utils.money import round_to_cents

# Written only by the classification of the internal transfers, never by the Pluggy sync:
# sending them (as None) on a re-sync would erase the classification.
CLASSIFICATION_FIELDS = (
    "internal_transfer",
    "internal_transfer_classification_source",
)


@translate_repository_errors
def upsert_transactions(
    session: Session, transactions: list[Transaction]
) -> list[Transaction]:
    saved = transactions_repository.upsert_transactions(
        session, [to_values(t, exclude=CLASSIFICATION_FIELDS) for t in transactions]
    )
    return to_entities(Transaction, saved)


@translate_repository_errors
def list_transactions_since(
    session: Session,
    bank_account_id: uuid.UUID,
    date_from: datetime.datetime,
    include_deleted: bool = False,
) -> list[Transaction]:
    transactions = transactions_repository.list_transactions_since(
        session, bank_account_id, date_from, include_deleted
    )
    return to_entities(Transaction, transactions)


@translate_repository_errors
def mark_transactions_deleted(session: Session, ids: list[uuid.UUID]) -> None:
    transactions_repository.soft_delete_transactions(session, ids)


@translate_repository_errors
def update_transactions(session: Session, transactions: list[Transaction]) -> None:
    transactions_repository.update_transactions(
        session, [to_values(t, exclude=CLASSIFICATION_FIELDS) for t in transactions]
    )


@translate_repository_errors
def list_unclassified_transactions(
    session: Session, account_ids: list[uuid.UUID]
) -> list[Transaction]:
    """POSTED transactions of the accounts that are not classified as internal transfer yet."""
    if not account_ids:
        return []
    transactions = transactions_repository.list_unclassified_posted_by_accounts(
        session, account_ids
    )
    return to_entities(Transaction, transactions)


@translate_repository_errors
def mark_internal_transfer(
    session: Session, ids: list[uuid.UUID], value: str, source: str
) -> int:
    """Classifies the transactions (value: SAME_PERSON | SAME_HOUSEHOLD | NOT_INTERNAL_TRANSFER,
    source: MANUAL | AUTO). The already classified ones are not changed. Returns how many were."""
    if not ids:
        return 0
    return transactions_repository.set_internal_transfer(session, ids, value, source)


@translate_repository_errors
def search_transactions(
    session: Session,
    filters: TransactionFilters,
    limit: int = 50,
    offset: int = 0,
) -> tuple[list[TransactionWithOwner], int]:
    """A page of transactions (newest first) and the total that match the filters."""
    rows = transactions_repository.search_transactions(session, filters, limit, offset)
    total = transactions_repository.count_transactions(session, filters)
    items = [
        TransactionWithOwner(transaction=to_entity(Transaction, t), user_id=user_id)
        for t, user_id in rows
    ]
    return items, total


@translate_repository_errors
def summarize_transactions(
    session: Session, filters: TransactionFilters
) -> TransactionSummary:
    """Debit and credit totals (absolute values) and counts of everything the filters match."""
    summary = TransactionSummary()
    for type_, total, count in transactions_repository.summarize_transactions(
        session, filters
    ):
        if type_ == "DEBIT":
            summary.debit_total, summary.debit_count = total, count
        elif type_ == "CREDIT":
            summary.credit_total, summary.credit_count = total, count
    return summary


@translate_repository_errors
def get_total_expenses(
    session: Session, filters: TransactionFilters
) -> decimal.Decimal:
    """Sum of the debits (money out) that match the filters. Absolute value. Automatically excludes credit card payments."""
    return transactions_repository.sum_transactions_amount(
        session,
        dataclasses.replace(filters, type="DEBIT"),
    )


@translate_repository_errors
def get_total_revenues(
    session: Session, filters: TransactionFilters
) -> decimal.Decimal:
    """Sum of the credits (money in) that match the filters. Absolute value. Automatically excludes credit card payments."""
    return transactions_repository.sum_transactions_amount(
        session,
        dataclasses.replace(filters, type="CREDIT"),
    )


def get_balance(session: Session, filters: TransactionFilters) -> decimal.Decimal:
    """Revenues minus expenses of the period. Negative when the period spent more than it got."""
    return get_total_revenues(session, filters) - get_total_expenses(session, filters)


@translate_repository_errors
def get_top_expenses(
    session: Session, filters: TransactionFilters, limit: int
) -> list[TopExpense]:
    """The `limit` biggest debits that match the filters, biggest first. Automatically excludes credit card payments."""
    rows = transactions_repository.list_top_transactions(
        session,
        dataclasses.replace(filters, type="DEBIT"),
        limit,
    )
    return [
        TopExpense(
            date=date.astimezone(datetime.UTC).date(),
            description=description,
            amount=amount,
        )
        for date, description, amount in rows
    ]


@translate_repository_errors
def get_daily_expenses(
    session: Session, filters: TransactionFilters
) -> list[DailyTotal]:
    """What was spent in each UTC day of the period, oldest day first.

    Days without spending are in the list with 0, so the list always has every day of the period.
    The filters need both `date_from` and `date_to` (`date_to` is exclusive). Automatically excludes credit card payments.
    """
    if filters.date_from is None or filters.date_to is None:
        raise ValueError("date_from and date_to are required")
    rows = transactions_repository.sum_transactions_by_day(
        session,
        dataclasses.replace(filters, type="DEBIT"),
    )
    totals = dict(rows)
    start, end = filters.date_from.date(), filters.date_to.date()
    return [
        DailyTotal(
            day=start + datetime.timedelta(days=offset),
            total=totals.get(
                start + datetime.timedelta(days=offset), decimal.Decimal("0.00")
            ),
        )
        for offset in range((end - start).days)
    ]


def get_average_daily_expenses(
    session: Session, filters: TransactionFilters
) -> decimal.Decimal:
    """Total spent divided by the number of days of the period (days without spending count)."""
    daily = get_daily_expenses(session, filters)
    if not daily:
        return decimal.Decimal("0.00")
    total = sum((d.total for d in daily), decimal.Decimal(0))
    return round_to_cents(total / len(daily))


@translate_repository_errors
def summarize_transactions_by(
    session: Session,
    filters: TransactionFilters,
    by_owner: bool,
    by_category: bool,
) -> list[TransactionGroupTotal]:
    """Debit and credit totals per owner and/or category, biggest debit total first."""
    groups: dict[tuple, TransactionGroupTotal] = {}
    for (
        user_id,
        category,
        type_,
        total,
        count,
    ) in transactions_repository.summarize_transactions_by(
        session, filters, by_owner, by_category
    ):
        group = groups.setdefault(
            (user_id, category),
            TransactionGroupTotal(user_id=user_id, category=category),
        )
        if type_ == "DEBIT":
            group.debit_total, group.debit_count = total, count
        elif type_ == "CREDIT":
            group.credit_total, group.credit_count = total, count
    return sorted(
        groups.values(), key=lambda g: (g.debit_total, g.credit_total), reverse=True
    )
