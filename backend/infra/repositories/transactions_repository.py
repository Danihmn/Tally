import datetime
import decimal
import uuid
from typing import Any

from sqlalchemy import (
    Date,
    Text,
    Uuid,
    cast,
    func,
    literal,
    literal_column,
    select,
    update,
)
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from domain.read_models import TransactionFilters
from infra.database.models import BankAccounts, PluggyItems, Transactions
from infra.repositories.common.exceptions import (
    translate_db_errors,
)
from infra.repositories.common.transaction_filters import apply_filters, join_owner

# Columns never overwritten when the transaction already exists.
_KEEP_ON_CONFLICT = {"id", "created_at", "pluggy_transaction_id", "bank_account_id"}

# Rows per INSERT statement: keeps well under Postgres' 65535 bind parameters limit.
_UPSERT_CHUNK_SIZE = 500


@translate_db_errors("transactions")
def list_transactions_since(
    session: Session,
    bank_account_id: uuid.UUID,
    date_from: datetime.datetime,
    include_deleted: bool = False,
) -> list[Transactions]:
    """Every transaction of the account with date >= date_from (no pagination).

    The sync passes include_deleted=True: it needs the deleted rows to bring back the ones that reappear.
    """
    stmt = (
        select(Transactions)
        .where(Transactions.bank_account_id == bank_account_id)
        .where(Transactions.date >= date_from)
        .order_by(Transactions.date, Transactions.id)
    )
    if not include_deleted:
        stmt = stmt.where(Transactions.deleted_at.is_(None))
    return list(session.scalars(stmt).all())


@translate_db_errors("transactions")
def upsert_transactions(
    session: Session, values_list: list[dict[str, Any]]
) -> list[Transactions]:
    """Insert or update by pluggy_transaction_id. Each dict uses Transactions column names.

    Sent in chunks of _UPSERT_CHUNK_SIZE rows. All dicts must have the same keys.
    """
    saved: list[Transactions] = []
    for start in range(0, len(values_list), _UPSERT_CHUNK_SIZE):
        chunk = values_list[start : start + _UPSERT_CHUNK_SIZE]
        stmt = insert(Transactions).values(chunk)
        update_values = {
            key: stmt.excluded[key] for key in chunk[0] if key not in _KEEP_ON_CONFLICT
        }
        update_values["updated_at"] = func.now()  # type: ignore
        stmt = stmt.on_conflict_do_update(
            index_elements=["pluggy_transaction_id"], set_=update_values
        ).returning(Transactions)
        saved.extend(
            session.scalars(stmt, execution_options={"populate_existing": True}).all()
        )
    return saved


@translate_db_errors("transactions")
def update_transactions(session: Session, values_list: list[dict[str, Any]]) -> None:
    """Bulk UPDATE by primary key. Each dict must have the row's `id`.

    Used when pluggy_transaction_id itself changes, which the upsert cannot do.
    """
    if not values_list:
        return
    now = datetime.datetime.now(datetime.UTC)
    session.execute(
        update(Transactions),
        [{**values, "updated_at": now} for values in values_list],
    )


@translate_db_errors("transactions")
def soft_delete_transactions(session: Session, ids: list[uuid.UUID]) -> None:
    """Marks the transactions as deleted (they can come back: Pluggy may return them again)."""
    now = datetime.datetime.now(datetime.UTC)
    for start in range(0, len(ids), _UPSERT_CHUNK_SIZE):
        chunk = ids[start : start + _UPSERT_CHUNK_SIZE]
        session.execute(
            update(Transactions)
            .where(Transactions.id.in_(chunk))
            .values(deleted_at=now, updated_at=now)
        )


@translate_db_errors("transactions")
def list_unclassified_posted_by_accounts(
    session: Session, account_ids: list[uuid.UUID]
) -> list[Transactions]:
    """POSTED transactions of the accounts that were not classified as internal transfer yet."""
    stmt = (
        select(Transactions)
        .where(Transactions.bank_account_id.in_(account_ids))
        .where(Transactions.status == "POSTED")
        .where(Transactions.deleted_at.is_(None))
        .where(Transactions.internal_transfer.is_(None))
        .order_by(Transactions.date, Transactions.id)
    )
    return list(session.scalars(stmt).all())


@translate_db_errors("transactions")
def set_internal_transfer(
    session: Session, ids: list[uuid.UUID], value: str, source: str
) -> int:
    """Classifies the transactions. Only the ones still unclassified: a decision already
    taken (by hand or by an earlier run) is never overwritten. Returns how many changed."""
    now = datetime.datetime.now(datetime.UTC)
    changed = 0
    for start in range(0, len(ids), _UPSERT_CHUNK_SIZE):
        chunk = ids[start : start + _UPSERT_CHUNK_SIZE]
        result = session.execute(
            update(Transactions)
            .where(Transactions.id.in_(chunk))
            .where(Transactions.internal_transfer.is_(None))
            .where(Transactions.deleted_at.is_(None))
            .values(
                internal_transfer=value,
                internal_transfer_classification_source=source,
                updated_at=now,
            )
        )
        changed += result.rowcount  # type: ignore[attr-defined]
    return changed


