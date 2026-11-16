import unittest
import uuid
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from infra.database.session import get_db
from presentation.app import app
from presentation.dependencies.auth import get_current_user
from services.common.exceptions import AlreadyExistsError, InvalidDataError, NotFoundError
from tests.factories import HOUSEHOLD_ID, make_user

MODULE = "presentation.routers.reconciliations_router"


class ReconciliationsEndpointTestCase(unittest.TestCase):
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
        self.transaction_id = uuid.uuid4()
        self.entry_id = uuid.uuid4()
        self.path = f"/transactions/{self.transaction_id}/financial-entries/{self.entry_id}"


class LinkEntryEndpointTests(ReconciliationsEndpointTestCase):
    SERVICE = "link_entry"

    def test_links_in_the_household_of_the_login_and_commits(self):
        response = self.client.post(self.path)

        self.assertEqual(response.status_code, 204)
        self.assertEqual(
            self.service.call_args.args[1:],
            (HOUSEHOLD_ID, self.transaction_id, self.entry_id),
        )
        self.session.commit.assert_called_once()

    def test_service_errors_become_their_status_without_commit(self):
        for error, expected in (
            (NotFoundError("x"), 404),
            (AlreadyExistsError("x"), 409),
            (InvalidDataError("x"), 422),
        ):
            self.service.side_effect = error
            self.assertEqual(self.client.post(self.path).status_code, expected)
        self.session.commit.assert_not_called()

    def test_ids_that_are_not_uuids_are_422(self):
        response = self.client.post("/transactions/x/financial-entries/y")

        self.assertEqual(response.status_code, 422)
        self.service.assert_not_called()

    def test_without_a_token_it_is_unauthorized(self):
        app.dependency_overrides.pop(get_current_user)

        self.assertEqual(self.client.post(self.path).status_code, 401)


class UnlinkEntryEndpointTests(ReconciliationsEndpointTestCase):
    SERVICE = "unlink_entry"

    def test_unlinks_in_the_household_of_the_login_and_commits(self):
        response = self.client.delete(self.path)

        self.assertEqual(response.status_code, 204)
        self.assertEqual(
            self.service.call_args.args[1:],
            (HOUSEHOLD_ID, self.transaction_id, self.entry_id),
        )
        self.session.commit.assert_called_once()

    def test_a_pair_that_is_not_linked_is_404_without_commit(self):
        self.service.side_effect = NotFoundError("x")

        self.assertEqual(self.client.delete(self.path).status_code, 404)
        self.session.commit.assert_not_called()

    def test_without_a_token_it_is_unauthorized(self):
        app.dependency_overrides.pop(get_current_user)

        self.assertEqual(self.client.delete(self.path).status_code, 401)
