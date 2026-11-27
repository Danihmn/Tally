import datetime
import unittest
import uuid
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from infra.security.refresh_tokens import hash_refresh_token
from services.auth_service import (
    issue_refresh_token,
    revoke_refresh_token,
    rotate_refresh_token,
)
from services.common.exceptions import InvalidRefreshTokenError
from settings import settings
from tests.factories import USER_ID, utc

MODULE = "services.auth_service"
NOW = utc(2026, 11, 27, 12)


class _FrozenDatetime(datetime.datetime):
    @classmethod
    def now(cls, tz=None):
        return NOW


def _row(**overrides):
    """The SQLAlchemy row the repository would return."""
    values = {
        "id": uuid.uuid4(),
        "user_id": USER_ID,
        "token_hash": "hash",
        "expires_at": NOW + datetime.timedelta(days=10),
        "created_at": NOW - datetime.timedelta(days=1),
        "revoked_at": None,
        "replaced_by_id": None,
    }
    values.update(overrides)
    return SimpleNamespace(**values)


class _ServiceTestCase(unittest.TestCase):
    def setUp(self):
        self.session = MagicMock()
        patcher = patch(f"{MODULE}.refresh_tokens_repository")
        self.repo = patcher.start()
        self.addCleanup(patcher.stop)
        date_patcher = patch(f"{MODULE}.datetime", _FrozenDatetime)
        date_patcher.start()
        self.addCleanup(date_patcher.stop)
        self.repo.create_refresh_token.return_value = _row()


class IssueRefreshTokenTests(_ServiceTestCase):
    def test_stores_only_the_hash_of_the_returned_token(self):
        raw = issue_refresh_token(self.session, USER_ID)

        args = self.repo.create_refresh_token.call_args.args
        self.assertEqual(args[1], USER_ID)
        self.assertEqual(args[2], hash_refresh_token(raw))
        self.assertNotEqual(args[2], raw)

    def test_token_expires_after_the_configured_days(self):
        issue_refresh_token(self.session, USER_ID)

        expires_at = self.repo.create_refresh_token.call_args.args[3]
        self.assertEqual(
            expires_at, NOW + datetime.timedelta(days=settings.refresh_token_expire_days)
        )

    def test_deletes_expired_tokens(self):
        issue_refresh_token(self.session, USER_ID)

        self.repo.delete_expired_refresh_tokens.assert_called_once_with(
            self.session, NOW
        )


class RotateRefreshTokenTests(_ServiceTestCase):
    def test_valid_token_returns_the_user_and_a_new_token(self):
        self.repo.get_refresh_token_by_hash.return_value = _row()

        user_id, new_token = rotate_refresh_token(self.session, "old-token")

        self.assertEqual(user_id, USER_ID)
        self.assertNotEqual(new_token, "old-token")
        self.repo.get_refresh_token_by_hash.assert_called_once_with(
            self.session, hash_refresh_token("old-token")
        )

    def test_old_token_is_revoked_and_points_to_the_new_one(self):
        stored = _row()
        replacement = _row()
        self.repo.get_refresh_token_by_hash.return_value = stored
        self.repo.create_refresh_token.return_value = replacement

        rotate_refresh_token(self.session, "old-token")

        self.repo.revoke_refresh_token.assert_called_once_with(
            self.session, stored.id, NOW, replaced_by_id=replacement.id
        )

    def test_unknown_token_is_invalid_and_creates_nothing(self):
        self.repo.get_refresh_token_by_hash.return_value = None

        with self.assertRaises(InvalidRefreshTokenError):
            rotate_refresh_token(self.session, "nope")

        self.repo.create_refresh_token.assert_not_called()

    def test_expired_token_is_invalid(self):
        self.repo.get_refresh_token_by_hash.return_value = _row(
            expires_at=NOW - datetime.timedelta(seconds=1)
        )

        with self.assertRaises(InvalidRefreshTokenError):
            rotate_refresh_token(self.session, "old-token")

        self.repo.create_refresh_token.assert_not_called()

    def test_reusing_a_rotated_token_revokes_every_token_of_the_user(self):
        self.repo.get_refresh_token_by_hash.return_value = _row(
            revoked_at=NOW - datetime.timedelta(minutes=5),
            replaced_by_id=uuid.uuid4(),
        )

        with self.assertRaises(InvalidRefreshTokenError):
            rotate_refresh_token(self.session, "old-token")

        self.repo.revoke_all_user_refresh_tokens.assert_called_once_with(
            self.session, USER_ID, NOW
        )
        self.repo.create_refresh_token.assert_not_called()

    def test_token_revoked_by_logout_is_invalid_but_does_not_revoke_the_others(self):
        self.repo.get_refresh_token_by_hash.return_value = _row(
            revoked_at=NOW - datetime.timedelta(minutes=5), replaced_by_id=None
        )

        with self.assertRaises(InvalidRefreshTokenError):
            rotate_refresh_token(self.session, "old-token")

        self.repo.revoke_all_user_refresh_tokens.assert_not_called()


class RevokeRefreshTokenTests(_ServiceTestCase):
    def test_revokes_a_valid_token_without_a_replacement(self):
        stored = _row()
        self.repo.get_refresh_token_by_hash.return_value = stored

        revoke_refresh_token(self.session, "token")

        self.repo.revoke_refresh_token.assert_called_once_with(
            self.session, stored.id, NOW
        )

    def test_unknown_token_is_ignored(self):
        self.repo.get_refresh_token_by_hash.return_value = None

        revoke_refresh_token(self.session, "token")

        self.repo.revoke_refresh_token.assert_not_called()

    def test_already_revoked_token_is_left_as_it_is(self):
        self.repo.get_refresh_token_by_hash.return_value = _row(
            revoked_at=NOW - datetime.timedelta(days=1)
        )

        revoke_refresh_token(self.session, "token")

        self.repo.revoke_refresh_token.assert_not_called()
