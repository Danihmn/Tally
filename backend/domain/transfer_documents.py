"""Pure rules to read who is on the other side of a transaction from its `payment_data`.

Pluggy fills `payment_data` as it can: the whole object, a party or its document may be
missing or null. Anything that is not a clean, complete document is "unknown", never a guess.
"""

import re
from collections.abc import Collection
from typing import Any

from domain.entities import Transaction

SAME_PERSON = "SAME_PERSON"
SAME_HOUSEHOLD = "SAME_HOUSEHOLD"
# Not an internal transfer for sure (a company, or a person outside the household).
# It is only used to leave the transaction out of the pairing: it is never stored.
EXTERNAL = "EXTERNAL"

_CPF_DIGITS = 11
_CNPJ_DIGITS = 14

# (type, digits): ("CPF", "43455082823")
Document = tuple[str, str]


def normalize_cpf(value: Any) -> str | None:
    """The 11 digits of a CPF, or None when it is not a complete CPF (empty, masked, short)."""
    if not isinstance(value, str):
        return None
    digits = re.sub(r"\D", "", value)
    if len(digits) != _CPF_DIGITS or len(set(digits)) == 1:
        return None
    return digits


def _normalize_cnpj(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    digits = re.sub(r"\D", "", value)
    return digits if len(digits) == _CNPJ_DIGITS else None


def _document(payment_data: Any, party: str) -> Document | None:
    """The document of the `payer` or of the `receiver`. None when anything on the way is missing."""
    if not isinstance(payment_data, dict):
        return None
    side = payment_data.get(party)
    if not isinstance(side, dict):
        return None
    document = side.get("documentNumber")
    if not isinstance(document, dict):
        return None

    kind = document.get("type")
    if kind == "CPF":
        number = normalize_cpf(document.get("value"))
    elif kind == "CNPJ":
        number = _normalize_cnpj(document.get("value"))
    else:
        return None
    return (kind, number) if number is not None else None


def classify_by_documents(
    transaction: Transaction,
    owner_cpf: str | None,
    household_cpfs: Collection[str],
    all_cpfs_known: bool,
) -> str | None:
    """SAME_PERSON, SAME_HOUSEHOLD, EXTERNAL, or None when the documents do not settle it.

    The account owner is the payer of a DEBIT and the receiver of a CREDIT, so the other
    party is the counterparty: one document is enough, the transaction does not need its pair.

    `owner_cpf` is the CPF of the account owner, `household_cpfs` the CPFs of everyone in the
    household. A CPF outside the household only means "third party" when `all_cpfs_known`
    (a partner without a known CPF would look like a stranger).
    """
    if owner_cpf is None:
        return None
    if transaction.type == "DEBIT":
        owner_party, other_party = "payer", "receiver"
    elif transaction.type == "CREDIT":
        owner_party, other_party = "receiver", "payer"
    else:
        return None

    # The owner's side, when it is there, must be the owner: otherwise the data is odd
    owner_side = _document(transaction.payment_data, owner_party)
    if owner_side is not None and owner_side != ("CPF", owner_cpf):
        return None

    counterparty = _document(transaction.payment_data, other_party)
    if counterparty is None:
        return None

    kind, number = counterparty
    if kind == "CNPJ":
        return EXTERNAL
    if number == owner_cpf:
        return SAME_PERSON
    if number in household_cpfs:
        return SAME_HOUSEHOLD
    return EXTERNAL if all_cpfs_known else None
