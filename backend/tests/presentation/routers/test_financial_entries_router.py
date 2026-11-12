import unittest
import uuid
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from infra.database.session import get_db
from presentation.app import app
from presentation.dependencies.auth import get_current_user
from tests.factories import make_entry, make_user, utc

MODULE = "presentation.routers.financial_entries_router"
OTHER_HOUSEHOLD_ID = uuid.UUID("00000000-0000-0000-0000-00000000c002")


class CreateFinancialEntryEndpointTests(unittest.TestCase):
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
        for name in ("create_financial_entry", "get_user_by_id"):
            patcher = patch(f"{MODULE}.{name}")
            self.mocks[name] = patcher.start()
            self.addCleanup(patcher.stop)
        self.mocks["create_financial_entry"].side_effect = lambda session, entry: make_entry(
            created_at=utc(2026, 11, 1), household_id=entry.household_id, user_id=entry.user_id
        )

    def _body(self, **extra):
        return {
            "description": "Rent",
            "type": "EXPENSES",
            "amount": "1000.00",
            "reference_month": "2026-11-15",
            **extra,
        }

    def test_the_entry_belongs_to_the_household_of_the_logged_user(self):
        response = self.client.post("/financial-entries", json=self._body())

        self.assertEqual(response.status_code, 201)
        saved = self.mocks["create_financial_entry"].call_args.args[1]
        self.assertEqual(saved.household_id, self.current_user.household_id)

    def test_entry_for_a_user_of_the_same_household_is_allowed(self):
        partner = make_user(id=uuid.uuid4())
        self.mocks["get_user_by_id"].return_value = partner

        response = self.client.post(
            "/financial-entries", json=self._body(user_id=str(partner.id))
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(
            self.mocks["create_financial_entry"].call_args.args[1].user_id, partner.id
        )

    def test_entry_for_a_user_of_another_household_is_not_found(self):
        stranger = make_user(id=uuid.uuid4(), household_id=OTHER_HOUSEHOLD_ID)
        self.mocks["get_user_by_id"].return_value = stranger

        response = self.client.post(
            "/financial-entries", json=self._body(user_id=str(stranger.id))
        )

        self.assertEqual(response.status_code, 404)
        self.mocks["create_financial_entry"].assert_not_called()

    def test_response_has_the_recurrence_of_the_entry(self):
        recurrence_id = uuid.uuid4()
        self.mocks["create_financial_entry"].side_effect = lambda session, entry: make_entry(
            created_at=utc(2026, 11, 1), recurrence_id=recurrence_id
        )

        response = self.client.post("/financial-entries", json=self._body())

        self.assertEqual(response.json()["recurrence_id"], str(recurrence_id))

    def test_entry_created_by_hand_has_no_recurrence(self):
        response = self.client.post("/financial-entries", json=self._body())

        self.assertIsNone(response.json()["recurrence_id"])
        self.assertIsNone(
            self.mocks["create_financial_entry"].call_args.args[1].recurrence_id
        )
