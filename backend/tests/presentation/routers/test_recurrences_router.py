import datetime
import types
import unittest
import uuid
from decimal import Decimal
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from domain.read_models import ProvisioningResult
from infra.database.session import get_db
from presentation.app import app
from presentation.dependencies.auth import get_current_user
from tests.factories import make_entry, make_recurrence, make_user, utc

MODULE = "presentation.routers.recurrences_router"
OTHER_HOUSEHOLD_ID = uuid.UUID("00000000-0000-0000-0000-00000000c002")


def _frozen_datetime_module(now: datetime.datetime) -> types.SimpleNamespace:
    """The `datetime` module as the router sees it, with `datetime.now()` frozen."""

    class FrozenDatetime(datetime.datetime):
        @classmethod
        def now(cls, tz=None):
            return now

    return types.SimpleNamespace(
        datetime=FrozenDatetime, date=datetime.date, UTC=datetime.UTC
    )


class _RouterTestCase(unittest.TestCase):
    patched: tuple[str, ...] = ()

    def setUp(self):
        self.session = MagicMock()
        self.current_user = make_user()

        def _get_db():
            yield self.session

        app.dependency_overrides[get_db] = _get_db
        app.dependency_overrides[get_current_user] = lambda: self.current_user
        self.addCleanup(app.dependency_overrides.clear)
        self.client = TestClient(app)

        self.mocks = {}
        for name in self.patched:
            patcher = patch(f"{MODULE}.{name}")
            self.mocks[name] = patcher.start()
            self.addCleanup(patcher.stop)


