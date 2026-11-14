import dataclasses
import unittest
import uuid
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from domain.entities import BankAccount
from services.bank_accounts_service import (
    list_bank_accounts_by_user,
    update_bank_account_settings,
    upsert_bank_account,
)
from services.common.exceptions import InvalidDataError, NotFoundError
from tests.factories import HOUSEHOLD_ID, make_bank_account

MODULE = "services.bank_accounts_service"
USER_ID = uuid.UUID("00000000-0000-0000-0000-00000000b001")


def _as_model(account: BankAccount) -> SimpleNamespace:
    """What the repository returns: an object with the same attributes as the entity."""
    return SimpleNamespace(
        **{f.name: getattr(account, f.name) for f in dataclasses.fields(account)}
    )


class ListBankAccountsByUserTests(unittest.TestCase):
    def _list(self, stored):
        session = MagicMock()
        with patch(f"{MODULE}.bank_account_repository") as repository:
            repository.list_bank_accounts_by_user.return_value = stored
            result = list_bank_accounts_by_user(session, USER_ID)
        return result, repository, session

    def test_asks_the_repository_for_the_accounts_of_that_user(self):
        _, repository, session = self._list([])

        repository.list_bank_accounts_by_user.assert_called_once_with(session, USER_ID)

    def test_the_accounts_come_back_as_entities_in_the_repository_order(self):
        first = make_bank_account(id=uuid.uuid4())
        second = make_bank_account(id=uuid.uuid4(), subtype="SAVINGS_ACCOUNT")

        result, _, _ = self._list([_as_model(first), _as_model(second)])

        self.assertEqual(result, [first, second])
        self.assertTrue(all(isinstance(a, BankAccount) for a in result))

    def test_a_user_without_bank_accounts_gets_an_empty_list(self):
        result, _, _ = self._list([])

        self.assertEqual(result, [])


class UpsertBankAccountTests(unittest.TestCase):
    def test_the_user_settings_are_never_sent_so_a_sync_does_not_reset_them(self):
        account = make_bank_account(outgoing_transfers_are_income=False, bank_code=None)
        with patch(f"{MODULE}.bank_account_repository") as repository:
            repository.upsert_bank_account.return_value = _as_model(account)
            upsert_bank_account(MagicMock(), account)

        values = repository.upsert_bank_account.call_args.args[1]
        self.assertNotIn("outgoing_transfers_are_income", values)
        self.assertNotIn("bank_code", values)
        self.assertEqual(values["number"], account.number)


