import unittest
import uuid
from unittest.mock import MagicMock, call, patch

from services.common.exceptions import InvalidDataError, NotFoundError
from services.reconciliations_service import (
    link_entry,
    undo_reconciliations_of_transactions,
    unlink_entry,
)
from tests.factories import HOUSEHOLD_ID, make_entry, make_reconciliation

MODULE = "services.reconciliations_service"


class UndoReconciliationsOfTransactionsTests(unittest.TestCase):
    def setUp(self):
        self.session = MagicMock()
        self.mocks = {}
        for name in (
            "list_reconciliations_by_transactions",
            "list_reconciliations_by_entries",
            "mark_reconciliation_deleted",
            "mark_financial_entries_status",
        ):
            patcher = patch(f"{MODULE}.{name}")
            self.mocks[name] = patcher.start()
            self.addCleanup(patcher.stop)
        self.mocks["list_reconciliations_by_entries"].return_value = []

    def test_no_transactions_does_nothing(self):
        self.assertEqual(undo_reconciliations_of_transactions(self.session, []), 0)

        self.mocks["list_reconciliations_by_transactions"].assert_not_called()

    def test_no_active_reconciliation_does_nothing(self):
        self.mocks["list_reconciliations_by_transactions"].return_value = []

        self.assertEqual(
            undo_reconciliations_of_transactions(self.session, [uuid.uuid4()]), 0
        )
        self.mocks["mark_reconciliation_deleted"].assert_not_called()
        self.mocks["mark_financial_entries_status"].assert_not_called()

    def test_undoes_them_and_sends_the_entries_back_to_planned(self):
        first = make_reconciliation(source="AUTO")
        second = make_reconciliation(source="MANUAL")
        self.mocks["list_reconciliations_by_transactions"].return_value = [
            first,
            second,
        ]
        transaction_ids = [first.transaction_id, second.transaction_id]

        undone = undo_reconciliations_of_transactions(self.session, transaction_ids)

        self.assertEqual(undone, 2)
        self.mocks["list_reconciliations_by_transactions"].assert_called_once_with(
            self.session, transaction_ids
        )
        self.mocks["mark_reconciliation_deleted"].assert_has_calls(
            [call(self.session, first.id), call(self.session, second.id)]
        )
        session, entry_ids, status = self.mocks[
            "mark_financial_entries_status"
        ].call_args.args
        self.assertIs(session, self.session)
        self.assertCountEqual(
            entry_ids, [first.financial_entry_id, second.financial_entry_id]
        )
        self.assertEqual(status, "PLANNED")
        self.assertEqual(
            self.mocks["mark_financial_entries_status"].call_args.kwargs,
            {"only_from": "RECONCILED"},
        )

    def test_only_auto_keeps_the_manual_ones(self):
        auto = make_reconciliation(source="AUTO")
        manual = make_reconciliation(source="MANUAL")
        self.mocks["list_reconciliations_by_transactions"].return_value = [auto, manual]

        undone = undo_reconciliations_of_transactions(
            self.session, [auto.transaction_id, manual.transaction_id], only_auto=True
        )

        self.assertEqual(undone, 1)
        self.mocks["mark_reconciliation_deleted"].assert_called_once_with(
            self.session, auto.id
        )
        self.mocks["mark_financial_entries_status"].assert_called_once_with(
            self.session, [auto.financial_entry_id], "PLANNED", only_from="RECONCILED"
        )

    def test_entry_with_another_active_reconciliation_stays_reconciled(self):
        entry_id = uuid.uuid4()
        undone = make_reconciliation(financial_entry_id=entry_id)
        still_active = make_reconciliation(financial_entry_id=entry_id)
        self.mocks["list_reconciliations_by_transactions"].return_value = [undone]
        self.mocks["list_reconciliations_by_entries"].return_value = [still_active]

        undo_reconciliations_of_transactions(self.session, [undone.transaction_id])

        self.mocks["list_reconciliations_by_entries"].assert_called_once_with(
            self.session, [entry_id]
        )
        self.mocks["mark_financial_entries_status"].assert_called_once_with(
            self.session, [], "PLANNED", only_from="RECONCILED"
        )

    def test_reconciliation_without_id_is_ignored(self):
        self.mocks["list_reconciliations_by_transactions"].return_value = [
            make_reconciliation(id=None)
        ]

        self.assertEqual(
            undo_reconciliations_of_transactions(self.session, [uuid.uuid4()]), 0
        )
        self.mocks["mark_reconciliation_deleted"].assert_not_called()


if __name__ == "__main__":
    unittest.main()


