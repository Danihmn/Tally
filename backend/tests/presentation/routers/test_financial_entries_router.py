import datetime
import unittest
import uuid
from decimal import Decimal
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from infra.database.session import get_db
from presentation.app import app
from presentation.dependencies.auth import get_current_user
from tests.factories import HOUSEHOLD_ID, make_entry, make_user, utc

MODULE = "presentation.routers.financial_entries_router"
OTHER_HOUSEHOLD_ID = uuid.UUID("00000000-0000-0000-0000-00000000c002")


PARTNER_ID = uuid.UUID("00000000-0000-0000-0000-00000000b002")
TODAY = datetime.date(2026, 11, 13)
PLANNING_PATHS = (
    "/financial-entries/total-planned",
    "/financial-entries/total-reconciled",
    "/financial-entries/reconciliation-counts",
)


class PlanningEndpointsTestCase(unittest.TestCase):
    """Shared setup: logged user, fake session, `today` frozen and the services patched."""

    def setUp(self):
        self.session = MagicMock()
        self.current_user = make_user()

        def _get_db():
            yield self.session

        app.dependency_overrides[get_db] = _get_db
        app.dependency_overrides[get_current_user] = lambda: self.current_user
        self.addCleanup(app.dependency_overrides.clear)
        self.client = TestClient(app)

        patcher = patch(f"{MODULE}.today_local", return_value=TODAY)
        patcher.start()
        self.addCleanup(patcher.stop)

        self.mocks = {}
        for name, value in (
            ("get_total_planned", Decimal("1000.00")),
            ("get_total_reconciled", Decimal("700.50")),
            ("count_reconciled_entries", 3),
            ("count_not_reconciled_entries", 2),
            (
                "list_upcoming_entries",
                [
                    make_entry(description="Rent", amount=Decimal("1500.00"), type="EXPENSES",
                               category="Moradia", due_date=datetime.date(2026, 11, 15)),
                    make_entry(description="Salary", amount=Decimal("5000.00"), type="REVENUES",
                               due_date=datetime.date(2026, 11, 18)),
                ],
            ),
        ):
            patcher = patch(f"{MODULE}.{name}", return_value=value)
            self.mocks[name] = patcher.start()
            self.addCleanup(patcher.stop)

    def filters_sent_to(self, service: str):
        return self.mocks[service].call_args.args[1]


class TotalPlannedEndpointTests(PlanningEndpointsTestCase):
    def test_answers_with_the_total_and_the_months_that_were_used(self):
        response = self.client.get(
            "/financial-entries/total-planned",
            params={"type": "EXPENSES", "date_from": "2026-10-20", "date_to": "2026-11-05"},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                "reference_month_from": "2026-10-01",
                "reference_month_to": "2026-11-01",
                "type": "EXPENSES",
                "total": "1000.00",
            },
        )

    def test_without_dates_it_is_the_whole_current_month(self):
        response = self.client.get("/financial-entries/total-planned", params={"type": "EXPENSES"})

        body = response.json()
        self.assertEqual(
            (body["reference_month_from"], body["reference_month_to"]),
            ("2026-11-01", "2026-11-01"),
        )

    def test_any_day_of_the_month_picks_that_month(self):
        self.client.get(
            "/financial-entries/total-planned",
            params={"type": "EXPENSES", "date_from": "2026-11-01", "date_to": "2026-11-12"},
        )

        filters = self.filters_sent_to("get_total_planned")
        self.assertEqual(filters.reference_month_from, datetime.date(2026, 11, 1))
        self.assertEqual(filters.reference_month_to, datetime.date(2026, 11, 1))

    def test_the_total_is_planned_so_no_status_filter_is_sent(self):
        self.client.get("/financial-entries/total-planned", params={"type": "REVENUES"})

        self.assertIsNone(self.filters_sent_to("get_total_planned").status)


class TotalReconciledEndpointTests(PlanningEndpointsTestCase):
    def test_answers_with_the_reconciled_total(self):
        response = self.client.get(
            "/financial-entries/total-reconciled", params={"type": "REVENUES"}
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["total"], "700.50")
        self.assertEqual(response.json()["type"], "REVENUES")
        self.mocks["get_total_reconciled"].assert_called_once()
        self.mocks["get_total_planned"].assert_not_called()


class ReconciliationCountsEndpointTests(PlanningEndpointsTestCase):
    def test_answers_with_both_counts_of_the_type(self):
        response = self.client.get(
            "/financial-entries/reconciliation-counts", params={"type": "EXPENSES"}
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                "reference_month_from": "2026-11-01",
                "reference_month_to": "2026-11-01",
                "type": "EXPENSES",
                "reconciled": 3,
                "not_reconciled": 2,
            },
        )

    def test_both_counts_use_the_same_filters(self):
        self.client.get(
            "/financial-entries/reconciliation-counts", params={"type": "EXPENSES"}
        )

        self.assertEqual(
            self.filters_sent_to("count_reconciled_entries"),
            self.filters_sent_to("count_not_reconciled_entries"),
        )


