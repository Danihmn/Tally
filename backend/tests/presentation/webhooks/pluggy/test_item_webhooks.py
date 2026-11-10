import unittest
import uuid
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from infra.database.session import get_db
from infra.security.webhook_secret import hash_webhook_secret
from integrations.pluggy.config import (
    item_created_webhook_path,
    item_deleted_webhook_path,
    item_updated_webhook_path,
    webhook_token_header,
)
from presentation.app import app
from tests.factories import make_pluggy_item, make_user, utc

MODULE = "presentation.webhooks.pluggy.item_webhooks"
TOKEN = "webhook-secret"


class ItemWebhooksTests(unittest.TestCase):
    def setUp(self):
        self.session = MagicMock()
        self.user = make_user()

        def _get_db():
            yield self.session

        app.dependency_overrides[get_db] = _get_db
        self.addCleanup(app.dependency_overrides.clear)
        # Not used as a context manager: the lifespan (webhook registration) does not run
        self.client = TestClient(app)

        self.mocks = {}
        for name in (
            "get_user_by_webhook_secret_hash",
            "get_pluggy_item_by_pluggy_item_id",
            "mark_pluggy_item_deleted",
            "register_user_item",
            "launch_user_transactions",
        ):
            patcher = patch(f"{MODULE}.{name}")
            self.mocks[name] = patcher.start()
            self.addCleanup(patcher.stop)
        self.mocks["get_user_by_webhook_secret_hash"].return_value = self.user

    def _post(self, path, item_id, token=TOKEN, event="item/updated"):
        headers = {webhook_token_header: token} if token is not None else {}
        return self.client.post(
            path, json={"event": event, "itemId": str(item_id)}, headers=headers
        )

    def _assert_no_side_effects(self):
        self.mocks["register_user_item"].assert_not_called()
        self.mocks["launch_user_transactions"].assert_not_called()
        self.mocks["mark_pluggy_item_deleted"].assert_not_called()
        self.session.commit.assert_not_called()

    # Authentication (shared by every item webhook)

    def test_missing_token_is_unauthorized(self):
        for path in (
            item_created_webhook_path,
            item_updated_webhook_path,
            item_deleted_webhook_path,
        ):
            with self.subTest(path=path):
                response = self._post(path, uuid.uuid4(), token=None)

                self.assertEqual(response.status_code, 401)
        self.mocks["get_user_by_webhook_secret_hash"].assert_not_called()
        self._assert_no_side_effects()

    def test_unknown_token_is_unauthorized(self):
        self.mocks["get_user_by_webhook_secret_hash"].return_value = None

        response = self._post(item_updated_webhook_path, uuid.uuid4())

        self.assertEqual(response.status_code, 401)
        self._assert_no_side_effects()

    def test_user_is_found_by_the_hash_of_the_token(self):
        self._post(item_created_webhook_path, uuid.uuid4(), event="item/created")

        self.mocks["get_user_by_webhook_secret_hash"].assert_called_once_with(
            self.session, hash_webhook_secret(TOKEN)
        )

    def test_invalid_body_is_rejected(self):
        response = self.client.post(
            item_updated_webhook_path,
            json={"event": "item/updated", "itemId": "not-a-uuid"},
            headers={webhook_token_header: TOKEN},
        )

        self.assertEqual(response.status_code, 422)
        self._assert_no_side_effects()

    # item/created

    def test_created_registers_the_item_after_the_response(self):
        item_id = uuid.uuid4()

        response = self._post(item_created_webhook_path, item_id, event="item/created")

        self.assertEqual(response.status_code, 202)
        self.mocks["register_user_item"].assert_called_once_with(self.user.id, item_id)

    # item/updated

    def test_updated_syncs_the_user_transactions(self):
        item = make_pluggy_item(user_id=self.user.id)
        self.mocks["get_pluggy_item_by_pluggy_item_id"].return_value = item

        response = self._post(item_updated_webhook_path, item.pluggy_item_id)

        self.assertEqual(response.status_code, 202)
        self.mocks["get_pluggy_item_by_pluggy_item_id"].assert_called_once_with(
            self.session, item.pluggy_item_id
        )
        self.mocks["launch_user_transactions"].assert_called_once_with(self.user.id)
        self.mocks["register_user_item"].assert_not_called()

    def test_updated_with_unknown_item_registers_it(self):
        # The 'item/created' was lost: the update registers the item
        self.mocks["get_pluggy_item_by_pluggy_item_id"].return_value = None
        item_id = uuid.uuid4()

        response = self._post(item_updated_webhook_path, item_id)

        self.assertEqual(response.status_code, 202)
        self.mocks["register_user_item"].assert_called_once_with(self.user.id, item_id)
        self.mocks["launch_user_transactions"].assert_not_called()

    def test_updated_item_of_another_user_is_not_found(self):
        item = make_pluggy_item(user_id=uuid.uuid4())
        self.mocks["get_pluggy_item_by_pluggy_item_id"].return_value = item

        response = self._post(item_updated_webhook_path, item.pluggy_item_id)

        self.assertEqual(response.status_code, 404)
        self._assert_no_side_effects()

    def test_updated_deleted_item_is_ignored(self):
        item = make_pluggy_item(user_id=self.user.id, deleted_at=utc(2026, 11, 1))
        self.mocks["get_pluggy_item_by_pluggy_item_id"].return_value = item

        response = self._post(item_updated_webhook_path, item.pluggy_item_id)

        self.assertEqual(response.status_code, 202)
        self._assert_no_side_effects()

    # item/deleted

    def test_deleted_marks_the_item_and_commits(self):
        item = make_pluggy_item(user_id=self.user.id)
        self.mocks["get_pluggy_item_by_pluggy_item_id"].return_value = item

        response = self._post(
            item_deleted_webhook_path, item.pluggy_item_id, event="item/deleted"
        )

        self.assertEqual(response.status_code, 202)
        self.mocks["mark_pluggy_item_deleted"].assert_called_once_with(
            self.session, item.id
        )
        self.session.commit.assert_called_once()

    def test_deleted_unknown_or_already_deleted_item_does_nothing(self):
        cases = {
            "unknown": None,
            "already deleted": make_pluggy_item(
                user_id=self.user.id, deleted_at=utc(2026, 11, 1)
            ),
        }
        for name, item in cases.items():
            with self.subTest(case=name):
                self.mocks["get_pluggy_item_by_pluggy_item_id"].return_value = item

                response = self._post(
                    item_deleted_webhook_path, uuid.uuid4(), event="item/deleted"
                )

                self.assertEqual(response.status_code, 202)
                self._assert_no_side_effects()

    def test_deleted_item_of_another_user_is_not_found(self):
        item = make_pluggy_item(user_id=uuid.uuid4())
        self.mocks["get_pluggy_item_by_pluggy_item_id"].return_value = item

        response = self._post(
            item_deleted_webhook_path, item.pluggy_item_id, event="item/deleted"
        )

        self.assertEqual(response.status_code, 404)
        self._assert_no_side_effects()


if __name__ == "__main__":
    unittest.main()
