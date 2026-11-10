import datetime
import types
import unittest
import uuid
from decimal import Decimal
from unittest.mock import MagicMock, call, patch

from domain.entities import Reconciliation
from domain.read_models import TransactionWithOwner
from infra.jobs import reconciliation_registration
from infra.jobs.reconciliation_registration import (
    _load_transactions,
    _window_start,
    reconciliate_financial_entries,
)
from services.exceptions import ServiceError
from tests.factories import (
    USER_ID,
    fake_get_session,
    make_entry,
    make_reconciliation,
    make_transaction,
)

MODULE = "infra.jobs.reconciliation_registration"
WINDOW_START = datetime.date(2026, 9, 1)


def _frozen_datetime_module(now: datetime.datetime) -> types.SimpleNamespace:
    """The `datetime` module as the job sees it, with `datetime.now()` frozen."""

    class FrozenDatetime(datetime.datetime):
        @classmethod
        def now(cls, tz=None):
            return now

    return types.SimpleNamespace(
        datetime=FrozenDatetime,
        date=datetime.date,
        time=datetime.time,
        UTC=datetime.UTC,
    )


def _owned(transactions):
    return [TransactionWithOwner(transaction=t, user_id=USER_ID) for t in transactions]


class WindowStartTests(unittest.TestCase):
    def test_first_day_of_the_month_two_months_ago(self):
        cases = {
            datetime.datetime(2026, 11, 10, tzinfo=datetime.UTC): datetime.date(
                2026, 9, 1
            ),
            datetime.datetime(2026, 1, 31, tzinfo=datetime.UTC): datetime.date(
                2025, 11, 1
            ),
            datetime.datetime(2026, 3, 1, tzinfo=datetime.UTC): datetime.date(
                2026, 1, 1
            ),
        }
        for now, expected in cases.items():
            with (
                self.subTest(now=now),
                patch(f"{MODULE}.datetime", _frozen_datetime_module(now)),
            ):
                self.assertEqual(_window_start(), expected)


class LoadTransactionsTests(unittest.TestCase):
    def setUp(self):
        patcher = patch(f"{MODULE}.search_transactions")
        self.search_transactions = patcher.start()
        self.addCleanup(patcher.stop)
        self.session = MagicMock()

    def test_filters_posted_transactions_of_the_user_since_the_window(self):
        self.search_transactions.return_value = ([], 0)

        _load_transactions(self.session, USER_ID, WINDOW_START)

        filters = self.search_transactions.call_args.args[1]
        self.assertEqual(filters.user_id, USER_ID)
        self.assertEqual(filters.status, "POSTED")
        self.assertEqual(
            filters.date_from, datetime.datetime(2026, 9, 1, tzinfo=datetime.UTC)
        )

    def test_reads_every_page(self):
        size = reconciliation_registration._TRANSACTIONS_PAGE_SIZE
        first = [make_transaction() for _ in range(size)]
        second = [make_transaction()]
        self.search_transactions.side_effect = [
            (_owned(first), size + 1),
            (_owned(second), size + 1),
        ]

        transactions = _load_transactions(self.session, USER_ID, WINDOW_START)

        self.assertEqual(transactions, first + second)
        self.assertEqual(
            [c.kwargs for c in self.search_transactions.call_args_list],
            [{"limit": size, "offset": 0}, {"limit": size, "offset": size}],
        )

    def test_stops_on_an_empty_page(self):
        self.search_transactions.return_value = ([], 999)

        self.assertEqual(_load_transactions(self.session, USER_ID, WINDOW_START), [])
        self.search_transactions.assert_called_once()


