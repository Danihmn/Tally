import unittest
from decimal import Decimal
from unittest.mock import MagicMock, patch

from domain.read_models import FinancialEntryFilters
from services.financial_entries_service import summarize_financial_entries

MODULE = "services.financial_entries_service"


class SummarizeFinancialEntriesTests(unittest.TestCase):
    def _summarize(self, rows):
        session, filters = MagicMock(), FinancialEntryFilters()
        with patch(f"{MODULE}.financial_entries_repository") as repository:
            repository.summarize_financial_entries.return_value = rows
            summary = summarize_financial_entries(session, filters)
        repository.summarize_financial_entries.assert_called_once_with(session, filters)
        return summary

    def test_maps_each_type_and_status_to_its_total_and_count(self):
        summary = self._summarize([
            ("EXPENSES", "PLANNED", Decimal("100"), 2),
            ("EXPENSES", "RECONCILED", Decimal("50.5"), 1),
            ("EXPENSES", "CANCELLED", Decimal("9"), 1),
            ("REVENUES", "RECONCILED", Decimal("7000"), 1),
        ])

        expenses = summary.expenses
        self.assertEqual((expenses.planned_total, expenses.planned_count), (Decimal("100"), 2))
        self.assertEqual((expenses.reconciled_total, expenses.reconciled_count), (Decimal("50.5"), 1))
        self.assertEqual((expenses.cancelled_total, expenses.cancelled_count), (Decimal("9"), 1))
        self.assertEqual(summary.revenues.reconciled_total, Decimal("7000"))
        self.assertEqual(summary.revenues.planned_count, 0)

    def test_no_entries_is_all_zero(self):
        summary = self._summarize([])

        for totals in (summary.revenues, summary.expenses):
            self.assertEqual(totals.planned_total, Decimal("0.00"))
            self.assertEqual(totals.reconciled_count, 0)

    def test_unknown_type_or_status_is_ignored(self):
        summary = self._summarize([
            ("OTHER", "PLANNED", Decimal("1"), 1),
            ("EXPENSES", "WEIRD", Decimal("1"), 1),
        ])

        self.assertEqual(summary.expenses.planned_total, Decimal("0.00"))
        self.assertEqual(summary.revenues.planned_total, Decimal("0.00"))

    def test_each_summary_has_its_own_totals(self):
        first = self._summarize([("EXPENSES", "PLANNED", Decimal("1"), 1)])
        second = self._summarize([])

        self.assertIsNot(first.expenses, second.expenses)
        self.assertEqual(second.expenses.planned_total, Decimal("0.00"))


if __name__ == "__main__":
    unittest.main()
