import datetime
import unittest
import uuid
from decimal import Decimal
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from infra.database.session import get_db
from presentation.app import app
from presentation.dependencies.auth import get_current_user
from domain.read_models import DailyTotal, TopExpense, TransactionWithOwner
from tests.factories import HOUSEHOLD_ID, make_transaction, make_user, utc

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
        for name, value in (
            (
                "get_top_expenses",
                [
                    TopExpense(datetime.date(2026, 11, 10), "Rent", Decimal("1500.00")),
                    TopExpense(datetime.date(2026, 11, 3), None, Decimal("20.50")),
                ],
            ),
            (
                "get_daily_expenses",
                [
                    DailyTotal(datetime.date(2026, 11, 1), Decimal("0.00")),
                    DailyTotal(datetime.date(2026, 11, 2), Decimal("99.90")),
                ],
            ),
            ("get_average_daily_expenses", Decimal("49.95")),
        ):
            patcher = patch(f"{MODULE}.{name}", return_value=value)
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



class TopExpensesEndpointTests(PeriodEndpointsTestCase):
    def test_lists_only_the_date_the_amount_and_the_description(self):
        response = self.client.get("/transactions/top-expenses")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                "date_from": "2026-11-01",
                "date_to": "2026-11-12",
                "items": [
                    {"date": "2026-11-10", "amount": "1500.00", "description": "Rent"},
                    {"date": "2026-11-03", "amount": "20.50", "description": None},
                ],
            },
        )

    def test_the_limit_is_5_by_default_and_can_be_changed(self):
        self.client.get("/transactions/top-expenses")
        self.assertEqual(self.mocks["get_top_expenses"].call_args.args[2], 5)

        self.client.get("/transactions/top-expenses", params={"limit": 12})
        self.assertEqual(self.mocks["get_top_expenses"].call_args.args[2], 12)

    def test_a_limit_out_of_range_is_rejected(self):
        for limit in (0, 51, -1):
            with self.subTest(limit=limit):
                response = self.client.get("/transactions/top-expenses", params={"limit": limit})

                self.assertEqual(response.status_code, 422)

    def test_uses_the_same_period_and_household_rules_as_the_totals(self):
        self.client.get(
            "/transactions/top-expenses",
            params={"date_from": "2026-11-01", "date_to": "2026-11-10", "user_id": str(PARTNER_ID)},
        )

        filters = self.filters_sent_to("get_top_expenses")
        self.assertEqual(filters.household_id, HOUSEHOLD_ID)
        self.assertEqual(filters.user_id, PARTNER_ID)
        self.assertEqual(filters.date_to, datetime.datetime(2026, 11, 11, tzinfo=datetime.UTC))

    def test_only_one_of_the_two_dates_is_rejected(self):
        response = self.client.get("/transactions/top-expenses", params={"date_from": "2026-11-01"})

        self.assertEqual(response.status_code, 422)

    def test_a_household_sent_in_the_request_is_rejected(self):
        response = self.client.get(
            "/transactions/top-expenses", params={"household_id": str(uuid.uuid4())}
        )

        self.assertEqual(response.status_code, 422)

    def test_without_a_token_it_is_unauthorized(self):
        app.dependency_overrides.pop(get_current_user)

        self.assertEqual(self.client.get("/transactions/top-expenses").status_code, 401)