class ProvisionRecurrencesEndpointTests(_RouterTestCase):
    patched = ("provision_entries_from_recurrences",)

    def setUp(self):
        super().setUp()
        self.mocks["provision_entries_from_recurrences"].side_effect = (
            lambda session, household_id, month, fallback_user_id: ProvisioningResult(
                reference_month=month
            )
        )

    def _month_sent_to_the_service(self):
        return self.mocks["provision_entries_from_recurrences"].call_args.args[2]

    def test_without_body_uses_the_current_month(self):
        frozen = _frozen_datetime_module(
            datetime.datetime(2026, 11, 12, tzinfo=datetime.UTC)
        )
        with patch(f"{MODULE}.datetime", frozen):
            response = self.client.post("/recurrences/provision")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(self._month_sent_to_the_service(), datetime.date(2026, 11, 1))
        self.assertEqual(response.json()["reference_month"], "2026-11-01")

    def test_empty_body_uses_the_current_month(self):
        frozen = _frozen_datetime_module(
            datetime.datetime(2026, 12, 31, tzinfo=datetime.UTC)
        )
        with patch(f"{MODULE}.datetime", frozen):
            response = self.client.post("/recurrences/provision", json={})

        self.assertEqual(response.status_code, 200)
        self.assertEqual(self._month_sent_to_the_service(), datetime.date(2026, 12, 1))

    def test_any_day_of_the_month_is_moved_to_the_first_day(self):
        response = self.client.post(
            "/recurrences/provision", json={"reference_month": "2027-01-20"}
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(self._month_sent_to_the_service(), datetime.date(2027, 1, 1))

    def test_provisions_the_household_of_the_logged_user_and_commits(self):
        self.client.post(
            "/recurrences/provision", json={"reference_month": "2026-11-01"}
        )

        call = self.mocks["provision_entries_from_recurrences"].call_args
        self.assertEqual(call.args[1], self.current_user.household_id)
        self.assertEqual(call.kwargs["fallback_user_id"], self.current_user.id)
        self.session.commit.assert_called_once()

    def test_returns_the_created_entries_and_the_skipped_count(self):
        recurrence_id = uuid.uuid4()
        created = make_entry(
            created_at=utc(2026, 11, 12),
            recurrence_id=recurrence_id,
            description="Rent",
            amount=Decimal("1500.00"),
        )
        self.mocks["provision_entries_from_recurrences"].side_effect = None
        self.mocks[
            "provision_entries_from_recurrences"
        ].return_value = ProvisioningResult(
            reference_month=datetime.date(2026, 11, 1),
            created=[created],
            skipped_count=2,
        )

        response = self.client.post(
            "/recurrences/provision", json={"reference_month": "2026-11-01"}
        )

        body = response.json()
        self.assertEqual(body["skipped_count"], 2)
        self.assertEqual(len(body["created"]), 1)
        self.assertEqual(body["created"][0]["recurrence_id"], str(recurrence_id))
        self.assertEqual(body["created"][0]["description"], "Rent")
        self.assertEqual(body["created"][0]["status"], "PLANNED")

    def test_unknown_field_is_rejected(self):
        response = self.client.post("/recurrences/provision", json={"month": "2026-11"})

        self.assertEqual(response.status_code, 422)
        self.mocks["provision_entries_from_recurrences"].assert_not_called()


class CreateRecurrenceEndpointTests(_RouterTestCase):
    patched = ("create_recurrence", "get_user_by_id")

    def setUp(self):
        super().setUp()
        self.mocks["create_recurrence"].side_effect = lambda session, r: (
            make_recurrence(
                created_at=utc(2026, 11, 1),
                household_id=r.household_id,
                user_id=r.user_id,
                description=r.description,
                due_day=r.due_day,
                notes=r.notes,
                source=r.source,
            )
        )

    def _body(self, **extra):
        return {
            "description": "Rent",
            "type": "EXPENSES",
            "amount": "1500.00",
            **extra,
        }

    def _saved(self):
        return self.mocks["create_recurrence"].call_args.args[1]

    def test_recurrence_belongs_to_the_household_of_the_logged_user(self):
        response = self.client.post("/recurrences", json=self._body())

        self.assertEqual(response.status_code, 201)
        self.assertEqual(self._saved().household_id, self.current_user.household_id)
        self.assertEqual(self._saved().user_id, self.current_user.id)

    def test_recurrence_created_by_the_endpoint_is_manual(self):
        response = self.client.post("/recurrences", json=self._body())

        self.assertEqual(self._saved().source, "MANUAL")
        self.assertEqual(response.json()["source"], "MANUAL")

    def test_source_cannot_be_sent_in_the_body(self):
        response = self.client.post("/recurrences", json=self._body(source="AI"))

        self.assertEqual(response.status_code, 422)
        self.mocks["create_recurrence"].assert_not_called()

    def test_saves_description_notes_and_due_day(self):
        response = self.client.post(
            "/recurrences", json=self._body(notes="Apartment", due_day=10)
        )

        saved = self._saved()
        self.assertEqual(
            (saved.description, saved.notes, saved.due_day), ("Rent", "Apartment", 10)
        )
        body = response.json()
        self.assertEqual((body["notes"], body["due_day"]), ("Apartment", 10))

    def test_description_is_required(self):
        body = self._body()
        del body["description"]

        response = self.client.post("/recurrences", json=body)

        self.assertEqual(response.status_code, 422)

    def test_due_day_out_of_range_is_rejected(self):
        for due_day in (0, 32):
            with self.subTest(due_day=due_day):
                response = self.client.post(
                    "/recurrences", json=self._body(due_day=due_day)
                )
                self.assertEqual(response.status_code, 422)

    def test_recurrence_for_a_user_of_the_same_household_is_allowed(self):
        partner = make_user(id=uuid.uuid4())
        self.mocks["get_user_by_id"].return_value = partner

        response = self.client.post(
            "/recurrences", json=self._body(user_id=str(partner.id))
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(self._saved().user_id, partner.id)

    def test_recurrence_for_a_user_of_another_household_is_not_found(self):
        stranger = make_user(id=uuid.uuid4(), household_id=OTHER_HOUSEHOLD_ID)
        self.mocks["get_user_by_id"].return_value = stranger

        response = self.client.post(
            "/recurrences", json=self._body(user_id=str(stranger.id))
        )

        self.assertEqual(response.status_code, 404)
        self.mocks["create_recurrence"].assert_not_called()


class ListRecurrencesEndpointTests(_RouterTestCase):
    patched = ("search_recurrences",)

    def test_lists_only_the_household_of_the_logged_user(self):
        self.mocks["search_recurrences"].return_value = (
            [make_recurrence(created_at=utc(2026, 11, 1))],
            1,
        )

        response = self.client.get("/recurrences")

        self.assertEqual(response.status_code, 200)
        filters = self.mocks["search_recurrences"].call_args.args[1]
        self.assertEqual(filters.household_id, self.current_user.household_id)
        self.assertEqual(response.json()["total"], 1)


class GetRecurrenceEndpointTests(_RouterTestCase):
    patched = ("get_recurrence_by_id",)

    def test_recurrence_of_the_household_is_returned(self):
        recurrence = make_recurrence(created_at=utc(2026, 11, 1))
        self.mocks["get_recurrence_by_id"].return_value = recurrence

        response = self.client.get(f"/recurrences/{recurrence.id}")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["id"], str(recurrence.id))

    def test_recurrence_of_another_household_is_not_found(self):
        recurrence = make_recurrence(
            created_at=utc(2026, 11, 1), household_id=OTHER_HOUSEHOLD_ID
        )
        self.mocks["get_recurrence_by_id"].return_value = recurrence

        response = self.client.get(f"/recurrences/{recurrence.id}")

        self.assertEqual(response.status_code, 404)


if __name__ == "__main__":
    unittest.main()
