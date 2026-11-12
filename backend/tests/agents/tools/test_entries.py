import datetime
import unittest
import uuid
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from agents.common.context import AgentContext
from agents.tools.entries import get_household_entries, get_my_entries
from domain.read_models import FinancialEntrySummary, FinancialEntryTotals
from tests.factories import (
    HOUSEHOLD_ID,
    USER_ID,
    fake_get_session,
    make_entry,
    make_user,
)

MODULE = "agents.tools.entries"
PARTNER_ID = uuid.UUID("00000000-0000-0000-0000-00000000b002")


class EntriesToolTestCase(unittest.TestCase):
    """Patches the services and the clock of the tools' module (no database, no model)."""

    def setUp(self):
        self.user = make_user(first_name="Ana")
        self.partner = make_user(id=PARTNER_ID, first_name="Bia")
        self.runtime = SimpleNamespace(context=AgentContext(user=self.user))

        self.mocks = {}
        for name in (
            "search_financial_entries",
            "summarize_financial_entries",
            "owner_names",
        ):
            patcher = patch(f"{MODULE}.{name}")
            self.mocks[name] = patcher.start()
            self.addCleanup(patcher.stop)
        session_patcher = patch(f"{MODULE}.get_session", fake_get_session(MagicMock()))
        session_patcher.start()
        self.addCleanup(session_patcher.stop)
        today_patcher = patch(f"{MODULE}.today", return_value=datetime.date(2026, 11, 10))
        today_patcher.start()
        self.addCleanup(today_patcher.stop)

        self.mocks["search_financial_entries"].return_value = ([], 0)
        self.mocks["summarize_financial_entries"].return_value = FinancialEntrySummary()
        self.mocks["owner_names"].return_value = {
            self.user.id: "Ana",
            self.partner.id: "Bia",
        }

    def filters(self):
        return self.mocks["search_financial_entries"].call_args.args[1]

    def with_entries(self, *entries, total=None):
        self.mocks["search_financial_entries"].return_value = (
            list(entries),
            len(entries) if total is None else total,
        )


class ScopeTests(EntriesToolTestCase):
    def test_my_entries_are_filtered_by_user_and_household(self):
        get_my_entries.func(runtime=self.runtime)

        filters = self.filters()
        self.assertEqual(filters.user_id, USER_ID)
        self.assertEqual(filters.household_id, HOUSEHOLD_ID)

    def test_household_entries_are_not_filtered_by_user(self):
        get_household_entries.func(runtime=self.runtime)

        filters = self.filters()
        self.assertIsNone(filters.user_id)
        self.assertEqual(filters.household_id, HOUSEHOLD_ID)

    def test_the_user_and_the_household_are_not_arguments_of_the_model(self):
        for tool in (get_my_entries, get_household_entries):
            self.assertNotIn("runtime", tool.args)
            self.assertNotIn("user_id", tool.args)
            self.assertNotIn("household_id", tool.args)


class MonthsTests(EntriesToolTestCase):
    def test_without_months_it_uses_the_current_month_and_says_so(self):
        result = get_my_entries.func(runtime=self.runtime)

        filters = self.filters()
        self.assertEqual(filters.reference_month_from, datetime.date(2026, 11, 1))
        self.assertEqual(filters.reference_month_to, datetime.date(2026, 11, 1))
        self.assertIn("Reference months: 2026-11 (current month", result)

    def test_both_months_are_inclusive_first_days(self):
        result = get_my_entries.func(runtime=self.runtime, month_from="2026-09", month_to="2026-11")

        filters = self.filters()
        self.assertEqual(filters.reference_month_from, datetime.date(2026, 9, 1))
        self.assertEqual(filters.reference_month_to, datetime.date(2026, 11, 1))
        self.assertIn("Reference months: 2026-09 to 2026-11", result)

    def test_only_one_month_means_that_month(self):
        for kwargs in ({"month_from": "2026-12"}, {"month_to": "2026-12"}):
            with self.subTest(**kwargs):
                get_my_entries.func(runtime=self.runtime, **kwargs)

                filters = self.filters()
                self.assertEqual(filters.reference_month_from, datetime.date(2026, 12, 1))
                self.assertEqual(filters.reference_month_to, datetime.date(2026, 12, 1))

    def test_invalid_month_returns_an_error_for_the_model_to_retry(self):
        for value in ("2026-11-05", "novembro", "2026-13"):
            with self.subTest(value=value):
                result = get_my_entries.func(runtime=self.runtime, month_from=value)

                self.assertTrue(result.startswith("Error:"))
        self.mocks["search_financial_entries"].assert_not_called()

    def test_inverted_months_return_an_error(self):
        result = get_my_entries.func(runtime=self.runtime, month_from="2026-12", month_to="2026-10")

        self.assertTrue(result.startswith("Error:"))
        self.mocks["search_financial_entries"].assert_not_called()


