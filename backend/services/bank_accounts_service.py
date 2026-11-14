import decimal
import uuid
from typing import Any

from sqlalchemy.orm import Session

from domain.entities import BankAccount, CreditData
from domain.income_accounts import bank_code_from_transfer_number, normalize_bank_code
from domain.read_models import AccountBalance, BankAccountWithOwner
from infra.repositories import bank_account_repository, bank_datas_repository
from services.common.exceptions import (
    InvalidDataError,
    NotFoundError,
    translate_repository_errors,
)
from services.common.mappers import to_entities, to_entity, to_entity_or_none, to_values

# Set by the user (PATCH /bank-accounts/{id}), never by the Pluggy sync: sending them on a
# re-sync would reset them to their defaults.
USER_SETTINGS_FIELDS = (
    "outgoing_transfers_are_income",
    "bank_code",
)


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
    saved = bank_account_repository.upsert_bank_account(
        session, to_values(account, exclude=USER_SETTINGS_FIELDS)
    )
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


@translate_repository_errors
def update_bank_account_settings(
    session: Session,
    household_id: uuid.UUID,
    account_id: uuid.UUID,
    changes: dict[str, Any],
) -> tuple[BankAccountWithOwner, bool]:
    """Writes the user settings of a bank account (keys of USER_SETTINGS_FIELDS only).

    Turning the flag on with no bank code (neither sent nor stored) takes the code from the
    account's transfer number (`bank_datas.transfer_number`, "001/0514/..."). Sending
    `bank_code: None` explicitly does not.

    Returns the account as it is now and whether anything changed. Does not commit.
    Raises NotFoundError when the account is not in the household, and InvalidDataError for
    a credit card, a bad bank code, or the flag on without a bank code we can find."""
    unknown = set(changes) - set(USER_SETTINGS_FIELDS)
    if unknown:
        raise ValueError(f"Not a user setting: {sorted(unknown)}")

    row = bank_account_repository.get_bank_account_with_owner(
        session, account_id, household_id
    )
    if row is None:
        raise NotFoundError("Bank account not found")
    account, owner_id = to_entity(BankAccount, row[0]), row[1]
    if account.type != "BANK":
        raise InvalidDataError("Only bank accounts have these settings")

    values = dict(changes)
    if "bank_code" in values and values["bank_code"] is not None:
        code = normalize_bank_code(values["bank_code"])
        if code is None:
            raise InvalidDataError("bank_code must have up to 3 digits")
        values["bank_code"] = code

    flag = values.get(
        "outgoing_transfers_are_income", account.outgoing_transfers_are_income
    )
    code = values.get("bank_code", account.bank_code)
    if flag and code is None and "bank_code" not in values:
        code = _bank_code_of(session, account_id)
        if code is not None:
            values["bank_code"] = code
    if flag and code is None:
        raise InvalidDataError("A bank code is needed to count the outgoing TEDs")

    values = {k: v for k, v in values.items() if getattr(account, k) != v}
    if values:
        bank_account_repository.update_bank_account(session, account_id, values)
        for key, value in values.items():
            setattr(account, key, value)
    return BankAccountWithOwner(account=account, user_id=owner_id), bool(values)


def _bank_code_of(session: Session, account_id: uuid.UUID) -> str | None:
    """The bank code in the account's transfer number, when Pluggy sent one with it."""
    data = bank_datas_repository.get_bank_data_by_bank_account_id(session, account_id)
    return bank_code_from_transfer_number(data.transfer_number if data else None)
