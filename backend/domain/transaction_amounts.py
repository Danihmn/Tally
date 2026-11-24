"""The value of a transaction in the currency of its account (the one the totals use).

A card purchase in another currency (USD, for example) comes from Pluggy with `amount` and
`currencyCode` in that currency, and `amountInAccountCurrency` with the value already converted
by the bank (what is in the bill). Pluggy only sends it when the currencies differ.
Adding `amount` of a USD purchase as if it were BRL gives a wrong total (US$ 20 is not R$ 20).
"""

from decimal import Decimal

from domain.entities import Transaction


def amount_in_currency(transaction: Transaction, currency: str) -> Decimal | None:
    """Absolute value of the transaction in `currency` (the currency of the account).

    None when the transaction is in another currency and Pluggy did not send the converted
    value: it cannot be added to anything, so the caller leaves it out and warns."""
    if transaction.currency_code == currency:
        return abs(transaction.amount)
    if transaction.amount_in_account_currency is not None:
        return abs(transaction.amount_in_account_currency)
    return None


def is_unconverted(transaction: Transaction, currency: str) -> bool:
    """True when the transaction is in another currency and has no converted value."""
    return amount_in_currency(transaction, currency) is None
