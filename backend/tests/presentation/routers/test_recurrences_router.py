import datetime
import unittest
import uuid
from decimal import Decimal
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from domain.read_models import ProvisionResult
from infra.database.session import get_db
from presentation.app import app
from presentation.dependencies.auth import get_current_user
from services.common.exceptions import InvalidDataError, NoRecurrencesError, NotFoundError
from tests.factories import HOUSEHOLD_ID, make_recurrence, make_user, utc

MODULE = "presentation.routers.recurrences_router"
TODAY = datetime.date(2026, 11, 15)
BODY = {"description": "Rent", "type": "EXPENSES", "amount": "1500.00", "due_day": 5}


class RecurrencesEndpointTestCase(unittest.TestCase):
    """Shared setup: logged user, fake session and a patched service."""

    SERVICE: str

    def setUp(self):
        self.session = MagicMock()
        self.current_user = make_user()

        def _get_db():
            yield self.session

        app.dependency_overrides[get_db] = _get_db
        app.dependency_overrides[get_current_user] = lambda: self.current_user
        self.addCleanup(app.dependency_overrides.clear)
        self.client = TestClient(app)
        patcher = patch(f"{MODULE}.{self.SERVICE}")
        self.service = patcher.start()
        self.addCleanup(patcher.stop)


def _stored(**overrides):
    return make_recurrence(created_at=utc(2026, 11, 13), **overrides)


class ListRecurrencesEndpointTests(RecurrencesEndpointTestCase):
    SERVICE = "search_recurrences"

    def test_answers_with_a_page(self):
        self.service.return_value = ([_stored(), _stored()], 5)

        response = self.client.get("/recurrences", params={"limit": 2, "offset": 2})

        body = response.json()
        self.assertEqual(response.status_code, 200)
        self.assertEqual((len(body["items"]), body["total"], body["limit"], body["offset"]), (2, 5, 2, 2))

    def test_the_household_comes_from_the_logged_user(self):
        self.service.return_value = ([], 0)

        self.client.get("/recurrences", params={"type": "EXPENSES", "search": "ren"})

        filters = self.service.call_args.args[1]
        self.assertEqual((filters.household_id, filters.type, filters.search), (HOUSEHOLD_ID, "EXPENSES", "ren"))

    def test_household_in_the_query_is_rejected(self):
        response = self.client.get("/recurrences", params={"household_id": str(uuid.uuid4())})

        self.assertEqual(response.status_code, 422)
        self.service.assert_not_called()

    def test_without_a_token_it_is_unauthorized(self):
        app.dependency_overrides.pop(get_current_user)

        self.assertEqual(self.client.get("/recurrences").status_code, 401)


class CreateRecurrenceEndpointTests(RecurrencesEndpointTestCase):
    SERVICE = "create_recurrence"

    def setUp(self):
        super().setUp()
        self.service.side_effect = lambda session, r: _stored(
            description=r.description, amount=r.amount, due_day=r.due_day
        )

    def test_creates_the_recurrence_and_commits(self):
        response = self.client.post("/recurrences", json=BODY)

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json()["description"], "Rent")
        self.session.commit.assert_called_once()

    def test_owner_household_and_source_are_not_taken_from_the_body(self):
        self.client.post("/recurrences", json=BODY)

        recurrence = self.service.call_args.args[1]
        self.assertEqual(recurrence.user_id, self.current_user.id)
        self.assertEqual(recurrence.household_id, HOUSEHOLD_ID)
        self.assertEqual(recurrence.source, "MANUAL")
        for field in ("household_id", "user_id", "source"):
            response = self.client.post("/recurrences", json={**BODY, field: "AI"})
            self.assertEqual(response.status_code, 422, field)

    def test_invalid_bodies_are_422_without_calling_the_service(self):
        self.service.reset_mock()
        for change in (
            {"amount": "0"},
            {"amount": "-1"},
            {"due_day": 0},
            {"due_day": 32},
            {"type": "OTHER"},
            {"payment_type": "PIX"},
            {"description": " "},
        ):
            response = self.client.post("/recurrences", json={**BODY, **change})
            self.assertEqual(response.status_code, 422, change)
        self.service.assert_not_called()
        self.session.commit.assert_not_called()

    def test_days_29_to_31_are_accepted(self):
        for day in (29, 30, 31):
            self.assertEqual(self.client.post("/recurrences", json={**BODY, "due_day": day}).status_code, 201)