class LimitAndFiltersTests(EntriesToolTestCase):
    def test_limit_is_capped_at_fifty(self):
        get_my_entries.func(runtime=self.runtime, limit=500)

        self.assertEqual(self.mocks["search_financial_entries"].call_args.kwargs["limit"], 50)

    def test_limit_has_a_floor_of_one(self):
        get_my_entries.func(runtime=self.runtime, limit=-3)

        self.assertEqual(self.mocks["search_financial_entries"].call_args.kwargs["limit"], 1)

    def test_type_status_category_and_search_are_passed_to_the_filters(self):
        get_household_entries.func(
            runtime=self.runtime,
            type="EXPENSES",
            status="PLANNED",
            category="Moradia",
            search="aluguel",
        )

        filters = self.filters()
        self.assertEqual(filters.type, "EXPENSES")
        self.assertEqual(filters.status, "PLANNED")
        self.assertEqual(filters.category, "Moradia")
        self.assertEqual(filters.search, "aluguel")

    def test_empty_strings_do_not_filter(self):
        get_household_entries.func(runtime=self.runtime, category="", search="")

        filters = self.filters()
        self.assertIsNone(filters.category)
        self.assertIsNone(filters.search)

    def test_the_summary_uses_the_same_filters_as_the_listing(self):
        get_my_entries.func(runtime=self.runtime, status="RECONCILED")

        self.assertIs(self.mocks["summarize_financial_entries"].call_args.args[1], self.filters())


class OutputTests(EntriesToolTestCase):
    def test_no_entries_says_so(self):
        result = get_my_entries.func(runtime=self.runtime)

        self.assertIn("No entries found", result)

    def test_lines_have_every_column_and_the_owner_name(self):
        self.with_entries(
            make_entry(
                description="Aluguel",
                category="Moradia",
                amount=Decimal("2500"),
                due_date=datetime.date(2026, 11, 15),
                payment_type="DEBIT",
            ),
            make_entry(
                user_id=PARTNER_ID,
                description="Notebook",
                amount=Decimal("350.5"),
                status="RECONCILED",
                installment_number=3,
                installment_total=10,
            ),
            total=42,
        )

        result = get_household_entries.func(runtime=self.runtime)

        self.assertIn(
            "2026-11 | 2026-11-15 | Aluguel | Moradia | EXPENSES | DEBIT | 2500.00 | "
            "PLANNED | - | Ana",
            result,
        )
        self.assertIn(
            "2026-11 | - | Notebook | - | EXPENSES | - | 350.50 | RECONCILED | 3/10 | Bia",
            result,
        )
        self.assertIn("Showing 2 of 42 entries", result)

    def test_a_planned_entry_due_before_today_is_overdue(self):
        self.with_entries(
            make_entry(description="Luz", due_date=datetime.date(2026, 11, 9)),
            make_entry(description="Agua", due_date=datetime.date(2026, 11, 10)),
            make_entry(
                description="Internet",
                due_date=datetime.date(2026, 11, 1),
                status="RECONCILED",
            ),
        )

        result = get_my_entries.func(runtime=self.runtime)

        lines = result.splitlines()
        self.assertIn("PLANNED (overdue)", next(line for line in lines if "| Luz |" in line))
        self.assertNotIn("overdue", next(line for line in lines if "| Agua |" in line))
        self.assertNotIn("overdue", next(line for line in lines if "| Internet |" in line))

    def test_installment_without_total_shows_a_question_mark(self):
        self.with_entries(make_entry(installment_number=2))

        result = get_my_entries.func(runtime=self.runtime)

        self.assertIn("| 2/? |", result)

    def test_totals_come_from_the_summary_and_leave_cancelled_out(self):
        self.with_entries(make_entry())
        self.mocks["summarize_financial_entries"].return_value = FinancialEntrySummary(
            expenses=FinancialEntryTotals(
                planned_total=Decimal("1000"),
                planned_count=3,
                reconciled_total=Decimal("500.25"),
                reconciled_count=2,
                cancelled_total=Decimal("80"),
                cancelled_count=1,
            ),
            revenues=FinancialEntryTotals(reconciled_total=Decimal("7000"), reconciled_count=1),
        )

        result = get_household_entries.func(runtime=self.runtime)

        self.assertIn(
            "Total expenses: 1500.25 (5 entries); planned (not reconciled yet): 1000.00 (3); "
            "reconciled: 500.25 (2); cancelled, left out of the total: 80.00 (1)",
            result,
        )
        self.assertIn(
            "Total revenues: 7000.00 (1 entries); planned (not reconciled yet): 0.00 (0); "
            "reconciled: 7000.00 (1)",
            result,
        )
        revenues_line = next(line for line in result.splitlines() if "Total revenues" in line)
        self.assertNotIn("cancelled", revenues_line)

    def test_an_owner_outside_the_household_list_is_shown_as_unknown(self):
        self.with_entries(make_entry(user_id=uuid.uuid4()))

        result = get_household_entries.func(runtime=self.runtime)

        self.assertIn("| - | ?", result)


if __name__ == "__main__":
    unittest.main()