class ReconciliateFinancialEntriesTests(unittest.TestCase):
    def setUp(self):
        self.session = MagicMock()
        self.mocks = {}
        for name in (
            "list_financial_entries_by_user",
            "search_transactions",
            "list_reconciliations_by_transactions",
            "create_reconciliation",
            "mark_financial_entries_status",
        ):
            patcher = patch(f"{MODULE}.{name}")
            self.mocks[name] = patcher.start()
            self.addCleanup(patcher.stop)
        for name, value in (
            ("get_session", fake_get_session(self.session)),
            ("_window_start", lambda: WINDOW_START),
        ):
            patcher = patch(f"{MODULE}.{name}", value)
            patcher.start()
            self.addCleanup(patcher.stop)
        self.mocks["list_reconciliations_by_transactions"].return_value = []

    def _given(self, entries, transactions):
        self.mocks["list_financial_entries_by_user"].return_value = entries
        self.mocks["search_transactions"].side_effect = [
            (_owned(transactions), len(transactions)),
            ([], len(transactions)),
        ]

    def test_loads_the_planned_entries_of_the_window(self):
        self._given([], [])

        reconciliate_financial_entries(USER_ID)

        self.mocks["list_financial_entries_by_user"].assert_called_once_with(
            self.session, USER_ID, reference_month_from=WINDOW_START, status="PLANNED"
        )

    def test_no_entries_does_not_load_transactions(self):
        self._given([], [make_transaction()])

        reconciliate_financial_entries(USER_ID)

        self.mocks["search_transactions"].assert_not_called()
        self.session.commit.assert_not_called()

    def test_unambiguous_pair_is_reconciled(self):
        entry = make_entry()
        transaction = make_transaction()
        self._given([entry], [transaction])

        reconciliate_financial_entries(USER_ID)

        self.mocks["create_reconciliation"].assert_called_once_with(
            self.session,
            Reconciliation(
                financial_entry_id=entry.id,
                transaction_id=transaction.id,
                source="AUTO",
            ),
        )
        self.mocks["mark_financial_entries_status"].assert_called_once_with(
            self.session, [entry.id], "RECONCILED"
        )
        self.session.commit.assert_called_once()

    def test_reconciles_every_pair_in_one_commit(self):
        entries = [
            make_entry(amount=Decimal("10.00")),
            make_entry(amount=Decimal("20.00")),
        ]
        transactions = [
            make_transaction(amount=Decimal("-10.00")),
            make_transaction(amount=Decimal("-20.00")),
        ]
        self._given(entries, transactions)

        reconciliate_financial_entries(USER_ID)

        self.assertEqual(self.mocks["create_reconciliation"].call_count, 2)
        self.mocks["mark_financial_entries_status"].assert_called_once_with(
            self.session, [e.id for e in entries], "RECONCILED"
        )
        self.session.commit.assert_called_once()

    def test_already_reconciled_transaction_is_not_used(self):
        entry = make_entry()
        transaction = make_transaction()
        self._given([entry], [transaction])
        self.mocks["list_reconciliations_by_transactions"].return_value = [
            make_reconciliation(transaction_id=transaction.id)
        ]

        reconciliate_financial_entries(USER_ID)

        self.mocks["list_reconciliations_by_transactions"].assert_called_once_with(
            self.session, [transaction.id]
        )
        self.mocks["create_reconciliation"].assert_not_called()
        self.session.commit.assert_not_called()

    def test_ambiguous_entries_are_left_for_the_agent(self):
        self._given([make_entry()], [make_transaction(), make_transaction()])

        reconciliate_financial_entries(USER_ID)

        self.mocks["create_reconciliation"].assert_not_called()
        self.mocks["mark_financial_entries_status"].assert_not_called()
        self.session.commit.assert_not_called()

    def test_service_error_rolls_back_the_whole_run(self):
        self._given([make_entry()], [make_transaction()])
        self.mocks["mark_financial_entries_status"].side_effect = ServiceError("db")

        reconciliate_financial_entries(USER_ID)

        self.session.rollback.assert_called_once()
        self.session.commit.assert_not_called()

    def test_unexpected_error_is_raised(self):
        self.mocks["list_financial_entries_by_user"].side_effect = RuntimeError("bug")

        with self.assertRaises(RuntimeError):
            reconciliate_financial_entries(uuid.uuid4())

        self.assertNotIn(call.commit(), self.session.mock_calls)


if __name__ == "__main__":
    unittest.main()
