import unittest
import uuid
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from agents.common.context import AgentContext
from agents.tools.recurrences import get_household_recurrences, get_my_recurrences
from tests.factories import HOUSEHOLD_ID, fake_get_session, make_recurrence, make_user

MODULE = "agents.tools.recurrences"
PARTNER_ID = uuid.UUID("00000000-0000-0000-0000-00000000b002")


class RecurrencesToolTestCase(unittest.TestCase):
    """Patches the services of the tools' module (no database, no model)."""

    def setUp(self):
        self.user = make_user(first_name="Ana")
        self.runtime = SimpleNamespace(context=AgentContext(user=self.user))

        self.search = self._patch("search_recurrences")
        self.search.return_value = ([], 0)
        self._patch("owner_names").return_value = {self.user.id: "Ana", PARTNER_ID: "Bia"}
        session_patcher = patch(f"{MODULE}.get_session", fake_get_session(MagicMock()))
        session_patcher.start()
        self.addCleanup(session_patcher.stop)

    def _patch(self, name):
        patcher = patch(f"{MODULE}.{name}")
        mock = patcher.start()
        self.addCleanup(patcher.stop)
        return mock

    def with_recurrences(self, *recurrences):
        self.search.return_value = (list(recurrences), len(recurrences))

    def filters(self):
        return self.search.call_args.args[1]


class FilterTests(RecurrencesToolTestCase):
    def test_household_and_active_status_are_used_by_default(self):
        get_household_recurrences.func(runtime=self.runtime)

        filters = self.filters()
        self.assertEqual(filters.household_id, HOUSEHOLD_ID)
        self.assertEqual(filters.status, "ACTIVE")
        self.assertIsNone(filters.type)
        self.assertIsNone(filters.search)

    def test_filters_from_the_model_are_passed_to_the_service(self):
        get_household_recurrences.func(
            runtime=self.runtime, type="REVENUES", status="CANCELLED", search="salário"
        )

        filters = self.filters()
        self.assertEqual(filters.type, "REVENUES")
        self.assertEqual(filters.status, "CANCELLED")
        self.assertEqual(filters.search, "salário")

    def test_the_user_and_the_household_are_not_arguments_of_the_model(self):
        for tool in (get_my_recurrences, get_household_recurrences):
            self.assertNotIn("runtime", tool.args)
            self.assertNotIn("household_id", tool.args)
            self.assertNotIn("user_id", tool.args)


class ScopeTests(RecurrencesToolTestCase):
    def test_my_recurrences_keep_only_the_logged_users_rows(self):
        self.with_recurrences(
            make_recurrence(description="Academia", user_id=self.user.id),
            make_recurrence(description="Curso", user_id=PARTNER_ID),
            make_recurrence(description="Aluguel", user_id=None),
        )

        result = get_my_recurrences.func(runtime=self.runtime)

        self.assertIn("Academia", result)
        self.assertNotIn("Curso", result)
        self.assertNotIn("Aluguel", result)
        self.assertIn("only the logged user's recurrences", result)

    def test_household_recurrences_name_the_owner_of_each_line(self):
        self.with_recurrences(
            make_recurrence(description="Academia", user_id=self.user.id),
            make_recurrence(description="Curso", user_id=PARTNER_ID),
            make_recurrence(description="Aluguel", user_id=None),
        )

        result = get_household_recurrences.func(runtime=self.runtime)

        self.assertIn("| Ana", result)
        self.assertIn("| Bia", result)
        self.assertIn("Aluguel", result)
        self.assertIn("shared (no owner)", result)
        self.assertIn("the whole household", result)


class ResultTests(RecurrencesToolTestCase):
    def test_no_recurrences_says_so(self):
        result = get_household_recurrences.func(runtime=self.runtime)

        self.assertIn("No recurrences found for these filters.", result)

    def test_monthly_totals_are_summed_per_type(self):
        self.with_recurrences(
            make_recurrence(type="EXPENSES", amount=Decimal("1500.00")),
            make_recurrence(type="EXPENSES", amount=Decimal("49.90")),
            make_recurrence(type="REVENUES", amount=Decimal("5000.00")),
        )

        result = get_household_recurrences.func(runtime=self.runtime)

        self.assertIn("expenses 1549.90, revenues 5000.00", result)

    def test_totals_cover_every_row_even_when_the_list_is_cut_by_the_limit(self):
        self.with_recurrences(
            make_recurrence(description="A", amount=Decimal("10.00")),
            make_recurrence(description="B", amount=Decimal("20.00")),
            make_recurrence(description="C", amount=Decimal("30.00")),
        )

        result = get_household_recurrences.func(runtime=self.runtime, limit=2)

        self.assertIn("Showing 2 of 3 recurrences.", result)
        self.assertNotIn("C |", result)
        self.assertIn("expenses 60.00", result)

    def test_line_has_amount_due_day_and_status(self):
        self.with_recurrences(
            make_recurrence(
                description="Aluguel",
                category="Moradia",
                payment_type="DEBIT",
                amount=Decimal("1500.00"),
                due_day=5,
            )
        )

        result = get_household_recurrences.func(runtime=self.runtime)

        self.assertIn("Aluguel | Moradia | EXPENSES | DEBIT | 1500.00 | 5 | ACTIVE | Ana", result)

    def test_a_bad_value_becomes_an_error_the_model_can_read(self):
        self.search.side_effect = ValueError("bad filter")

        result = get_household_recurrences.func(runtime=self.runtime)

        self.assertEqual(result, "Error: bad filter")


if __name__ == "__main__":
    unittest.main()
