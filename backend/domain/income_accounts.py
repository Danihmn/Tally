"""Pure rule for the accounts whose outgoing transfers are income (no database access).

Some banks (a salary account, for example) report neither the money that comes in nor the
TED that sends it on to the person's other account. The only trace of that income is the TED
CREDIT in the other bank. Its documents say it came from the person themself (SAME_PERSON),
so it would leave the totals as an internal transfer.

The received TED does not carry the branch or account number of the payer, only its bank
(`payer.routingNumber`, the COMPE code). So the account is recognized by the bank code the
person stored on it (`bank_accounts.bank_code`), and only TEDs count: a Pix from the same bank
may come from another account of the person there.
"""

import re
from collections.abc import Collection
from typing import Any

from domain.entities import Transaction

INCOME_PAYMENT_METHOD = "TED"
_BANK_CODE_DIGITS = 3
# "001/0514/00050338-0": bank code / branch / account. The Pluggy docs only promise
# "branch / account", so a value with two parts (no bank code) gives nothing.
_TRANSFER_NUMBER = re.compile(r"^\s*(\d{1,3})\s*/[^/]+/[^/]+$")


def normalize_bank_code(value: Any) -> str | None:
    """The 3 digits of a COMPE bank code ("1" and "001" are the same bank), or None."""
    if not isinstance(value, str):
        return None
    digits = re.sub(r"\D", "", value)
    if not digits or len(digits) > _BANK_CODE_DIGITS:
        return None
    return digits.zfill(_BANK_CODE_DIGITS)


def bank_code_from_transfer_number(transfer_number: Any) -> str | None:
    """The bank code at the start of `bankData.transferNumber`, or None when it has none."""
    if not isinstance(transfer_number, str):
        return None
    match = _TRANSFER_NUMBER.match(transfer_number)
    return normalize_bank_code(match.group(1)) if match else None


def payer_bank_code(payment_data: Any) -> str | None:
    """The COMPE code of the payer's bank. None when anything on the way is missing."""
    if not isinstance(payment_data, dict):
        return None
    payer = payment_data.get("payer")
    if not isinstance(payer, dict):
        return None
    return normalize_bank_code(payer.get("routingNumber"))


def is_income_transfer(
    transaction: Transaction, income_bank_codes: Collection[str]
) -> bool:
    """True for a TED CREDIT whose payer is in one of the banks of `income_bank_codes`.

    It only looks at the bank: the caller checks that the payer is the same person (the
    document verdict SAME_PERSON) and that the codes are of that person's accounts."""
    if transaction.type != "CREDIT" or not income_bank_codes:
        return False
    payment_data = transaction.payment_data
    if not isinstance(payment_data, dict):
        return False
    if payment_data.get("paymentMethod") != INCOME_PAYMENT_METHOD:
        return False
    code = payer_bank_code(payment_data)
    return code is not None and code in income_bank_codes
