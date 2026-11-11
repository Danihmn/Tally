import unittest
import uuid
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from infra.database.session import get_db
from presentation.app import app
from presentation.dependencies.auth import get_current_user
from services.common.exceptions import NotFoundError
from tests.factories import HOUSEHOLD_ID, make_user, utc

MODULE = "presentation.routers.users_router"


class CreateUserEndpointTests(unittest.TestCase):
    def setUp(self):
        self.session = MagicMock()

        def _get_db():
            yield self.session

        app.dependency_overrides[get_db] = _get_db
        app.dependency_overrides[get_current_user] = lambda: make_user()
        self.addCleanup(app.dependency_overrides.clear)
        self.client = TestClient(app)

        self.mocks = {}
        for name in ("get_household_by_id", "create_user", "register_webhooks"):
            patcher = patch(f"{MODULE}.{name}")
            self.mocks[name] = patcher.start()
            self.addCleanup(patcher.stop)

    def _body(self, household_id):
        return {
            "first_name": "Ana",
            "email": "Ana@Example.com",
            "password": "12345678",
            "pluggy_client_id": str(uuid.uuid4()),
            "pluggy_client_secret": "secret",
            "household_id": str(household_id),
        }

    def test_creates_the_user_in_the_given_household(self):
        self.mocks["create_user"].side_effect = lambda session, user: make_user(
            id=uuid.uuid4(), created_at=utc(2026, 11, 1), household_id=user.household_id
        )

        response = self.client.post("/users", json=self._body(HOUSEHOLD_ID))

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json()["household_id"], str(HOUSEHOLD_ID))
        saved = self.mocks["create_user"].call_args.args[1]
        self.assertEqual(saved.household_id, HOUSEHOLD_ID)

    def test_unknown_household_creates_nothing(self):
        self.mocks["get_household_by_id"].side_effect = NotFoundError()

        response = self.client.post("/users", json=self._body(uuid.uuid4()))

        self.assertEqual(response.status_code, 404)
        self.mocks["create_user"].assert_not_called()