@translate_db_errors("transactions")
def clear_auto_internal_transfers(session: Session, household_id: uuid.UUID) -> int:
    """Undoes the AUTO classification of the household's transactions, so the next run
    classifies them again. MANUAL ones are someone's choice and stay. Returns how many."""
    result = session.execute(
        update(Transactions)
        .where(Transactions.household_id == household_id)
        .where(Transactions.internal_transfer_classification_source == "AUTO")
        .values(
            internal_transfer=None,
            internal_transfer_classification_source=None,
            updated_at=datetime.datetime.now(datetime.UTC),
        )
    )
    return result.rowcount  # type: ignore[attr-defined]


@translate_db_errors("transactions")
def search_transactions(
    session: Session,
    filters: TransactionFilters,
    limit: int = 50,
    offset: int = 0,
) -> list[tuple[Transactions, uuid.UUID]]:
    """Filtered page of transactions (newest first), each with the owner's user id."""
    stmt = apply_filters(join_owner(select(Transactions, PluggyItems.user_id)), filters)
    stmt = (
        stmt
        .order_by(Transactions.date.desc(), Transactions.id)
        .limit(limit)
        .offset(offset)
    )
    return [(transaction, user_id) for transaction, user_id in session.execute(stmt)]


@translate_db_errors("transactions")
def count_transactions(session: Session, filters: TransactionFilters) -> int:
    stmt = apply_filters(join_owner(select(func.count(Transactions.id))), filters)
    return session.scalar(stmt) or 0


@translate_db_errors("transactions")
def summarize_transactions(
    session: Session, filters: TransactionFilters
) -> list[tuple[str, decimal.Decimal, int]]:
    """(type, sum of abs(amount), count) per transaction type, over everything the filters match."""
    stmt = apply_filters(
        join_owner(
            select(
                Transactions.type,
                func.coalesce(func.sum(func.abs(Transactions.amount)), 0),
                func.count(Transactions.id),
            )
        ),
        filters,
    ).group_by(Transactions.type)
    return [(type_, total, count) for type_, total, count in session.execute(stmt)]


@translate_db_errors("transactions")
def sum_transactions_amount(
    session: Session, filters: TransactionFilters
) -> decimal.Decimal:
    """Sum of abs(amount) of everything the filters match (0 when nothing matches, no credit card payments)."""
    stmt = apply_filters(
        join_owner(
            select(func.coalesce(func.sum(func.abs(Transactions.amount)), 0)).where(
                BankAccounts.subtype != "CREDIT_CARD"
            )
        ),
        filters,
    )
    return session.scalar(stmt) or decimal.Decimal("0.00")


@translate_db_errors("transactions")
def list_top_transactions(
    session: Session, filters: TransactionFilters, limit: int
) -> list[tuple[datetime.datetime, str | None, decimal.Decimal]]:
    """(date, description, abs(amount)) of the `limit` biggest transactions the filters match (no credit card payments)."""
    amount = func.abs(Transactions.amount)
    stmt = (
        apply_filters(
            join_owner(
                select(Transactions.date, Transactions.description, amount).where(
                    BankAccounts.subtype != "CREDIT_CARD"
                )
            ),
            filters,
        )
        .order_by(amount.desc(), Transactions.date.desc(), Transactions.id)
        .limit(limit)
    )
    return [
        (date, description, value) for date, description, value in session.execute(stmt)
    ]


@translate_db_errors("transactions")
def sum_transactions_by_day(
    session: Session, filters: TransactionFilters
) -> list[tuple[datetime.date, decimal.Decimal]]:
    """(UTC day, sum of abs(amount)) per day that has transactions, oldest day first.

    The day is cut in UTC on purpose: it does not depend on the time zone of the connection.
    'UTC' is written in the SQL (not a bind parameter), so GROUP BY matches the selected column.
    """
    day = cast(func.timezone(literal_column("'UTC'"), Transactions.date), Date).label(
        "day"
    )
    stmt = (
        apply_filters(
            join_owner(select(day, func.sum(func.abs(Transactions.amount)))), filters
        )
        .group_by(day)
        .order_by(day)
    )
    return [(day_, total) for day_, total in session.execute(stmt)]


@translate_db_errors("transactions")
def summarize_transactions_by(
    session: Session,
    filters: TransactionFilters,
    by_owner: bool,
    by_category: bool,
) -> list[tuple[uuid.UUID | None, str | None, str, decimal.Decimal, int]]:
    """(owner user id, category, type, sum of abs(amount), count) per group and type.

    A column that is not grouped comes back as None.
    """
    owner = PluggyItems.user_id if by_owner else literal(None, type_=Uuid)
    category = Transactions.category if by_category else literal(None, type_=Text)
    stmt = apply_filters(
        join_owner(
            select(
                owner,
                category,
                Transactions.type,
                func.coalesce(func.sum(func.abs(Transactions.amount)), 0),
                func.count(Transactions.id),
            )
        ),
        filters,
    )
    groups = [Transactions.type]
    if by_owner:
        groups.append(PluggyItems.user_id)  # type: ignore
    if by_category:
        groups.append(Transactions.category)  # type: ignore
    stmt = stmt.group_by(*groups)
    return [
        (user_id, category_, type_, total, count)
        for user_id, category_, type_, total, count in session.execute(stmt)
    ]
