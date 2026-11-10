import datetime
import unittest
from unittest.mock import MagicMock, call, patch

from infra.security.webhook_secret import hash_webhook_secret
from integrations.pluggy.config import item_webhook_paths, webhook_token_header
from services.pluggy_webhooks_service import ensure_item_webhooks
from tests.factories import make_user, make_webhook, page

MODULE = "services.pluggy_webhooks_service"
BASE_URL = "https://api.test"
OLD_SECRET = "old-secret"
NEW_SECRET = "new-secret"


def _webhooks(secret: str = OLD_SECRET, **overrides_by_event):
    """One webhook per item event, all pointing to BASE_URL and sending `secret`."""
    return [
        make_webhook(
            event=event,
            url=BASE_URL + path,
            headers={webhook_token_header: secret},
            **overrides_by_event.get(event, {}),
        )
        for event, path in item_webhook_paths.items()
    ]


class EnsureItemWebhooksTests(unittest.TestCase):
    def setUp(self):
        self.session = MagicMock()
        self.user = make_user(
            pluggy_webhook_secret_hash=hash_webhook_secret(OLD_SECRET)
        )
        self.mocks = {}
        for name in (
            "authenticate",
            "decrypt",
            "list_webhooks",
            "create_webhook",
            "update_webhook",
            "update_user_webhook_secret_hash",
            "generate_webhook_secret",
        ):
            patcher = patch(f"{MODULE}.{name}")
            self.mocks[name] = patcher.start()
            self.addCleanup(patcher.stop)
        self.mocks["authenticate"].return_value = "api-key"
        self.mocks["decrypt"].return_value = "client-secret"
        self.mocks["generate_webhook_secret"].return_value = NEW_SECRET

    def _run(self, registered, base_url=BASE_URL):
        self.mocks["list_webhooks"].return_value = page(registered)
        ensure_item_webhooks(self.session, self.user, base_url)

    def _assert_rotated(self):
        self.mocks["update_user_webhook_secret_hash"].assert_called_once_with(
            self.session, self.user.id, hash_webhook_secret(NEW_SECRET)
        )

    def test_authenticates_with_the_decrypted_secret(self):
        self._run(_webhooks())

        self.mocks["decrypt"].assert_called_once_with("secret-crypto")
        self.mocks["authenticate"].assert_called_once_with(
            client_id=self.user.pluggy_client_id, client_secret="client-secret"
        )

    def test_everything_in_place_changes_nothing(self):
        self._run(_webhooks())

        self.mocks["create_webhook"].assert_not_called()
        self.mocks["update_webhook"].assert_not_called()
        self.mocks["update_user_webhook_secret_hash"].assert_not_called()

    def test_header_name_is_compared_without_case(self):
        registered = [
            make_webhook(
                event=w.event, url=w.url, headers={"x-webhook-token": OLD_SECRET}
            )
            for w in _webhooks()
        ]

        self._run(registered)

        self.mocks["update_user_webhook_secret_hash"].assert_not_called()

    def test_no_webhooks_creates_all_of_them_with_a_new_secret(self):
        self._run([])

        self.assertCountEqual(
            self.mocks["create_webhook"].call_args_list,
            [
                call(
                    "api-key",
                    BASE_URL + path,
                    event,
                    {webhook_token_header: NEW_SECRET},
                )
                for event, path in item_webhook_paths.items()
            ],
        )
        self.mocks["update_webhook"].assert_not_called()
        self._assert_rotated()

    def test_one_missing_creates_it_and_rotates_the_others(self):
        registered = [w for w in _webhooks() if w.event != "item/deleted"]

        self._run(registered)

        self.mocks["create_webhook"].assert_called_once_with(
            "api-key",
            BASE_URL + item_webhook_paths["item/deleted"],
            "item/deleted",
            {webhook_token_header: NEW_SECRET},
        )
        self.assertCountEqual(
            self.mocks["update_webhook"].call_args_list,
            [
                call(
                    "api-key",
                    str(w.id),
                    headers={webhook_token_header: NEW_SECRET},
                    enabled=None,
                )
                for w in registered
            ],
        )
        self._assert_rotated()

    def test_webhook_with_another_url_counts_as_missing(self):
        registered = _webhooks()
        registered[0] = make_webhook(
            event=registered[0].event,
            url="https://old.test" + item_webhook_paths[registered[0].event],
            headers={webhook_token_header: OLD_SECRET},
        )

        self._run(registered)

        self.mocks["create_webhook"].assert_called_once()
        self._assert_rotated()

    def test_secret_that_does_not_match_the_hash_rotates(self):
        self._run(_webhooks(secret="someone-else"))

        self.assertEqual(self.mocks["update_webhook"].call_count, 3)
        self._assert_rotated()

    def test_hash_never_saved_rotates(self):
        self.user = make_user(pluggy_webhook_secret_hash=None)

        self._run(_webhooks())

        self._assert_rotated()

    def test_rotation_enables_a_disabled_webhook(self):
        disabled = {"disabled_at": datetime.datetime(2026, 11, 1, tzinfo=datetime.UTC)}
        registered = _webhooks(secret="someone-else", **{"item/updated": disabled})

        self._run(registered)

        updated = next(w for w in registered if w.event == "item/updated")
        self.mocks["update_webhook"].assert_any_call(
            "api-key",
            str(updated.id),
            headers={webhook_token_header: NEW_SECRET},
            enabled=True,
        )

    def test_disabled_webhook_with_the_right_secret_is_only_enabled(self):
        disabled = {"disabled_at": datetime.datetime(2026, 11, 1, tzinfo=datetime.UTC)}
        registered = _webhooks(**{"item/updated": disabled})

        self._run(registered)

        updated = next(w for w in registered if w.event == "item/updated")
        self.mocks["update_webhook"].assert_called_once_with(
            "api-key", str(updated.id), enabled=True
        )
        self.mocks["update_user_webhook_secret_hash"].assert_not_called()

    def test_trailing_slash_in_the_base_url_is_ignored(self):
        self._run(_webhooks(), base_url=BASE_URL + "/")

        self.mocks["create_webhook"].assert_not_called()
        self.mocks["update_user_webhook_secret_hash"].assert_not_called()

    def test_user_without_id_is_rejected(self):
        self.user = make_user(id=None)

        with self.assertRaises(ValueError):
            self._run(_webhooks())

        self.mocks["authenticate"].assert_not_called()


if __name__ == "__main__":
    unittest.main()