class PlanningEndpointsSharedRulesTests(PlanningEndpointsTestCase):
    def test_the_type_is_required_in_every_endpoint(self):
        for path in PLANNING_PATHS:
            with self.subTest(path=path):
                self.assertEqual(self.client.get(path).status_code, 422)

    def test_an_unknown_type_is_rejected_in_every_endpoint(self):
        for path in PLANNING_PATHS:
            with self.subTest(path=path):
                response = self.client.get(path, params={"type": "DEBIT"})

                self.assertEqual(response.status_code, 422)

    def test_the_type_is_passed_to_the_filters(self):
        self.client.get("/financial-entries/total-reconciled", params={"type": "REVENUES"})

        self.assertEqual(self.filters_sent_to("get_total_reconciled").type, "REVENUES")

    def test_the_household_comes_from_the_logged_user(self):
        self.client.get("/financial-entries/total-planned", params={"type": "EXPENSES"})

        self.assertEqual(self.filters_sent_to("get_total_planned").household_id, HOUSEHOLD_ID)

    def test_a_household_sent_in_the_request_is_rejected(self):
        response = self.client.get(
            "/financial-entries/total-planned",
            params={"type": "EXPENSES", "household_id": str(uuid.uuid4())},
        )

        self.assertEqual(response.status_code, 422)
        self.mocks["get_total_planned"].assert_not_called()

    def test_the_user_filter_is_optional_and_is_passed_on(self):
        self.client.get("/financial-entries/total-planned", params={"type": "EXPENSES"})
        self.assertIsNone(self.filters_sent_to("get_total_planned").user_id)

        self.client.get(
            "/financial-entries/total-planned",
            params={"type": "EXPENSES", "user_id": str(PARTNER_ID)},
        )
        self.assertEqual(self.filters_sent_to("get_total_planned").user_id, PARTNER_ID)

    def test_only_one_of_the_two_dates_is_rejected(self):
        for params in ({"date_from": "2026-11-01"}, {"date_to": "2026-11-10"}):
            with self.subTest(params=params):
                response = self.client.get(
                    "/financial-entries/total-planned", params={"type": "EXPENSES", **params}
                )

                self.assertEqual(response.status_code, 422)

    def test_a_start_after_the_end_is_rejected(self):
        response = self.client.get(
            "/financial-entries/total-planned",
            params={"type": "EXPENSES", "date_from": "2026-11-10", "date_to": "2026-11-01"},
        )

        self.assertEqual(response.status_code, 422)

    def test_the_fixed_paths_are_not_taken_as_an_entry_id(self):
        for path in PLANNING_PATHS:
            with self.subTest(path=path):
                response = self.client.get(path, params={"type": "EXPENSES"})

                self.assertEqual(response.status_code, 200)

    def test_without_a_token_it_is_unauthorized(self):
        app.dependency_overrides.pop(get_current_user)

        for path in PLANNING_PATHS:
            with self.subTest(path=path):
                response = self.client.get(path, params={"type": "EXPENSES"})

                self.assertEqual(response.status_code, 401)


class UpcomingEntriesEndpointTests(PlanningEndpointsTestCase):
    def test_lists_the_description_the_amount_the_type_and_the_due_date(self):
        response = self.client.get("/financial-entries/upcoming", params={"days": 5})

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                "date_from": "2026-11-13",
                "date_to": "2026-11-18",
                "items": [
                    {
                        "description": "Rent",
                        "amount": "1500.00",
                        "type": "EXPENSES",
                        "category": "Moradia",
                        "due_date": "2026-11-15",
                    },
                    {
                        "description": "Salary",
                        "amount": "5000.00",
                        "type": "REVENUES",
                        "category": None,
                        "due_date": "2026-11-18",
                    },
                ],
            },
        )

    def test_an_entry_without_category_has_a_null_category(self):
        response = self.client.get("/financial-entries/upcoming")

        categories = [item["category"] for item in response.json()["items"]]
        self.assertEqual(categories, ["Moradia", None])

    def test_the_window_goes_from_today_until_today_plus_the_days(self):
        self.client.get("/financial-entries/upcoming", params={"days": 5})

        filters = self.filters_sent_to("list_upcoming_entries")
        self.assertEqual(filters.due_date_from, datetime.date(2026, 11, 13))
        self.assertEqual(filters.due_date_to, datetime.date(2026, 11, 18))

    def test_the_days_are_7_by_default(self):
        response = self.client.get("/financial-entries/upcoming")

        self.assertEqual(response.json()["date_to"], "2026-11-20")

    def test_days_out_of_range_are_rejected(self):
        for days in (0, 91, -3):
            with self.subTest(days=days):
                response = self.client.get("/financial-entries/upcoming", params={"days": days})

                self.assertEqual(response.status_code, 422)

    def test_the_type_is_not_a_filter_so_revenues_and_expenses_come_together(self):
        self.client.get("/financial-entries/upcoming")

        self.assertIsNone(self.filters_sent_to("list_upcoming_entries").type)

    def test_the_household_comes_from_the_logged_user(self):
        self.client.get("/financial-entries/upcoming")

        self.assertEqual(self.filters_sent_to("list_upcoming_entries").household_id, HOUSEHOLD_ID)

    def test_the_user_filter_is_optional_and_is_passed_on(self):
        self.client.get("/financial-entries/upcoming")
        self.assertIsNone(self.filters_sent_to("list_upcoming_entries").user_id)

        self.client.get("/financial-entries/upcoming", params={"user_id": str(PARTNER_ID)})
        self.assertEqual(self.filters_sent_to("list_upcoming_entries").user_id, PARTNER_ID)

    def test_a_household_sent_in_the_request_is_rejected(self):
        response = self.client.get(
            "/financial-entries/upcoming", params={"household_id": str(uuid.uuid4())}
        )

        self.assertEqual(response.status_code, 422)
        self.mocks["list_upcoming_entries"].assert_not_called()

    def test_is_not_taken_as_an_entry_id(self):
        self.assertEqual(self.client.get("/financial-entries/upcoming").status_code, 200)

    def test_without_a_token_it_is_unauthorized(self):
        app.dependency_overrides.pop(get_current_user)

        self.assertEqual(self.client.get("/financial-entries/upcoming").status_code, 401)