class DailyExpensesEndpointTests(PeriodEndpointsTestCase):
    def test_answers_with_one_item_per_day(self):
        response = self.client.get("/transactions/daily-expenses")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                "date_from": "2026-11-01",
                "date_to": "2026-11-12",
                "items": [
                    {"date": "2026-11-01", "total": "0.00"},
                    {"date": "2026-11-02", "total": "99.90"},
                ],
            },
        )

    def test_uses_the_household_of_the_logged_user_and_the_period(self):
        self.client.get(
            "/transactions/daily-expenses",
            params={"date_from": "2026-11-01", "date_to": "2026-11-10"},
        )

        filters = self.filters_sent_to("get_daily_expenses")
        self.assertEqual(filters.household_id, HOUSEHOLD_ID)
        self.assertEqual(filters.date_from, datetime.datetime(2026, 11, 1, tzinfo=datetime.UTC))
        self.assertEqual(filters.date_to, datetime.datetime(2026, 11, 11, tzinfo=datetime.UTC))

    def test_a_start_after_the_end_is_rejected(self):
        response = self.client.get(
            "/transactions/daily-expenses",
            params={"date_from": "2026-11-10", "date_to": "2026-11-01"},
        )

        self.assertEqual(response.status_code, 422)

    def test_is_not_taken_as_a_transaction_id(self):
        self.assertEqual(self.client.get("/transactions/daily-expenses").status_code, 200)


class AverageDailyExpensesEndpointTests(PeriodEndpointsTestCase):
    def test_answers_with_the_average_and_the_period_that_was_used(self):
        response = self.client.get("/transactions/average-daily-expenses")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {"date_from": "2026-11-01", "date_to": "2026-11-12", "average": "49.95"},
        )

    def test_uses_the_household_of_the_logged_user(self):
        self.client.get("/transactions/average-daily-expenses")

        self.assertEqual(
            self.filters_sent_to("get_average_daily_expenses").household_id, HOUSEHOLD_ID
        )

    def test_is_not_taken_as_a_transaction_id(self):
        self.assertEqual(self.client.get("/transactions/average-daily-expenses").status_code, 200)


