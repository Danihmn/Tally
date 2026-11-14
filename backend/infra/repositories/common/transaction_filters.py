from sqlalchemy import Select, exists, func, or_, select

from domain.read_models import TransactionFilters
from infra.database.models import (
    BankAccounts,
    PluggyItems,
    Reconciliations,
    Transactions,
)
from infra.repositories.common.like import ilike_contains

SAME_PERSON = "SAME_PERSON"
SAME_HOUSEHOLD = "SAME_HOUSEHOLD"
UNCLASSIFIED = "UNCLASSIFIED"  # filter value for internal_transfer IS NULL


def join_owner(stmt: Select) -> Select:
    """transactions -> bank_accounts -> pluggy_items (the owner is pluggy_items.user_id)."""
    return stmt.join(
        BankAccounts, Transactions.bank_account_id == BankAccounts.id
    ).join(PluggyItems, BankAccounts.pluggy_item_id == PluggyItems.id)


def apply_filters(stmt: Select, filters: TransactionFilters) -> Select:
    """Adds the WHERE clauses. The statement must already be joined with join_owner()."""
    stmt = stmt.where(Transactions.deleted_at.is_(None))
    if filters.household_id is not None:
        stmt = stmt.where(Transactions.household_id == filters.household_id)
    if filters.user_id is not None:
        stmt = stmt.where(PluggyItems.user_id == filters.user_id)
    if filters.bank_account_id is not None:
        stmt = stmt.where(Transactions.bank_account_id == filters.bank_account_id)
    if filters.date_from is not None:
        stmt = stmt.where(Transactions.date >= filters.date_from)
    if filters.date_to is not None:
        stmt = stmt.where(Transactions.date < filters.date_to)
    if filters.type is not None:
        stmt = stmt.where(Transactions.type == filters.type)
    if filters.status is not None:
        stmt = stmt.where(Transactions.status == filters.status)
    if filters.category is not None:
        stmt = stmt.where(Transactions.category == filters.category)
    if filters.search:
        stmt = stmt.where(ilike_contains(Transactions.description, filters.search))
    if filters.min_amount is not None:
        stmt = stmt.where(func.abs(Transactions.amount) >= filters.min_amount)
    if filters.max_amount is not None:
        stmt = stmt.where(func.abs(Transactions.amount) <= filters.max_amount)
    if filters.internal_transfer == UNCLASSIFIED:
        stmt = stmt.where(Transactions.internal_transfer.is_(None))
    elif filters.internal_transfer is not None:
        stmt = stmt.where(Transactions.internal_transfer == filters.internal_transfer)
    if filters.exclude_internal_transfers:
        # In the person view, only the transfers between their own accounts leave the totals.
        # In the household view, the transfers between people of the household leave too.
        # NULL (not classified yet) must stay in, so it needs an explicit IS NULL.
        excluded = (
            [SAME_PERSON]
            if filters.user_id is not None
            else [SAME_PERSON, SAME_HOUSEHOLD]
        )
        stmt = stmt.where(
            or_(
                Transactions.internal_transfer.is_(None),
                Transactions.internal_transfer.not_in(excluded),
            )
        )
    if filters.financial_entry_id is not None:
        stmt = stmt.where(
            exists(
                select(Reconciliations.id).where(
                    Reconciliations.transaction_id == Transactions.id,
                    Reconciliations.financial_entry_id == filters.financial_entry_id,
                    Reconciliations.deleted_at.is_(None),
                )
            )
        )
    return stmt
