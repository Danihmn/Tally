import datetime
import unittest
import uuid
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from agents.context import TallyContext
from agents.tools.transactions import (
    get_household_transactions,
    get_my_transactions,
)
from domain.read_models import TransactionSummary, TransactionWithOwner
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
        self.runtime = SimpleNamespace(context=TallyContext(user=self.user))

        self.mocks = {}
        for name in ("search_transactions", "summarize_transactions", "list_users_by_household"):
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
        self.mocks["list_users_by_household"].return_value = [self.user, self.partner]

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