class ListTransactionsEndpointTests(unittest.TestCase):
    """GET /transactions: the list of the Transactions screen."""

    OWNER_ID = PARTNER_ID

    def setUp(self):
        self.session = MagicMock()
        self.current_user = make_user()

        def _get_db():
            yield self.session

        app.dependency_overrides[get_db] = _get_db
        app.dependency_overrides[get_current_user] = lambda: self.current_user
        self.addCleanup(app.dependency_overrides.clear)
        self.client = TestClient(app)

        patcher = patch(f"{MODULE}.search_transactions")
        self.search = patcher.start()
        self.addCleanup(patcher.stop)
        self.search.return_value = ([], 0)

    def _filters(self):
        return self.search.call_args.args[1]

    def test_the_household_comes_from_the_logged_user(self):
        response = self.client.get("/transactions")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(self._filters().household_id, HOUSEHOLD_ID)

    def test_a_household_sent_in_the_request_is_rejected(self):
        response = self.client.get(
            "/transactions", params={"household_id": str(OTHER_HOUSEHOLD_ID)}
        )

        self.assertEqual(response.status_code, 422)
        self.search.assert_not_called()

    def test_every_filter_reaches_the_service(self):
        account = uuid.UUID("00000000-0000-0000-0000-00000000a001")

        self.client.get(
            "/transactions",
            params={
                "user_id": str(PARTNER_ID),
                "bank_account_id": str(account),
                "date_from": "2026-11-01",
                "date_to": "2026-11-12",
                "type": "DEBIT",
                "status": "PENDING",
                "category": "Groceries",
                "search": "mercado",
                "min_amount": "10.50",
                "max_amount": "200",
            },
        )

        filters = self._filters()
        self.assertEqual(filters.user_id, PARTNER_ID)
        self.assertEqual(filters.bank_account_id, account)
        self.assertEqual((filters.type, filters.status), ("DEBIT", "PENDING"))
        self.assertEqual((filters.category, filters.search), ("Groceries", "mercado"))
        self.assertEqual((filters.min_amount, filters.max_amount), (Decimal("10.50"), Decimal("200")))

    def test_the_period_is_whole_utc_days_with_both_ends_inclusive(self):
        self.client.get(
            "/transactions", params={"date_from": "2026-11-01", "date_to": "2026-11-12"}
        )

        filters = self._filters()
        self.assertEqual(filters.date_from, datetime.datetime(2026, 11, 1, tzinfo=datetime.UTC))
        # Exclusive bound: the next midnight, so the whole day 12 is inside
        self.assertEqual(filters.date_to, datetime.datetime(2026, 11, 13, tzinfo=datetime.UTC))

    def test_without_filters_only_the_household_is_set(self):
        self.client.get("/transactions")

        filters = self._filters()
        self.assertIsNone(filters.user_id)
        self.assertIsNone(filters.date_from)
        self.assertIsNone(filters.type)

    def test_the_page_is_50_from_the_start_by_default(self):
        self.client.get("/transactions")

        self.assertEqual(self.search.call_args.kwargs, {"limit": 50, "offset": 0})

    def test_limit_and_offset_are_passed_on(self):
        self.client.get("/transactions", params={"limit": 30, "offset": 60})

        self.assertEqual(self.search.call_args.kwargs, {"limit": 30, "offset": 60})

    def test_a_limit_out_of_range_is_rejected(self):
        for limit in (0, 201):
            with self.subTest(limit=limit):
                response = self.client.get("/transactions", params={"limit": limit})

                self.assertEqual(response.status_code, 422)

    def test_a_start_after_the_end_is_rejected(self):
        response = self.client.get(
            "/transactions", params={"date_from": "2026-11-10", "date_to": "2026-11-01"}
        )

        self.assertEqual(response.status_code, 422)

    def test_a_minimum_above_the_maximum_is_rejected(self):
        response = self.client.get(
            "/transactions", params={"min_amount": "50", "max_amount": "10"}
        )

        self.assertEqual(response.status_code, 422)

    def test_an_unknown_type_or_status_is_rejected(self):
        for params in ({"type": "TRANSFER"}, {"status": "DONE"}):
            with self.subTest(params=params):
                self.assertEqual(self.client.get("/transactions", params=params).status_code, 422)

    def test_answers_with_the_page_and_the_owner_of_each_transaction(self):
        transaction = make_transaction(
            date=utc(2026, 11, 5, 0),
            amount=Decimal("-120.50"),
            description="Mercado",
            category="Groceries",
            category_id="10000000",
            merchant={"name": "Pão de Açúcar"},
            balance=Decimal("900.00"),
        )
        self.search.return_value = (
            [TransactionWithOwner(transaction=transaction, user_id=self.OWNER_ID)],
            75,
        )

        response = self.client.get("/transactions", params={"limit": 30, "offset": 30})

        body = response.json()
        self.assertEqual((body["total"], body["limit"], body["offset"]), (75, 30, 30))
        item = body["items"][0]
        self.assertEqual(item["user_id"], str(self.OWNER_ID))
        self.assertEqual(item["id"], str(transaction.id))
        self.assertEqual(item["bank_account_id"], str(transaction.bank_account_id))
        self.assertEqual(item["description"], "Mercado")
        self.assertEqual(item["amount"], "-120.50")
        self.assertEqual((item["type"], item["status"]), ("DEBIT", "POSTED"))
        self.assertEqual((item["category"], item["category_id"]), ("Groceries", "10000000"))
        self.assertEqual(item["merchant"], {"name": "Pão de Açúcar"})
        self.assertEqual(item["balance"], "900.00")
        self.assertTrue(item["date"].startswith("2026-11-05T00:00:00"))

    def test_the_payment_data_is_never_in_the_answer(self):
        transaction = make_transaction(payment_data={"payer": {"documentNumber": "123"}})
        self.search.return_value = (
            [TransactionWithOwner(transaction=transaction, user_id=self.OWNER_ID)],
            1,
        )

        item = self.client.get("/transactions").json()["items"][0]

        self.assertNotIn("payment_data", item)

    def test_without_a_token_it_is_unauthorized(self):
        app.dependency_overrides.pop(get_current_user)

        self.assertEqual(self.client.get("/transactions").status_code, 401)


if __name__ == "__main__":
    unittest.main()
