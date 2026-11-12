import datetime
import unittest
import uuid
from types import SimpleNamespace
from unittest.mock import MagicMock, call, patch

import httpx

from integrations.pluggy.exceptions.pluggy_exception_error import PluggyExceptionError
from integrations.pluggy.schemas.base_error_schema import BaseErrorSchema
from jobs.transaction_launcher import (
    _sync_and_commit_user,
    _sync_user_transactions,
    launch_transactions,
    launch_user_transactions,
)
from services.common.exceptions import NotFoundError, ServiceError
from tests.factories import (
    fake_get_session,
    make_pluggy_item,
    make_transaction_schema,
    make_user,
    page,
)

MODULE = "jobs.transaction_launcher"


class _FrozenDate(datetime.date):
    @classmethod
    def today(cls):
        return datetime.date(2026, 11, 10)


def _pluggy_error() -> PluggyExceptionError:
    return PluggyExceptionError(
        BaseErrorSchema.model_validate(
            {"code": 500, "codeDescription": "ERROR", "message": "boom"}
        )
    )


class SyncUserTransactionsTests(unittest.TestCase):
    def setUp(self):
        self.session = MagicMock()
        self.user = make_user()
        self.item = make_pluggy_item()
        self.stored_account = SimpleNamespace(
            id=uuid.uuid4(), household_id=self.user.household_id
        )

        self.mocks = {}
        for name in (
            "authenticate_user",
            "list_pluggy_items_by_user",
            "get_all_accounts",
            "sync_bank_account",
            "get_all_transactions",
            "sync_account_transactions",
        ):
            patcher = patch(f"{MODULE}.{name}")
            self.mocks[name] = patcher.start()
            self.addCleanup(patcher.stop)
        date_patcher = patch(f"{MODULE}.date", _FrozenDate)
        date_patcher.start()
        self.addCleanup(date_patcher.stop)

        self.mocks["authenticate_user"].return_value = "api-key"
        self.mocks["list_pluggy_items_by_user"].return_value = [self.item]
        self.mocks["get_all_accounts"].return_value = page(
            [SimpleNamespace(id="acc-1")]
        )
        self.mocks["sync_bank_account"].return_value = (self.stored_account, True)

    def _synced_transactions(self):
        """The `incoming` list passed to sync_account_transactions (single call)."""
        self.mocks["sync_account_transactions"].assert_called_once()
        return self.mocks["sync_account_transactions"].call_args.args[2]

    def test_logs_in_to_pluggy_as_the_user(self):
        self.mocks["get_all_transactions"].return_value = page([])

        _sync_user_transactions(self.session, self.user)

        self.mocks["authenticate_user"].assert_called_once_with(self.user)
        self.mocks["get_all_accounts"].assert_called_once_with(
            "api-key", str(self.item.pluggy_item_id)
        )
        # Our own pluggy_items id, not Pluggy's
        self.mocks["sync_bank_account"].assert_called_once_with(
            self.session,
            self.item.id,
            self.mocks["get_all_accounts"].return_value.results[0],
            self.user.household_id,
        )

    def test_reads_the_last_six_months_plus_one_day(self):
        self.mocks["get_all_transactions"].return_value = page([])

        _sync_user_transactions(self.session, self.user)

        self.mocks["get_all_transactions"].assert_called_once_with(
            "api-key", "acc-1", date_from="2026-05-09", next=None
        )
        self.assertEqual(
            self.mocks["sync_account_transactions"].call_args.args[3],
            datetime.datetime(2026, 5, 9, tzinfo=datetime.UTC),
        )

    def test_follows_the_pages_until_next_is_empty(self):
        first, second, third = (make_transaction_schema() for _ in range(3))
        self.mocks["get_all_transactions"].side_effect = [
            page([first], next="c1"),
            page([second], next="c2"),
            page([third]),
        ]

        _sync_user_transactions(self.session, self.user)

        self.assertEqual(
            [
                c.kwargs["next"]
                for c in self.mocks["get_all_transactions"].call_args_list
            ],
            [None, "c1", "c2"],
        )
        incoming = self._synced_transactions()
        self.assertEqual(
            [t.pluggy_transaction_id for t in incoming], [first.id, second.id, third.id]
        )
        self.assertTrue(
            all(t.bank_account_id == self.stored_account.id for t in incoming)
        )

    def test_repeated_cursor_skips_the_item(self):
        self.mocks["get_all_transactions"].side_effect = [
            page([make_transaction_schema()], next="c1"),
            page([make_transaction_schema()], next="c1"),
        ]

        _sync_user_transactions(self.session, self.user)

        # A partial list would mark the missing transactions as deleted
        self.mocks["sync_account_transactions"].assert_not_called()

    def test_page_with_only_seen_transactions_skips_the_item(self):
        repeated = make_transaction_schema()
        self.mocks["get_all_transactions"].side_effect = [
            page([repeated], next="c1"),
            page([repeated], next="c2"),
        ]

        _sync_user_transactions(self.session, self.user)

        self.mocks["sync_account_transactions"].assert_not_called()

    def test_pluggy_error_on_one_item_does_not_stop_the_others(self):
        failing, working = make_pluggy_item(), make_pluggy_item()
        self.mocks["list_pluggy_items_by_user"].return_value = [failing, working]
        self.mocks["get_all_accounts"].side_effect = [
            _pluggy_error(),
            page([SimpleNamespace(id="acc-2")]),
        ]
        self.mocks["get_all_transactions"].return_value = page([])

        _sync_user_transactions(self.session, self.user)

        self.mocks["sync_bank_account"].assert_called_once()
        self.assertEqual(self.mocks["sync_bank_account"].call_args.args[1], working.id)
        self.mocks["sync_account_transactions"].assert_called_once()

    def test_syncs_every_account_of_the_item(self):
        self.mocks["get_all_accounts"].return_value = page(
            [SimpleNamespace(id="acc-1"), SimpleNamespace(id="acc-2")]
        )
        self.mocks["get_all_transactions"].return_value = page([])

        _sync_user_transactions(self.session, self.user)

        self.assertEqual(self.mocks["sync_account_transactions"].call_count, 2)

    def test_user_without_id_is_rejected(self):
        with self.assertRaises(ValueError):
            _sync_user_transactions(self.session, make_user(id=None))

        self.mocks["authenticate_user"].assert_not_called()


