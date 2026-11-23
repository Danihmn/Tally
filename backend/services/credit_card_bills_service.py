import datetime
import uuid

from sqlalchemy.orm import Session

from domain.credit_card_bills import bill_month_of, bill_total
from domain.entities import BankAccount, CreditData, Transaction
from domain.read_models import CardBill
from infra.repositories import (
    bank_account_repository,
    credit_datas_repository,
    transactions_repository,
)
from services.common.exceptions import NotFoundError, translate_repository_errors
from services.common.mappers import to_entities, to_entity, to_entity_or_none
from utils.dates import next_month_start, start_of_day_utc

# Months before the due month whose transactions can still be in its bill: the purchases of
# the month before closing, plus a margin for cards that close one month and are due two later.
_MONTHS_BEFORE = 2


def _months_before(month: datetime.date, count: int) -> datetime.date:
    index = month.year * 12 + (month.month - 1) - count
    return datetime.date(index // 12, index % 12 + 1, 1)


def _day_of(moment: datetime.datetime | None) -> int | None:
    """Day of the month of a Pluggy date (a day at UTC midnight)."""
    if moment is None:
        return None
    return moment.astimezone(datetime.UTC).day


@translate_repository_errors
def get_card_bill(
    session: Session,
    household_id: uuid.UUID,
    account_id: uuid.UUID,
    month: datetime.date,
) -> CardBill:
    """The bill of a credit card of the household that is due in `month` (any day of it).

    Raises NotFoundError when the account is not in the household or is not a credit card."""
    month = month.replace(day=1)
    row = bank_account_repository.get_bank_account_with_owner(
        session, account_id, household_id
    )
    if row is None:
        raise NotFoundError("Credit card not found")
    account = to_entity(BankAccount, row[0])
    if account.subtype != "CREDIT_CARD":
        raise NotFoundError("Credit card not found")

    credit = to_entity_or_none(
        CreditData,
        credit_datas_repository.get_credit_data_by_bank_account_id(session, account_id),
    )
    close_day = _day_of(credit.balance_close_date) if credit else None
    due_day = _day_of(credit.balance_due_date) if credit else None

    candidates = to_entities(
        Transaction,
        transactions_repository.list_card_transactions_for_bill(
            session,
            household_id,
            account_id,
            start_of_day_utc(_months_before(month, _MONTHS_BEFORE)),
            start_of_day_utc(next_month_start(month)),
            month.strftime("%Y-%m"),
        ),
    )

    in_bill: list[Transaction] = []
    estimated = False
    for transaction in candidates:
        bill_month, is_estimate = bill_month_of(transaction, close_day, due_day)
        if bill_month != month:
            continue
        in_bill.append(transaction)
        estimated = estimated or is_estimate

    return CardBill(
        account=account,
        month=month,
        total=bill_total(in_bill),
        estimated=estimated,
        transactions=in_bill,
    )
