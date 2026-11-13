import unittest
from decimal import Decimal
from unittest.mock import MagicMock, patch

import uuid

from domain.read_models import FinancialEntryFilters
from services.financial_entries_service import (
    count_not_reconciled_entries,
    count_reconciled_entries,
    get_total_not_reconciled,
    get_total_planned,
    get_total_reconciled,
    list_upcoming_entries,
    summarize_financial_entries,
)

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


class TotalsAndCountsOfThePeriodTests(unittest.TestCase):
    HOUSEHOLD = uuid.UUID("00000000-0000-0000-0000-00000000c001")

    def _run(self, function, repository_function, answers):
        """Runs `function` with the repository answering `answers` (one per call, in order)."""
        session = MagicMock()
        filters = FinancialEntryFilters(household_id=self.HOUSEHOLD, type="EXPENSES")
        with patch(f"{MODULE}.financial_entries_repository") as repository:
            getattr(repository, repository_function).side_effect = answers
            result = function(session, filters)
        calls = getattr(repository, repository_function).call_args_list
        return result, [c.args[1] for c in calls], filters

    def test_total_reconciled_sums_only_the_reconciled_entries(self):
        total, sent, _ = self._run(
            get_total_reconciled, "sum_financial_entries_amount", [Decimal("700.50")]
        )

        self.assertEqual(total, Decimal("700.50"))
        self.assertEqual([f.status for f in sent], ["RECONCILED"])

    def test_total_not_reconciled_sums_only_the_planned_entries(self):
        total, sent, _ = self._run(
            get_total_not_reconciled, "sum_financial_entries_amount", [Decimal("300")]
        )

        self.assertEqual(total, Decimal("300"))
        self.assertEqual([f.status for f in sent], ["PLANNED"])

    def test_total_planned_is_reconciled_plus_not_reconciled(self):
        total, sent, _ = self._run(
            get_total_planned,
            "sum_financial_entries_amount",
            [Decimal("700.50"), Decimal("299.50")],
        )

        self.assertEqual(total, Decimal("1000.00"))
        self.assertEqual({f.status for f in sent}, {"RECONCILED", "PLANNED"})

    def test_total_planned_never_asks_for_cancelled_entries(self):
        _, sent, _ = self._run(
            get_total_planned, "sum_financial_entries_amount", [Decimal("1"), Decimal("1")]
        )

        self.assertNotIn("CANCELLED", [f.status for f in sent])
        self.assertEqual(len(sent), 2)

    def test_total_planned_without_entries_is_zero(self):
        total, _, _ = self._run(
            get_total_planned, "sum_financial_entries_amount", [Decimal("0.00"), Decimal("0.00")]
        )

        self.assertEqual(total, Decimal("0.00"))

    def test_the_other_filters_are_kept_and_the_callers_filters_are_not_changed(self):
        _, sent, filters = self._run(
            get_total_reconciled, "sum_financial_entries_amount", [Decimal("1")]
        )

        self.assertEqual((sent[0].household_id, sent[0].type), (self.HOUSEHOLD, "EXPENSES"))
        self.assertIsNone(filters.status)

    def test_count_reconciled_counts_only_the_reconciled_entries(self):
        count, sent, _ = self._run(count_reconciled_entries, "count_financial_entries", [4])

        self.assertEqual(count, 4)
        self.assertEqual([f.status for f in sent], ["RECONCILED"])

    def test_count_not_reconciled_counts_only_the_planned_entries(self):
        count, sent, filters = self._run(
            count_not_reconciled_entries, "count_financial_entries", [0]
        )

        self.assertEqual(count, 0)
        self.assertEqual([f.status for f in sent], ["PLANNED"])
        self.assertIsNone(filters.status)


class ListUpcomingEntriesTests(unittest.TestCase):
    def _run(self, rows):
        session = MagicMock()
        filters = FinancialEntryFilters(
            household_id=uuid.UUID("00000000-0000-0000-0000-00000000c001")
        )
        with patch(f"{MODULE}.financial_entries_repository") as repository:
            repository.list_financial_entries_by_due_date.return_value = rows
            result = list_upcoming_entries(session, filters)
        return result, repository.list_financial_entries_by_due_date.call_args, filters

    def test_asks_only_for_the_entries_not_reconciled_yet(self):
        _, call, filters = self._run([])

        self.assertEqual(call.args[1].status, "PLANNED")
        self.assertEqual(call.args[1].household_id, filters.household_id)
        self.assertIsNone(filters.status)

    def test_keeps_the_order_of_the_repository(self):
        from tests.factories import make_entry

        first = make_entry(description="Rent")
        second = make_entry(description="Internet")

        result, _, _ = self._run([first, second])

        self.assertEqual([e.description for e in result], ["Rent", "Internet"])

    def test_without_entries_the_list_is_empty(self):
        result, _, _ = self._run([])

        self.assertEqual(result, [])