class GetRecurrenceEndpointTests(RecurrencesEndpointTestCase):
    SERVICE = "get_recurrence"

    def test_answers_with_the_recurrence_of_the_household(self):
        recurrence = _stored()
        self.service.return_value = recurrence

        response = self.client.get(f"/recurrences/{recurrence.id}")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(self.service.call_args.args[1:], (HOUSEHOLD_ID, recurrence.id))

    def test_unknown_recurrence_is_404(self):
        self.service.side_effect = NotFoundError("x")

        self.assertEqual(self.client.get(f"/recurrences/{uuid.uuid4()}").status_code, 404)


class UpdateRecurrenceEndpointTests(RecurrencesEndpointTestCase):
    SERVICE = "update_recurrence"

    def setUp(self):
        super().setUp()
        self.recurrence_id = uuid.uuid4()
        self.service.return_value = _stored(id=self.recurrence_id, amount=Decimal("1600.00"))

    def test_sends_only_the_fields_of_the_body_and_commits(self):
        response = self.client.patch(f"/recurrences/{self.recurrence_id}", json={"amount": "1600.00"})

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            self.service.call_args.args[1:],
            (HOUSEHOLD_ID, self.recurrence_id, {"amount": Decimal("1600.00")}),
        )
        self.session.commit.assert_called_once()

    def test_an_optional_field_can_be_cleared_with_null(self):
        self.client.patch(f"/recurrences/{self.recurrence_id}", json={"due_day": None})

        self.assertEqual(self.service.call_args.args[3], {"due_day": None})

    def test_bad_bodies_are_422_without_calling_the_service(self):
        for body in ({}, {"amount": None}, {"description": None}, {"due_day": 40}, {"source": "AI"}):
            response = self.client.patch(f"/recurrences/{self.recurrence_id}", json=body)
            self.assertEqual(response.status_code, 422, body)
        self.service.assert_not_called()

    def test_not_found_is_404_and_does_not_commit(self):
        self.service.side_effect = NotFoundError("x")

        response = self.client.patch(f"/recurrences/{self.recurrence_id}", json={"notes": "x"})

        self.assertEqual(response.status_code, 404)
        self.session.commit.assert_not_called()


class DeleteRecurrenceEndpointTests(RecurrencesEndpointTestCase):
    SERVICE = "delete_recurrence"

    def test_deletes_commits_and_answers_with_no_content(self):
        recurrence_id = uuid.uuid4()

        response = self.client.delete(f"/recurrences/{recurrence_id}")

        self.assertEqual(response.status_code, 204)
        self.assertEqual(self.service.call_args.args[1:], (HOUSEHOLD_ID, recurrence_id))
        self.session.commit.assert_called_once()

    def test_unknown_recurrence_is_404(self):
        self.service.side_effect = NotFoundError("x")

        self.assertEqual(self.client.delete(f"/recurrences/{uuid.uuid4()}").status_code, 404)


class ProvisionEndpointTests(RecurrencesEndpointTestCase):
    SERVICE = "provision_next_month"

    def setUp(self):
        super().setUp()
        patcher = patch(f"{MODULE}.today_local", return_value=TODAY)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.service.return_value = ProvisionResult(
            reference_month=datetime.date(2026, 12, 1), created=3, skipped=1
        )

    def test_answers_with_the_month_and_the_counts_and_commits(self):
        response = self.client.post("/recurrences/provision")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {"reference_month": "2026-12-01", "created": 3, "skipped": 1},
        )
        self.session.commit.assert_called_once()

    def test_uses_the_household_and_user_of_the_login_and_today(self):
        self.client.post("/recurrences/provision")

        self.assertEqual(
            self.service.call_args.args[1:],
            (HOUSEHOLD_ID, self.current_user.id, TODAY),
        )

    def test_without_recurrences_it_is_422_with_a_code_for_the_app_and_does_not_commit(self):
        self.service.side_effect = NoRecurrencesError("x")

        response = self.client.post("/recurrences/provision")

        self.assertEqual(response.status_code, 422)
        self.assertEqual(response.json()["code"], "NO_RECURRENCES")
        self.session.commit.assert_not_called()

    def test_other_invalid_data_has_no_code(self):
        self.service.side_effect = InvalidDataError("x")

        response = self.client.post("/recurrences/provision")

        self.assertEqual(response.status_code, 422)
        self.assertNotIn("code", response.json())

    def test_without_a_token_it_is_unauthorized(self):
        app.dependency_overrides.pop(get_current_user)

        self.assertEqual(self.client.post("/recurrences/provision").status_code, 401)