class ListFinancialEntriesEndpointTests(unittest.TestCase):
    """GET /financial-entries: the list of the Lançamentos screen."""

    def setUp(self):
        self.session = MagicMock()
        self.current_user = make_user()

        def _get_db():
            yield self.session

        app.dependency_overrides[get_db] = _get_db
        app.dependency_overrides[get_current_user] = lambda: self.current_user
        self.addCleanup(app.dependency_overrides.clear)
        self.client = TestClient(app)

        patcher = patch(f"{MODULE}.search_financial_entries")
        self.search = patcher.start()
        self.addCleanup(patcher.stop)
        self.search.return_value = ([], 0)

    def _filters(self):
        return self.search.call_args.args[1]

    def test_the_household_comes_from_the_logged_user(self):
        response = self.client.get("/financial-entries")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(self._filters().household_id, HOUSEHOLD_ID)

    def test_a_household_sent_in_the_request_is_rejected(self):
        response = self.client.get(
            "/financial-entries", params={"household_id": str(OTHER_HOUSEHOLD_ID)}
        )

        self.assertEqual(response.status_code, 422)
        self.search.assert_not_called()

    def test_every_filter_reaches_the_service(self):
        account = uuid.UUID("00000000-0000-0000-0000-00000000a001")
        transaction = uuid.UUID("00000000-0000-0000-0000-00000000b001")

        self.client.get(
            "/financial-entries",
            params={
                "user_id": str(self.current_user.id),
                "bank_account_id": str(account),
                "type": "EXPENSES",
                "payment_type": "CREDIT",
                "status": "PLANNED",
                "search": "luz",
                "reference_month_from": "2026-09-17",
                "reference_month_to": "2026-11-20",
                "due_date_from": "2026-11-01",
                "due_date_to": "2026-11-30",
                "min_amount": "10.50",
                "max_amount": "200",
                "transaction_id": str(transaction),
            },
        )

        filters = self._filters()
        self.assertEqual(filters.user_id, self.current_user.id)
        self.assertEqual(filters.bank_account_id, account)
        self.assertEqual((filters.type, filters.payment_type), ("EXPENSES", "CREDIT"))
        self.assertEqual((filters.status, filters.search), ("PLANNED", "luz"))
        # Any day of the month is moved to the first day
        self.assertEqual(filters.reference_month_from, datetime.date(2026, 9, 1))
        self.assertEqual(filters.reference_month_to, datetime.date(2026, 11, 1))
        self.assertEqual(filters.due_date_from, datetime.date(2026, 11, 1))
        self.assertEqual(filters.due_date_to, datetime.date(2026, 11, 30))
        self.assertEqual(
            (filters.min_amount, filters.max_amount), (Decimal("10.50"), Decimal("200"))
        )
        self.assertEqual(filters.transaction_id, transaction)

    def test_without_filters_only_the_household_is_set(self):
        self.client.get("/financial-entries")

        filters = self._filters()
        self.assertIsNone(filters.transaction_id)
        self.assertIsNone(filters.status)
        self.assertIsNone(filters.user_id)

    def test_the_page_has_the_items_the_total_and_the_paging(self):
        self.search.return_value = ([make_entry(created_at=utc(2026, 11, 1))], 41)

        body = self.client.get(
            "/financial-entries", params={"limit": 30, "offset": 30}
        ).json()

        self.assertEqual((body["total"], body["limit"], body["offset"]), (41, 30, 30))
        self.assertEqual(len(body["items"]), 1)
        self.assertEqual(self.search.call_args.kwargs, {"limit": 30, "offset": 30})

    def test_dates_out_of_order_are_rejected(self):
        response = self.client.get(
            "/financial-entries",
            params={"due_date_from": "2026-11-10", "due_date_to": "2026-11-01"},
        )

        self.assertEqual(response.status_code, 422)

    def test_without_a_token_it_is_unauthorized(self):
        app.dependency_overrides.pop(get_current_user)

        self.assertEqual(self.client.get("/financial-entries").status_code, 401)
