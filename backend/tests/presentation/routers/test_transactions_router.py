import datetime
import unittest
import uuid
from decimal import Decimal
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from infra.database.session import get_db
from presentation.app import app
from presentation.dependencies.auth import get_current_user
from tests.factories import HOUSEHOLD_ID, make_user

MODULE = "presentation.routers.transactions_router"
OTHER_HOUSEHOLD_ID = uuid.UUID("00000000-0000-0000-0000-00000000c002")
PARTNER_ID = uuid.UUID("00000000-0000-0000-0000-00000000b002")
TODAY = datetime.date(2026, 11, 13)


class PeriodEndpointsTestCase(unittest.TestCase):
    """Shared setup: logged user, fake session, `today` frozen and the three services patched."""

    today = TODAY

    def setUp(self):
        self.session = MagicMock()
        self.current_user = make_user()

        def _get_db():
            yield self.session

        app.dependency_overrides[get_db] = _get_db
        app.dependency_overrides[get_current_user] = lambda: self.current_user
        self.addCleanup(app.dependency_overrides.clear)
        self.client = TestClient(app)

        patcher = patch(f"{MODULE}.today_local", return_value=self.today)
        patcher.start()
        self.addCleanup(patcher.stop)

        self.mocks = {}
        for name in ("get_total_expenses", "get_total_revenues", "get_balance"):
            patcher = patch(f"{MODULE}.{name}", return_value=Decimal("10.50"))
            self.mocks[name] = patcher.start()
            self.addCleanup(patcher.stop)

    def filters_sent_to(self, service: str):
        return self.mocks[service].call_args.args[1]


class TotalExpensesEndpointTests(PeriodEndpointsTestCase):
    def test_answers_with_the_total_and_the_period_that_was_used(self):
        response = self.client.get(
            "/transactions/total-expenses",
            params={"date_from": "2026-11-01", "date_to": "2026-11-10"},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {"date_from": "2026-11-01", "date_to": "2026-11-10", "total": "10.50"},
        )

    def test_without_a_period_it_is_day_one_until_yesterday(self):
        response = self.client.get("/transactions/total-expenses")

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual((body["date_from"], body["date_to"]), ("2026-11-01", "2026-11-12"))
        filters = self.filters_sent_to("get_total_expenses")
        self.assertEqual(filters.date_from, datetime.datetime(2026, 11, 1, tzinfo=datetime.UTC))
        # Exclusive bound: the next midnight, so the whole day 12 is inside
        self.assertEqual(filters.date_to, datetime.datetime(2026, 11, 13, tzinfo=datetime.UTC))

    def test_the_household_comes_from_the_logged_user(self):
        self.client.get("/transactions/total-expenses")

        self.assertEqual(self.filters_sent_to("get_total_expenses").household_id, HOUSEHOLD_ID)

    def test_a_household_sent_in_the_request_is_rejected(self):
        response = self.client.get(
            "/transactions/total-expenses", params={"household_id": str(OTHER_HOUSEHOLD_ID)}
        )

        self.assertEqual(response.status_code, 422)
        self.mocks["get_total_expenses"].assert_not_called()

    def test_the_user_filter_is_optional_and_is_passed_on(self):
        self.client.get("/transactions/total-expenses")
        self.assertIsNone(self.filters_sent_to("get_total_expenses").user_id)

        self.client.get("/transactions/total-expenses", params={"user_id": str(PARTNER_ID)})
        self.assertEqual(self.filters_sent_to("get_total_expenses").user_id, PARTNER_ID)

    def test_only_one_of_the_two_dates_is_rejected(self):
        for params in ({"date_from": "2026-11-01"}, {"date_to": "2026-11-10"}):
            with self.subTest(params=params):
                response = self.client.get("/transactions/total-expenses", params=params)

                self.assertEqual(response.status_code, 422)

    def test_a_start_after_the_end_is_rejected(self):
        response = self.client.get(
            "/transactions/total-expenses",
            params={"date_from": "2026-11-10", "date_to": "2026-11-01"},
        )

        self.assertEqual(response.status_code, 422)

    def test_a_single_day_period_is_allowed(self):
        response = self.client.get(
            "/transactions/total-expenses",
            params={"date_from": "2026-11-05", "date_to": "2026-11-05"},
        )

        self.assertEqual(response.status_code, 200)

    def test_without_a_token_it_is_unauthorized(self):
        app.dependency_overrides.pop(get_current_user)

        response = self.client.get("/transactions/total-expenses")

        self.assertEqual(response.status_code, 401)


class TotalExpensesOnTheFirstDayTests(PeriodEndpointsTestCase):
    today = datetime.date(2026, 11, 1)

    def test_it_is_the_whole_previous_month(self):
        response = self.client.get("/transactions/total-expenses")

        body = response.json()
        self.assertEqual((body["date_from"], body["date_to"]), ("2026-10-01", "2026-10-31"))


class TotalRevenuesEndpointTests(PeriodEndpointsTestCase):
    def test_answers_with_the_total_of_the_revenues(self):
        response = self.client.get("/transactions/total-revenues")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["total"], "10.50")
        self.mocks["get_total_revenues"].assert_called_once()
        self.mocks["get_total_expenses"].assert_not_called()

    def test_uses_the_household_and_the_period_like_the_expenses(self):
        self.client.get(
            "/transactions/total-revenues",
            params={"date_from": "2026-11-01", "date_to": "2026-11-10", "user_id": str(PARTNER_ID)},
        )

        filters = self.filters_sent_to("get_total_revenues")
        self.assertEqual(filters.household_id, HOUSEHOLD_ID)
        self.assertEqual(filters.user_id, PARTNER_ID)
        self.assertEqual(filters.date_to, datetime.datetime(2026, 11, 11, tzinfo=datetime.UTC))


class BalanceEndpointTests(PeriodEndpointsTestCase):
    def test_answers_with_the_balance_and_the_period_that_was_used(self):
        self.mocks["get_balance"].return_value = Decimal("-35.00")

        response = self.client.get("/transactions/balance")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {"date_from": "2026-11-01", "date_to": "2026-11-12", "balance": "-35.00"},
        )

    def test_is_not_taken_as_a_transaction_id(self):
        response = self.client.get("/transactions/balance")

        self.assertNotEqual(response.status_code, 422)

    def test_uses_the_household_of_the_logged_user(self):
        self.client.get("/transactions/balance")

        self.assertEqual(self.filters_sent_to("get_balance").household_id, HOUSEHOLD_ID)


if __name__ == "__main__":
    unittest.main()
