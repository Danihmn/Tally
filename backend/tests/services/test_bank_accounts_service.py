import dataclasses
import unittest
import uuid
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from domain.entities import BankAccount
from services.bank_accounts_service import list_bank_accounts_by_user
from tests.factories import make_bank_account

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
