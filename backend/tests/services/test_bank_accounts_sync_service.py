import unittest
import uuid
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from services.bank_accounts_sync_service import (
    sync_bank_account,
    to_bank_account_entity,
)
from tests.factories import HOUSEHOLD_ID

MODULE = "services.bank_accounts_sync_service"


def make_account_schema(**overrides):
    values = {
        "id": str(uuid.uuid4()),
        "type": "BANK",
        "subtype": "CHECKING_ACCOUNT",
        "name": "Checking",
        "number": "123",
        "currency_code": "BRL",
        "marketing_name": None,
        "tax_number": None,
        "owner": None,
        "balance": Decimal("10.00"),
        "bank_data": None,
        "credit_data": None,
    }
    values.update(overrides)
    return SimpleNamespace(**values)


class ToBankAccountEntityTests(unittest.TestCase):
    def test_the_entity_belongs_to_the_given_household(self):
        item_id = uuid.uuid4()

        entity = to_bank_account_entity(make_account_schema(), item_id, HOUSEHOLD_ID)

        self.assertEqual(entity.household_id, HOUSEHOLD_ID)
        self.assertEqual(entity.pluggy_item_id, item_id)


class SyncBankAccountTests(unittest.TestCase):
    def test_a_new_account_is_stored_in_the_household_of_its_owner(self):
        schema = make_account_schema()

        with (
            patch(f"{MODULE}.get_bank_account_by_pluggy_account_id", return_value=None),
            patch(f"{MODULE}.upsert_bank_account") as upsert,
        ):
            upsert.return_value = SimpleNamespace(id=uuid.uuid4())
            sync_bank_account(MagicMock(), uuid.uuid4(), schema, HOUSEHOLD_ID)

        self.assertEqual(upsert.call_args.args[1].household_id, HOUSEHOLD_ID)