class SyncAndCommitUserTests(unittest.TestCase):
    def setUp(self):
        self.session = MagicMock()
        self.user = make_user()
        self.order = (
            MagicMock()
        )  # Records the order of the sync, the commit and the reconciliation

        sync_patcher = patch(f"{MODULE}._sync_user_transactions", self.order.sync)
        reconcile_patcher = patch(
            f"{MODULE}.reconciliate_financial_entries", self.order.reconcile
        )
        sync_patcher.start()
        reconcile_patcher.start()
        self.addCleanup(sync_patcher.stop)
        self.addCleanup(reconcile_patcher.stop)
        self.session.commit = self.order.commit
        self.session.rollback = self.order.rollback

    def test_commits_and_then_reconciles(self):
        _sync_and_commit_user(self.session, self.user)

        self.assertEqual(
            self.order.mock_calls,
            [
                call.sync(self.session, self.user),
                call.commit(),
                call.reconcile(self.user.id),
            ],
        )

    def test_known_errors_roll_back_and_skip_the_reconciliation(self):
        errors = (
            ServiceError("db"),
            _pluggy_error(),
            httpx.ConnectError("down"),
            ValueError("bad data"),
        )
        for error in errors:
            with self.subTest(error=type(error).__name__):
                self.order.reset_mock()
                self.order.sync.side_effect = error

                _sync_and_commit_user(self.session, self.user)

                self.order.rollback.assert_called_once()
                self.order.commit.assert_not_called()
                self.order.reconcile.assert_not_called()

    def test_unexpected_error_is_raised(self):
        self.order.sync.side_effect = RuntimeError("bug")

        with self.assertRaises(RuntimeError):
            _sync_and_commit_user(self.session, self.user)


class LaunchTransactionsTests(unittest.TestCase):
    def setUp(self):
        self.session = MagicMock()
        for name, value in (
            ("get_session", fake_get_session(self.session)),
            ("_sync_and_commit_user", MagicMock()),
            ("iter_all_users", MagicMock()),
            ("get_user_by_id", MagicMock()),
        ):
            patcher = patch(f"{MODULE}.{name}", value)
            setattr(self, name, patcher.start())
            self.addCleanup(patcher.stop)

    def test_syncs_every_user(self):
        users = [make_user(id=uuid.uuid4()) for _ in range(3)]
        self.iter_all_users.return_value = iter(users)

        launch_transactions()

        self.iter_all_users.assert_called_once_with(self.session)
        self.assertEqual(
            self._sync_and_commit_user.call_args_list,
            [call(self.session, u) for u in users],
        )

    def test_no_users_does_nothing(self):
        self.iter_all_users.return_value = iter([])

        launch_transactions()

        self._sync_and_commit_user.assert_not_called()

    def test_launch_user_transactions_syncs_that_user(self):
        user = make_user()
        self.get_user_by_id.return_value = user

        launch_user_transactions(user.id)

        self.get_user_by_id.assert_called_once_with(self.session, user.id)
        self._sync_and_commit_user.assert_called_once_with(self.session, user)

    def test_launch_user_transactions_with_unknown_user_does_nothing(self):
        self.get_user_by_id.side_effect = NotFoundError("not found")

        launch_user_transactions(uuid.uuid4())

        self._sync_and_commit_user.assert_not_called()


if __name__ == "__main__":
    unittest.main()