class UpdateBankAccountSettingsTests(unittest.TestCase):
    def setUp(self):
        self.session = MagicMock()
        self.stored = make_bank_account(id=uuid.uuid4())
        patcher = patch(f"{MODULE}.bank_account_repository")
        self.repository = patcher.start()
        self.addCleanup(patcher.stop)
        self.repository.get_bank_account_with_owner.side_effect = lambda *args: (
            _as_model(self.stored),
            USER_ID,
        )
        datas_patcher = patch(f"{MODULE}.bank_datas_repository")
        self.bank_datas = datas_patcher.start()
        self.addCleanup(datas_patcher.stop)
        self.bank_datas.get_bank_data_by_bank_account_id.return_value = None

    def _with_transfer_number(self, transfer_number):
        self.bank_datas.get_bank_data_by_bank_account_id.return_value = SimpleNamespace(
            transfer_number=transfer_number
        )

    def _update(self, changes):
        return update_bank_account_settings(
            self.session, HOUSEHOLD_ID, self.stored.id, changes
        )

    def test_looks_for_the_account_inside_the_household(self):
        self._update({"bank_code": "001"})

        self.repository.get_bank_account_with_owner.assert_called_once_with(
            self.session, self.stored.id, HOUSEHOLD_ID
        )

    def test_turning_the_salary_account_on_writes_both_fields(self):
        item, changed = self._update(
            {"outgoing_transfers_are_income": True, "bank_code": "001"}
        )

        self.assertTrue(changed)
        self.repository.update_bank_account.assert_called_once_with(
            self.session,
            self.stored.id,
            {"outgoing_transfers_are_income": True, "bank_code": "001"},
        )
        self.assertTrue(item.account.outgoing_transfers_are_income)
        self.assertEqual(item.account.bank_code, "001")
        self.assertEqual(item.user_id, USER_ID)

    def test_the_flag_can_be_turned_on_with_the_code_already_stored(self):
        self.stored = make_bank_account(id=self.stored.id, bank_code="001")

        _, changed = self._update({"outgoing_transfers_are_income": True})

        self.assertTrue(changed)
        self.repository.update_bank_account.assert_called_once_with(
            self.session, self.stored.id, {"outgoing_transfers_are_income": True}
        )

    def test_the_flag_on_without_a_code_takes_it_from_the_transfer_number(self):
        self._with_transfer_number("001/0514/00050338-0")

        item, changed = self._update({"outgoing_transfers_are_income": True})

        self.assertTrue(changed)
        self.bank_datas.get_bank_data_by_bank_account_id.assert_called_once_with(
            self.session, self.stored.id
        )
        self.repository.update_bank_account.assert_called_once_with(
            self.session,
            self.stored.id,
            {"outgoing_transfers_are_income": True, "bank_code": "001"},
        )
        self.assertEqual(item.account.bank_code, "001")

    def test_a_code_sent_or_stored_wins_over_the_transfer_number(self):
        self._with_transfer_number("001/0514/00050338-0")

        self._update({"outgoing_transfers_are_income": True, "bank_code": "237"})
        self.stored = make_bank_account(id=self.stored.id, bank_code="104")
        self._update({"outgoing_transfers_are_income": True})

        self.bank_datas.get_bank_data_by_bank_account_id.assert_not_called()

    def test_a_transfer_number_without_bank_code_is_not_enough(self):
        self._with_transfer_number("0514/00050338-0")

        with self.assertRaises(InvalidDataError):
            self._update({"outgoing_transfers_are_income": True})
        self.repository.update_bank_account.assert_not_called()

    def test_clearing_the_code_does_not_take_it_from_the_transfer_number(self):
        self._with_transfer_number("001/0514/00050338-0")
        self.stored = make_bank_account(
            id=self.stored.id, outgoing_transfers_are_income=True, bank_code="001"
        )

        with self.assertRaises(InvalidDataError):
            self._update({"bank_code": None})

    def test_turning_the_flag_off_does_not_look_for_a_code(self):
        self._update({"outgoing_transfers_are_income": False})

        self.bank_datas.get_bank_data_by_bank_account_id.assert_not_called()

    def test_the_same_values_write_nothing(self):
        self.stored = make_bank_account(
            id=self.stored.id, outgoing_transfers_are_income=True, bank_code="001"
        )

        _, changed = self._update(
            {"outgoing_transfers_are_income": True, "bank_code": "001"}
        )

        self.assertFalse(changed)
        self.repository.update_bank_account.assert_not_called()

    def test_the_flag_on_without_a_bank_code_is_invalid(self):
        with self.assertRaises(InvalidDataError):
            self._update({"outgoing_transfers_are_income": True})

        self.stored = make_bank_account(
            id=self.stored.id, outgoing_transfers_are_income=True, bank_code="001"
        )
        with self.assertRaises(InvalidDataError):
            self._update({"bank_code": None})
        self.repository.update_bank_account.assert_not_called()

    def test_a_credit_card_has_no_such_settings(self):
        self.stored = make_bank_account(
            id=self.stored.id, type="CREDIT", subtype="CREDIT_CARD"
        )

        with self.assertRaises(InvalidDataError):
            self._update({"bank_code": "001"})

    def test_an_account_outside_the_household_is_not_found(self):
        self.repository.get_bank_account_with_owner.side_effect = None
        self.repository.get_bank_account_with_owner.return_value = None

        with self.assertRaises(NotFoundError):
            self._update({"bank_code": "001"})

    def test_only_user_settings_can_be_changed(self):
        with self.assertRaises(ValueError):
            self._update({"number": "999"})
        self.repository.get_bank_account_with_owner.assert_not_called()


if __name__ == "__main__":
    unittest.main()
