import logging
import uuid

from sqlalchemy.orm import Session

from domain.income_accounts import is_income_transfer, normalize_bank_code
from domain.internal_transfers import find_internal_pairs
from domain.transfer_documents import (
    SAME_HOUSEHOLD,
    SAME_PERSON,
    classify_by_documents,
    normalize_cpf,
)
from infra.database.session import get_session
from services.bank_accounts_service import list_bank_accounts_by_user
from services.common.exceptions import ServiceError
from services.transactions_service import (
    clear_auto_internal_transfers,
    list_unclassified_transactions,
    mark_internal_transfer,
)
from services.users_service import list_users_by_household
from utils.ids import require_id

logger = logging.getLogger(__name__)

AUTO = "AUTO"
NOT_INTERNAL_TRANSFER = "NOT_INTERNAL_TRANSFER"


def classificate_internal_transfers(session: Session, household_id: uuid.UUID) -> int:
    """Classifies the internal transfers of the household. Does not commit: the caller does.

    Two signals, both about the unclassified transactions of the BANK accounts:
    1. the documents in `payment_data` (who is the other party), which settle a transaction
       on their own, even when its other leg is in a bank that did not sync yet;
    2. the pairing by amount, date and accounts, for what the documents did not settle.
    A transaction that nothing settles stays unclassified (it counts as any other one).

    A TED the person sent themself from an account marked `outgoing_transfers_are_income`
    (a salary account that does not report the salary) is income, not a transfer: it is
    marked NOT_INTERNAL_TRANSFER (see domain/income_accounts.py).

    Returns how many transactions were marked."""
    owner_by_account: dict[uuid.UUID, uuid.UUID] = {}
    cpf_by_account: dict[uuid.UUID, str] = {}
    household_cpfs: set[str] = set()
    all_cpfs_known = True
    # Bank codes of the accounts whose outgoing TEDs are income, per owner
    income_codes_by_owner: dict[uuid.UUID, set[str]] = {}
    income_accounts: set[uuid.UUID] = set()

    for person in list_users_by_household(session, household_id):
        person_id = require_id(person, "User")
        person_cpfs: set[str] = set()
        for account in list_bank_accounts_by_user(session, person_id):
            account_id = require_id(account, "Bank account")
            owner_by_account[account_id] = person_id
            if account.outgoing_transfers_are_income:
                income_accounts.add(account_id)
                code = normalize_bank_code(account.bank_code)
                if code is not None:
                    income_codes_by_owner.setdefault(person_id, set()).add(code)
            cpf = normalize_cpf(account.tax_number)
            if cpf is not None:
                cpf_by_account[account_id] = cpf
                person_cpfs.add(cpf)
        household_cpfs |= person_cpfs
        if not person_cpfs:
            # A CPF outside the set cannot be called "a stranger" if someone's CPF is missing
            all_cpfs_known = False

    transactions = list_unclassified_transactions(session, list(owner_by_account))

    verdicts = {
        require_id(transaction, "Transaction"): classify_by_documents(
            transaction,
            cpf_by_account.get(transaction.bank_account_id),
            household_cpfs,
            all_cpfs_known,
        )
        for transaction in transactions
    }

    # Income from the person's own salary account: it is not paired either, because a
    # verdict other than SAME_PERSON / SAME_HOUSEHOLD keeps it out of the pairing
    for transaction in transactions:
        transaction_id = require_id(transaction, "Transaction")
        if verdicts[transaction_id] != SAME_PERSON:
            continue
        if transaction.bank_account_id in income_accounts:
            continue
        owner = owner_by_account.get(transaction.bank_account_id)
        if is_income_transfer(transaction, income_codes_by_owner.get(owner, ())):  # type: ignore[arg-type]
            verdicts[transaction_id] = NOT_INTERNAL_TRANSFER

    # dict (not set) to keep the order and not repeat a transaction
    to_mark: dict[str, dict[uuid.UUID, None]] = {
        SAME_PERSON: {},
        SAME_HOUSEHOLD: {},
        NOT_INTERNAL_TRANSFER: {},
    }
    for transaction_id, verdict in verdicts.items():
        if verdict in to_mark:
            to_mark[verdict][transaction_id] = None
    from_documents = sum(len(ids) for ids in to_mark.values())
    as_income = len(to_mark[NOT_INTERNAL_TRANSFER])

    for debit, credit, kind in find_internal_pairs(
        transactions, owner_by_account, verdicts
    ):
        to_mark[kind][require_id(debit, "Transaction")] = None
        to_mark[kind][require_id(credit, "Transaction")] = None

    marked = 0
    for kind, ids in to_mark.items():
        if ids:
            marked += mark_internal_transfer(session, list(ids), kind, AUTO)

    # Only counts: the documents are personal data and never go to the log
    logger.info(
        "Household %s: %s unclassified, %s settled by documents (%s of them as income), "
        "%s by pairing",
        household_id,
        len(transactions),
        from_documents,
        as_income,
        sum(len(ids) for ids in to_mark.values()) - from_documents,
    )
    return marked


def reclassify_internal_transfers(session: Session, household_id: uuid.UUID) -> int:
    """Undoes the AUTO classification of the household and classifies again, with the
    accounts as they are now (MANUAL ones stay). Does not commit: the caller does.

    The whole household, not one account: both legs of a pair must be unclassified to pair."""
    clear_auto_internal_transfers(session, household_id)
    return classificate_internal_transfers(session, household_id)


def launch_internal_transfers_classification(household_id: uuid.UUID) -> None:
    """Runs the classification in its own session, after the sync was committed.

    It never raises: a failure here must not break the sync that called it."""
    with get_session() as session:
        try:
            marked = classificate_internal_transfers(session, household_id)
            session.commit()
        except ServiceError, ValueError:
            session.rollback()
            logger.exception(
                "Internal transfers classification failed for household %s",
                household_id,
            )
            return

    logger.info(
        "Internal transfers of household %s: %s transactions marked",
        household_id,
        marked,
    )
