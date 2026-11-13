import datetime
import unittest
import uuid
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from agents.common.context import AgentContext
from agents.tools.transactions import (
    get_household_spending_summary,
    get_household_transactions,
    get_my_spending_summary,
    get_my_transactions,
)
from domain.read_models import (
    TransactionGroupTotal,
    TransactionSummary,
    TransactionWithOwner,
)
from tests.factories import (
    HOUSEHOLD_ID,
    USER_ID,
    fake_get_session,
    make_transaction,
    make_user,
    utc,
)

MODULE = "agents.tools.transactions"
PARTNER_ID = uuid.UUID("00000000-0000-0000-0000-00000000b002")


class ToolTestCase(unittest.TestCase):
    """Patches the services and the clock of the tools' module (no database, no model)."""

    def setUp(self):
        self.user = make_user(first_name="Ana")
        self.partner = make_user(id=PARTNER_ID, first_name="Bia")
        self.runtime = SimpleNamespace(context=AgentContext(user=self.user))

        self.mocks = {}
        for name in (
            "search_transactions",
            "summarize_transactions",
            "summarize_transactions_by",
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

        self.mocks["search_transactions"].return_value = ([], 0)
        self.mocks["summarize_transactions"].return_value = TransactionSummary()
        self.mocks["summarize_transactions_by"].return_value = []
        self.mocks["owner_names"].return_value = {
            self.user.id: "Ana",
            self.partner.id: "Bia",
        }

    def filters(self):
        return self.mocks["search_transactions"].call_args.args[1]


class ScopeTests(ToolTestCase):
    def test_my_transactions_are_filtered_by_user_and_household(self):
        get_my_transactions.func(runtime=self.runtime)

        filters = self.filters()
        self.assertEqual(filters.user_id, USER_ID)
        self.assertEqual(filters.household_id, HOUSEHOLD_ID)

    def test_household_transactions_are_not_filtered_by_user(self):
        get_household_transactions.func(runtime=self.runtime)

        filters = self.filters()
        self.assertIsNone(filters.user_id)
        self.assertEqual(filters.household_id, HOUSEHOLD_ID)

    def test_the_user_and_the_household_are_not_arguments_of_the_model(self):
        for tool in (get_my_transactions, get_household_transactions):
            self.assertNotIn("runtime", tool.args)
            self.assertNotIn("user_id", tool.args)
            self.assertNotIn("household_id", tool.args)


class PeriodTests(ToolTestCase):
    def test_without_dates_it_uses_the_current_month_and_says_so(self):
        result = get_my_transactions.func(runtime=self.runtime)

        filters = self.filters()
        self.assertEqual(filters.date_from, utc(2026, 11, 1, hour=0))
        self.assertEqual(filters.date_to, utc(2026, 12, 1, hour=0))  # exclusive end
        self.assertIn("Period: 2026-11-01 to 2026-11-30 (current month", result)

    def test_both_days_are_inclusive(self):
        get_my_transactions.func(runtime=self.runtime, date_from="2026-10-01", date_to="2026-10-31")

        filters = self.filters()
        self.assertEqual(filters.date_from, utc(2026, 10, 1, hour=0))
        self.assertEqual(filters.date_to, utc(2026, 11, 1, hour=0))

    def test_only_date_from_goes_until_today(self):
        result = get_my_transactions.func(runtime=self.runtime, date_from="2026-11-03")

        self.assertIn("Period: 2026-11-03 to 2026-11-10", result)

    def test_invalid_date_returns_an_error_for_the_model_to_retry(self):
        result = get_my_transactions.func(runtime=self.runtime, date_from="last month")

        self.assertTrue(result.startswith("Error:"))
        self.mocks["search_transactions"].assert_not_called()

    def test_inverted_period_returns_an_error(self):
        result = get_my_transactions.func(
            runtime=self.runtime, date_from="2026-11-05", date_to="2026-11-01"
        )

        self.assertTrue(result.startswith("Error:"))
        self.mocks["search_transactions"].assert_not_called()


class LimitAndFiltersTests(ToolTestCase):
    def test_limit_is_capped_at_fifty(self):
        get_my_transactions.func(runtime=self.runtime, limit=500)

        self.assertEqual(self.mocks["search_transactions"].call_args.kwargs["limit"], 50)

    def test_limit_has_a_floor_of_one(self):
        get_my_transactions.func(runtime=self.runtime, limit=0)

        self.assertEqual(self.mocks["search_transactions"].call_args.kwargs["limit"], 1)

    def test_type_category_and_search_are_passed_to_the_filters(self):
        get_household_transactions.func(
            runtime=self.runtime, type="DEBIT", category="Food", search="market"
        )

        filters = self.filters()
        self.assertEqual(filters.type, "DEBIT")
        self.assertEqual(filters.category, "Food")
        self.assertEqual(filters.search, "market")

    def test_empty_strings_do_not_filter(self):
        get_household_transactions.func(runtime=self.runtime, category="", search="")

        filters = self.filters()
        self.assertIsNone(filters.category)
        self.assertIsNone(filters.search)


class OutputTests(ToolTestCase):
    def test_no_transactions_says_so(self):
        result = get_my_transactions.func(runtime=self.runtime)

        self.assertIn("No transactions found", result)

    def test_lines_have_the_owner_name_and_the_totals_come_from_the_summary(self):
        self.mocks["search_transactions"].return_value = (
            [
                TransactionWithOwner(
                    transaction=make_transaction(
                        date=utc(2026, 11, 5),
                        amount=Decimal("-100"),
                        description="Market",
                    ),
                    user_id=USER_ID,
                ),
                TransactionWithOwner(
                    transaction=make_transaction(
                        date=utc(2026, 11, 4),
                        amount=Decimal("-30.5"),
                        description=None,
                    ),
                    user_id=PARTNER_ID,
                ),
            ],
            134,
        )
        self.mocks["summarize_transactions"].return_value = TransactionSummary(
            debit_total=Decimal("1234.5"),
            credit_total=Decimal("500"),
            debit_count=80,
            credit_count=54,
        )

        result = get_household_transactions.func(runtime=self.runtime)

        self.assertIn("2026-11-05 | -100.00 | DEBIT | Market | Ana", result)
        self.assertIn("2026-11-04 | -30.50 | DEBIT | - | Bia", result)
        self.assertIn("Showing 2 of 134 transactions", result)
        self.assertIn("Total debits: 1234.50 (80 transactions)", result)
        self.assertIn("Total credits: 500.00 (54 transactions)", result)

    def test_the_summary_uses_the_same_filters_as_the_listing(self):
        get_my_transactions.func(runtime=self.runtime, type="DEBIT")

        self.assertIs(self.mocks["summarize_transactions"].call_args.args[1], self.filters())


class SpendingSummaryScopeTests(ToolTestCase):
    def summary_call(self):
        return self.mocks["summarize_transactions_by"].call_args.args

    def test_my_summary_is_filtered_by_user_and_groups_by_category_by_default(self):
        get_my_spending_summary.func(runtime=self.runtime)

        _, filters, by_owner, by_category = self.summary_call()
        self.assertEqual(filters.user_id, USER_ID)
        self.assertEqual(filters.household_id, HOUSEHOLD_ID)
        self.assertEqual((by_owner, by_category), (False, True))

    def test_the_summaries_leave_internal_transfers_out_but_the_listings_do_not(self):
        get_my_spending_summary.func(runtime=self.runtime)
        get_household_spending_summary.func(runtime=self.runtime)
        get_my_transactions.func(runtime=self.runtime)

        for call in self.mocks["summarize_transactions_by"].call_args_list:
            self.assertTrue(call.args[1].exclude_internal_transfers)
        self.assertFalse(self.filters().exclude_internal_transfers)

    def test_household_summary_is_not_filtered_by_user_and_groups_by_owner_by_default(self):
        get_household_spending_summary.func(runtime=self.runtime)

        _, filters, by_owner, by_category = self.summary_call()
        self.assertIsNone(filters.user_id)
        self.assertEqual(filters.household_id, HOUSEHOLD_ID)
        self.assertEqual((by_owner, by_category), (True, False))

    def test_owner_and_category_groups_by_both(self):
        get_household_spending_summary.func(
            runtime=self.runtime, group_by="owner_and_category"
        )

        _, _, by_owner, by_category = self.summary_call()
        self.assertEqual((by_owner, by_category), (True, True))

    def test_unknown_group_by_returns_an_error(self):
        result = get_household_spending_summary.func(runtime=self.runtime, group_by="month")

        self.assertTrue(result.startswith("Error:"))
        self.mocks["summarize_transactions_by"].assert_not_called()

    def test_the_user_and_the_household_are_not_arguments_of_the_model(self):
        for tool in (get_my_spending_summary, get_household_spending_summary):
            self.assertNotIn("runtime", tool.args)
            self.assertNotIn("user_id", tool.args)
            self.assertNotIn("household_id", tool.args)

    def test_period_and_filters_are_the_same_as_the_transactions_tools(self):
        get_household_spending_summary.func(
            runtime=self.runtime,
            date_from="2026-10-01",
            date_to="2026-10-31",
            type="DEBIT",
            category="",
            search="ifood",
        )

        _, filters, _, _ = self.summary_call()
        self.assertEqual(filters.date_from, utc(2026, 10, 1, hour=0))
        self.assertEqual(filters.date_to, utc(2026, 11, 1, hour=0))
        self.assertEqual(filters.type, "DEBIT")
        self.assertIsNone(filters.category)
        self.assertEqual(filters.search, "ifood")
        self.assertIs(self.mocks["summarize_transactions"].call_args.args[1], filters)

    def test_invalid_period_returns_an_error(self):
        result = get_my_spending_summary.func(runtime=self.runtime, date_from="ontem")

        self.assertTrue(result.startswith("Error:"))
        self.mocks["summarize_transactions_by"].assert_not_called()


class SpendingSummaryOutputTests(ToolTestCase):
    def test_no_transactions_says_so(self):
        result = get_household_spending_summary.func(runtime=self.runtime)

        self.assertIn("No transactions found", result)
        self.assertIn("Period: 2026-11-01 to 2026-11-30 (current month", result)

    def test_groups_by_owner_use_first_names_and_keep_the_service_order(self):
        self.mocks["summarize_transactions_by"].return_value = [
            TransactionGroupTotal(
                user_id=PARTNER_ID,
                debit_total=Decimal("900"),
                debit_count=12,
                credit_total=Decimal("50.5"),
                credit_count=1,
            ),
            TransactionGroupTotal(user_id=USER_ID, debit_total=Decimal("300.1"), debit_count=4),
        ]
        self.mocks["summarize_transactions"].return_value = TransactionSummary(
            debit_total=Decimal("1200.10"), debit_count=16, credit_total=Decimal("50.50"), credit_count=1
        )

        result = get_household_spending_summary.func(runtime=self.runtime)

        lines = result.splitlines()
        self.assertIn("owner | total debits | debit count | total credits | credit count", lines)
        bia = lines.index("Bia | 900.00 | 12 | 50.50 | 1")
        ana = lines.index("Ana | 300.10 | 4 | 0.00 | 0")
        self.assertLess(bia, ana)
        self.assertIn("Total debits: 1200.10 (16 transactions)", result)
        self.assertIn("Total credits: 50.50 (1 transactions)", result)

    def test_groups_by_category_name_the_missing_category(self):
        self.mocks["summarize_transactions_by"].return_value = [
            TransactionGroupTotal(category="Food", debit_total=Decimal("10"), debit_count=1),
            TransactionGroupTotal(category=None, debit_total=Decimal("5"), debit_count=1),
        ]

        result = get_my_spending_summary.func(runtime=self.runtime)

        self.assertIn("category | total debits", result)
        self.assertIn("Food | 10.00 | 1 | 0.00 | 0", result)
        self.assertIn("sem categoria | 5.00 | 1 | 0.00 | 0", result)
        self.assertNotIn("Ana |", result)

    def test_owner_and_category_lines_have_both_columns(self):
        self.mocks["summarize_transactions_by"].return_value = [
            TransactionGroupTotal(
                user_id=USER_ID, category="Food", debit_total=Decimal("10"), debit_count=1
            ),
        ]

        result = get_household_spending_summary.func(
            runtime=self.runtime, group_by="owner_and_category"
        )

        self.assertIn("owner | category | total debits", result)
        self.assertIn("Ana | Food | 10.00 | 1 | 0.00 | 0", result)

    def test_an_owner_outside_the_household_list_is_shown_as_unknown(self):
        self.mocks["summarize_transactions_by"].return_value = [
            TransactionGroupTotal(user_id=uuid.uuid4(), debit_total=Decimal("1"), debit_count=1),
        ]

        result = get_household_spending_summary.func(runtime=self.runtime)

        self.assertIn("? | 1.00 | 1", result)
