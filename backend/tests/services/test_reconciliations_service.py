import unittest
import uuid
from unittest.mock import MagicMock, call, patch

from services.reconciliations_service import undo_reconciliations_of_transactions
from tests.factories import make_reconciliation

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
