import decimal
import uuid

from sqlalchemy.orm import Session

from domain.entities import BankAccount, CreditData
from domain.read_models import AccountBalance, BankAccountWithOwner
from infra.repositories import bank_account_repository
from services.common.exceptions import translate_repository_errors
from services.common.mappers import to_entities, to_entity, to_entity_or_none, to_values


@translate_repository_errors
def get_bank_account_by_pluggy_account_id(
    session: Session, pluggy_account_id: uuid.UUID
) -> BankAccount | None:
    account = bank_account_repository.get_bank_account_by_pluggy_account_id(
        session, pluggy_account_id
    )
    return to_entity_or_none(BankAccount, account)


@translate_repository_errors
def list_bank_accounts_by_user(
    session: Session, user_id: uuid.UUID
) -> list[BankAccount]:
    """The user's bank accounts (checking and savings): no credit cards."""
    accounts = bank_account_repository.list_bank_accounts_by_user(session, user_id)
    return to_entities(BankAccount, accounts)


@translate_repository_errors
def upsert_bank_account(session: Session, account: BankAccount) -> BankAccount:
    saved = bank_account_repository.upsert_bank_account(session, to_values(account))
    return to_entity(BankAccount, saved)


@translate_repository_errors
def search_bank_accounts(
    session: Session,
    user_id: uuid.UUID | None = None,
    account_type: str | None = None,
    limit: int = 50,
    offset: int = 0,
    household_id: uuid.UUID | None = None,
    only_active: bool = False,
) -> list[BankAccountWithOwner]:
    rows = bank_account_repository.search_bank_accounts(
        session, user_id, account_type, limit, offset, household_id, only_active
    )
    return [
        BankAccountWithOwner(account=to_entity(BankAccount, a), user_id=owner_id)
        for a, owner_id in rows
    ]


@translate_repository_errors
def get_total_balance(
    session: Session,
    household_id: uuid.UUID,
    account_type: str,
    user_id: uuid.UUID | None = None,
) -> decimal.Decimal:
    """Sum of the balances Pluggy gave for the accounts of one type (BANK or CREDIT)."""
    return bank_account_repository.sum_bank_accounts_balance(
        session, household_id, account_type, user_id
    )


@translate_repository_errors
def list_account_balances(
    session: Session,
    household_id: uuid.UUID,
    account_type: str | None = None,
    user_id: uuid.UUID | None = None,
) -> list[AccountBalance]:
    rows = bank_account_repository.list_account_balances(
        session, household_id, account_type, user_id
    )
    return [
        AccountBalance(
            account=to_entity(BankAccount, account),
            user_id=owner_id,
            credit_data=to_entity_or_none(CreditData, credit_data),
        )
        for account, owner_id, credit_data in rows
    ]
