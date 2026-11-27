import unittest
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from infra.database.session import get_db
from infra.security.jwt_tokens import decode_access_token
from infra.security.password_hasher import get_password_hash
from presentation.app import app
from services.common.exceptions import InvalidRefreshTokenError
from tests.factories import USER_ID, make_user

MODULE = "presentation.routers.auth_router"


class AuthEndpointTestCase(unittest.TestCase):
    def setUp(self):
        self.session = MagicMock()

        def _get_db():
            yield self.session

        app.dependency_overrides[get_db] = _get_db
        self.addCleanup(app.dependency_overrides.clear)
        self.client = TestClient(app)
        self.mocks = {}
        for name in (
            "get_user_by_email",
            "issue_refresh_token",
            "rotate_refresh_token",
            "revoke_refresh_token",
        ):
            patcher = patch(f"{MODULE}.{name}")
            self.mocks[name] = patcher.start()
            self.addCleanup(patcher.stop)


class LoginTests(AuthEndpointTestCase):
    def setUp(self):
        super().setUp()
        self.user = make_user(hashed_password=get_password_hash("secret-123"))
        self.mocks["get_user_by_email"].return_value = self.user
        self.mocks["issue_refresh_token"].return_value = "refresh-1"

    def test_returns_an_access_token_and_a_refresh_token(self):
        response = self.client.post(
            "/auth/login", json={"email": "test@example.com", "password": "secret-123"}
        )

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["refresh_token"], "refresh-1")
        self.assertEqual(body["token_type"], "bearer")
        self.assertEqual(decode_access_token(body["access_token"]), USER_ID)

    def test_saves_the_refresh_token(self):
        self.client.post(
            "/auth/login", json={"email": "test@example.com", "password": "secret-123"}
        )

        self.mocks["issue_refresh_token"].assert_called_once_with(
            self.session, self.user.id
        )
        self.session.commit.assert_called_once()

    def test_wrong_password_is_401_and_issues_no_token(self):
        response = self.client.post(
            "/auth/login", json={"email": "test@example.com", "password": "wrong"}
        )

        self.assertEqual(response.status_code, 401)
        self.mocks["issue_refresh_token"].assert_not_called()

    def test_unknown_email_is_401(self):
        self.mocks["get_user_by_email"].return_value = None

        response = self.client.post(
            "/auth/login", json={"email": "no@example.com", "password": "x"}
        )

        self.assertEqual(response.status_code, 401)
        self.mocks["issue_refresh_token"].assert_not_called()


class RefreshTests(AuthEndpointTestCase):
    def test_valid_token_returns_a_new_pair_and_commits(self):
        self.mocks["rotate_refresh_token"].return_value = (USER_ID, "refresh-2")

        response = self.client.post("/auth/refresh", json={"refresh_token": "refresh-1"})

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["refresh_token"], "refresh-2")
        self.assertEqual(decode_access_token(body["access_token"]), USER_ID)
        self.mocks["rotate_refresh_token"].assert_called_once_with(
            self.session, "refresh-1"
        )
        self.session.commit.assert_called_once()

    def test_invalid_token_is_401_without_a_new_token(self):
        self.mocks["rotate_refresh_token"].side_effect = InvalidRefreshTokenError("x")

        response = self.client.post("/auth/refresh", json={"refresh_token": "bad"})

        self.assertEqual(response.status_code, 401)
        self.assertNotIn("access_token", response.json())

    def test_invalid_token_still_commits_so_a_reuse_revocation_is_saved(self):
        self.mocks["rotate_refresh_token"].side_effect = InvalidRefreshTokenError("x")

        self.client.post("/auth/refresh", json={"refresh_token": "bad"})

        self.session.commit.assert_called_once()

    def test_missing_token_is_422(self):
        response = self.client.post("/auth/refresh", json={})

        self.assertEqual(response.status_code, 422)


class LogoutTests(AuthEndpointTestCase):
    def test_revokes_the_token_and_answers_204(self):
        response = self.client.post("/auth/logout", json={"refresh_token": "refresh-1"})

        self.assertEqual(response.status_code, 204)
        self.mocks["revoke_refresh_token"].assert_called_once_with(
            self.session, "refresh-1"
        )
        self.session.commit.assert_called_once()

    def test_needs_no_access_token(self):
        response = self.client.post("/auth/logout", json={"refresh_token": "x"})

        self.assertNotEqual(response.status_code, 401)

