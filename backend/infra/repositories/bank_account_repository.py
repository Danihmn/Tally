import decimal
import uuid
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from infra.database.models import BankAccounts, CreditDatas, PluggyItems
from infra.repositories.common.exceptions import (
    translate_db_errors,
)
from infra.repositories.common.upsert import upsert_one


@translate_db_errors("bank_accounts")
def get_bank_account_by_pluggy_account_id(
    session: Session, pluggy_account_id: uuid.UUID
) -> BankAccounts | None:
    stmt = select(BankAccounts).where(
        BankAccounts.pluggy_account_id == pluggy_account_id
    )
    return session.scalars(stmt).one_or_none()


@translate_db_errors("bank_accounts")
def list_bank_accounts_by_user(
    session: Session, user_id: uuid.UUID
) -> list[BankAccounts]:
    """The user's bank accounts (type BANK: checking and savings), with no pagination.

    Credit cards (type CREDIT) and the accounts of removed items are left out."""
    stmt = (
        _with_owner(select(BankAccounts))
        .where(PluggyItems.user_id == user_id)
        .where(PluggyItems.deleted_at.is_(None))
        .where(BankAccounts.type == "BANK")
        .order_by(BankAccounts.created_at, BankAccounts.id)
    )
    return list(session.scalars(stmt).all())


@translate_db_errors("bank_accounts")
def upsert_bank_account(session: Session, values: dict[str, Any]) -> BankAccounts:
    """Insert or update by pluggy_account_id. `values` uses BankAccounts column names."""
    return upsert_one(
        session, BankAccounts, values, "pluggy_account_id", set_updated_at=True
    )


def _with_owner(stmt):
    return stmt.join(PluggyItems, BankAccounts.pluggy_item_id == PluggyItems.id)


@translate_db_errors("bank_accounts")
def search_bank_accounts(
    session: Session,
    user_id: uuid.UUID | None = None,
    account_type: str | None = None,
    limit: int = 50,
    offset: int = 0,
    household_id: uuid.UUID | None = None,
    only_active: bool = False,
) -> list[tuple[BankAccounts, uuid.UUID]]:
    """Accounts with the owner's user id. Accounts of deleted items stay (their history is
    kept), unless `only_active` is True: then only accounts of connected items come back."""
    stmt = _with_owner(select(BankAccounts, PluggyItems.user_id))
    if only_active:
        stmt = stmt.where(PluggyItems.deleted_at.is_(None))
    if household_id is not None:
        stmt = stmt.where(BankAccounts.household_id == household_id)
    if user_id is not None:
        stmt = stmt.where(PluggyItems.user_id == user_id)
    if account_type is not None:
        stmt = stmt.where(BankAccounts.type == account_type)
    stmt = (
        stmt
        .order_by(BankAccounts.created_at, BankAccounts.id)
        .limit(limit)
        .offset(offset)
    )
    return [(account, owner_id) for account, owner_id in session.execute(stmt)]


@translate_db_errors("bank_accounts")
def sum_bank_accounts_balance(
    session: Session,
    household_id: uuid.UUID,
    account_type: str,
    user_id: uuid.UUID | None = None,
) -> decimal.Decimal:
    """Sum of the balance of the accounts of one type (BANK or CREDIT) of connected items.

    Accounts of removed items are left out: their balance is old. Accounts with no balance count
    as zero. Zero when nothing matches."""
    stmt = _with_owner(select(func.coalesce(func.sum(BankAccounts.balance), 0)))
    stmt = stmt.where(
        BankAccounts.household_id == household_id,
        BankAccounts.type == account_type,
        PluggyItems.deleted_at.is_(None),
    )
    if user_id is not None:
        stmt = stmt.where(PluggyItems.user_id == user_id)
    return session.scalar(stmt) or decimal.Decimal("0.00")


@translate_db_errors("bank_accounts")
def list_account_balances(
    session: Session,
    household_id: uuid.UUID,
    account_type: str | None = None,
    user_id: uuid.UUID | None = None,
) -> list[tuple[BankAccounts, uuid.UUID, CreditDatas | None]]:
    """Accounts of connected items with the owner's user id and, for cards, the credit data.

    No pagination: a household has few accounts."""
    stmt = _with_owner(
        select(BankAccounts, PluggyItems.user_id, CreditDatas).outerjoin(
            CreditDatas, CreditDatas.bank_account_id == BankAccounts.id
        )
    ).where(
        BankAccounts.household_id == household_id,
        PluggyItems.deleted_at.is_(None),
    )
    if account_type is not None:
        stmt = stmt.where(BankAccounts.type == account_type)
    if user_id is not None:
        stmt = stmt.where(PluggyItems.user_id == user_id)
    stmt = stmt.order_by(BankAccounts.created_at, BankAccounts.id)
    return [
        (account, owner_id, credit_data)
        for account, owner_id, credit_data in session.execute(stmt)
    ]