class LinkEntryTests(unittest.TestCase):
    def setUp(self):
        self.session = MagicMock()
        self.transaction_id = uuid.uuid4()
        self.entry = make_entry(status="PLANNED")
        self.mocks = {}
        for name in (
            "get_transaction",
            "get_financial_entry",
            "create_reconciliation",
            "mark_financial_entries_status",
        ):
            patcher = patch(f"{MODULE}.{name}")
            self.mocks[name] = patcher.start()
            self.addCleanup(patcher.stop)
        self.mocks["get_financial_entry"].return_value = self.entry

    def _link(self):
        return link_entry(
            self.session, HOUSEHOLD_ID, self.transaction_id, self.entry.id
        )

    def test_creates_a_manual_reconciliation_and_the_entry_becomes_reconciled(self):
        self._link()

        reconciliation = self.mocks["create_reconciliation"].call_args.args[1]
        self.assertEqual(
            (
                reconciliation.transaction_id,
                reconciliation.financial_entry_id,
                reconciliation.source,
            ),
            (self.transaction_id, self.entry.id, "MANUAL"),
        )
        self.mocks["mark_financial_entries_status"].assert_called_once_with(
            self.session, [self.entry.id], "RECONCILED"
        )

    def test_both_are_looked_up_in_the_household_of_the_login(self):
        self._link()

        self.mocks["get_transaction"].assert_called_once_with(
            self.session, HOUSEHOLD_ID, self.transaction_id
        )
        self.mocks["get_financial_entry"].assert_called_once_with(
            self.session, HOUSEHOLD_ID, self.entry.id
        )

    def test_a_cancelled_entry_cannot_be_linked(self):
        self.entry.status = "CANCELLED"

        with self.assertRaises(InvalidDataError):
            self._link()

        self.mocks["create_reconciliation"].assert_not_called()
        self.mocks["mark_financial_entries_status"].assert_not_called()

    def test_an_unknown_transaction_links_nothing(self):
        self.mocks["get_transaction"].side_effect = NotFoundError("x")

        with self.assertRaises(NotFoundError):
            self._link()

        self.mocks["create_reconciliation"].assert_not_called()


class UnlinkEntryTests(unittest.TestCase):
    def setUp(self):
        self.session = MagicMock()
        self.transaction_id = uuid.uuid4()
        self.entry_id = uuid.uuid4()
        self.mocks = {}
        for name in (
            "get_transaction",
            "list_reconciliations_by_transactions",
            "list_reconciliations_by_entries",
            "mark_reconciliation_deleted",
            "mark_financial_entries_status",
        ):
            patcher = patch(f"{MODULE}.{name}")
            self.mocks[name] = patcher.start()
            self.addCleanup(patcher.stop)
        self.mocks["list_reconciliations_by_entries"].return_value = []

    def _unlink(self):
        unlink_entry(self.session, HOUSEHOLD_ID, self.transaction_id, self.entry_id)

    def test_undoes_only_the_link_with_that_entry_and_reopens_it(self):
        mine = make_reconciliation(
            transaction_id=self.transaction_id, financial_entry_id=self.entry_id
        )
        other = make_reconciliation(transaction_id=self.transaction_id)
        self.mocks["list_reconciliations_by_transactions"].return_value = [mine, other]

        self._unlink()

        self.mocks["mark_reconciliation_deleted"].assert_called_once_with(
            self.session, mine.id
        )
        self.mocks["mark_financial_entries_status"].assert_called_once_with(
            self.session, [self.entry_id], "PLANNED", only_from="RECONCILED"
        )

    def test_an_entry_with_another_link_stays_reconciled(self):
        mine = make_reconciliation(
            transaction_id=self.transaction_id, financial_entry_id=self.entry_id
        )
        self.mocks["list_reconciliations_by_transactions"].return_value = [mine]
        self.mocks["list_reconciliations_by_entries"].return_value = [
            make_reconciliation(financial_entry_id=self.entry_id)
        ]

        self._unlink()

        self.mocks["mark_financial_entries_status"].assert_called_once_with(
            self.session, [], "PLANNED", only_from="RECONCILED"
        )

    def test_a_pair_that_is_not_linked_is_not_found(self):
        self.mocks["list_reconciliations_by_transactions"].return_value = [
            make_reconciliation(transaction_id=self.transaction_id)
        ]

        with self.assertRaises(NotFoundError):
            self._unlink()

        self.mocks["mark_reconciliation_deleted"].assert_not_called()

    def test_a_transaction_outside_the_household_is_not_found(self):
        self.mocks["get_transaction"].side_effect = NotFoundError("x")

        with self.assertRaises(NotFoundError):
            self._unlink()

        self.mocks["list_reconciliations_by_transactions"].assert_not_called()
