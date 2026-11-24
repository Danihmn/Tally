"""Which credit card bill (fatura) a transaction belongs to, and the total of a bill.

A bill is named by its due month (the month the user pays it), as day 1 of that month.

Pluggy does not return open bills (`GET /bills` only has closed ones), so the bill of a
transaction comes from `creditCardMetadata.billForecastDate` ("YYYY-MM") when Pluggy sends it.
It only comes on connections created after July/2026. Without it, the bill is estimated with
the closing day of the card: a purchase on the closing day or after it goes to the next bill.

Each installment of a purchase is its own transaction, so a bill only adds the installment of
that month (R$300 in 10x = R$30 per bill), never the whole purchase.
"""

import datetime
import re
from collections.abc import Iterable
from decimal import Decimal

from domain.entities import Transaction
from domain.transaction_amounts import amount_in_currency, is_unconverted
from utils.dates import clamp_day_to_month, next_month_start

BILL_PAYMENT_OPERATION = "PAGAMENTO_FATURA"
_FORECAST_PATTERN = re.compile(r"^(\d{4})-(\d{2})$")


def _metadata(transaction: Transaction) -> dict:
    metadata = transaction.credit_card_metadata
    return metadata if isinstance(metadata, dict) else {}


def forecast_month(transaction: Transaction) -> datetime.date | None:
    """Day 1 of the `billForecastDate` month, or None when Pluggy did not send a valid one."""
    value = _metadata(transaction).get("billForecastDate")
    if not isinstance(value, str):
        return None
    match = _FORECAST_PATTERN.match(value.strip())
    if match is None:
        return None
    year, month = int(match.group(1)), int(match.group(2))
    if not 1 <= month <= 12:
        return None
    return datetime.date(year, month, 1)


def installment_of(transaction: Transaction) -> tuple[int | None, int | None]:
    """(installment number, total installments), each None when Pluggy did not send it."""
    metadata = _metadata(transaction)

    def _int(key: str) -> int | None:
        value = metadata.get(key)
        if isinstance(value, bool) or not isinstance(value, int | float):
            return None
        return int(value)

    return _int("installmentNumber"), _int("totalInstallments")


def bill_month_of(
    transaction: Transaction, close_day: int | None, due_day: int | None
) -> tuple[datetime.date, bool]:
    """Due month (day 1) of the bill of the transaction, and whether it is an estimate.

    The Pluggy dates are days at UTC midnight, so the UTC day is used (not the local one)."""
    forecast = forecast_month(transaction)
    if forecast is not None:
        return forecast, False

    day = transaction.date.astimezone(datetime.UTC).date()
    month_start = day.replace(day=1)
    if close_day is None or due_day is None:
        return month_start, True

    closing_month = month_start
    if day >= clamp_day_to_month(month_start, close_day):
        closing_month = next_month_start(month_start)
    # The due date is the first `due_day` after the closing date.
    due_month = (
        closing_month if due_day > close_day else next_month_start(closing_month)
    )
    return due_month, True


def is_bill_payment(transaction: Transaction) -> bool:
    """The payment of a previous bill: it is not part of the bill total."""
    return transaction.operation_type == BILL_PAYMENT_OPERATION


def bill_total(transactions: Iterable[Transaction], currency: str = "BRL") -> Decimal:
    """Purchases (DEBIT) add, refunds and credits (CREDIT) subtract. Bill payments are left out.

    Amounts are in `currency` (the card's): a purchase in another currency counts with the
    value converted by the bank. One without it is left out (see `unconverted_count`)."""
    total = Decimal("0.00")
    for transaction in transactions:
        if is_bill_payment(transaction):
            continue
        amount = amount_in_currency(transaction, currency)
        if amount is None:
            continue
        total += amount if transaction.type == "DEBIT" else -amount
    return total


def unconverted_count(transactions: Iterable[Transaction], currency: str = "BRL") -> int:
    """How many transactions `bill_total` leaves out for having no converted value."""
    return sum(
        1
        for transaction in transactions
        if not is_bill_payment(transaction) and is_unconverted(transaction, currency)
    )
