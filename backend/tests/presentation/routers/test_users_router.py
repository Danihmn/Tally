import unittest
import uuid
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from infra.database.session import get_db
from infra.security.encryption import decrypt
from infra.security.password_hasher import verify_password
from presentation.app import app
from presentation.dependencies.auth import get_current_user
from services.common.exceptions import EmailAlreadyExistsError, NotFoundError
from tests.factories import HOUSEHOLD_ID, make_user, utc

MODULE = "presentation.routers.users_router"
SECRET_FIELDS = (
    "hashed_password",
    "pluggy_client_id",
    "pluggy_client_secret",
    "pluggy_client_secret_crypto",
    "pluggy_webhook_secret_hash",
)


class UsersEndpointTestCase(unittest.TestCase):
    """Shared setup: logged user, fake session and the patched services/job."""

    PATCHED: tuple[str, ...] = ()

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
        for name in (*self.PATCHED, "register_webhooks"):
            patcher = patch(f"{MODULE}.{name}")
            self.mocks[name] = patcher.start()
            self.addCleanup(patcher.stop)

    def assert_no_secrets(self, body: dict):
        for field in SECRET_FIELDS:
            self.assertNotIn(field, body)


def _stored(**overrides):
    return make_user(created_at=utc(2026, 11, 13), **overrides)


class CreateUserEndpointTests(UsersEndpointTestCase):
    PATCHED = ("create_user",)

    def setUp(self):
        super().setUp()
        self.mocks["create_user"].side_effect = lambda session, user: make_user(
            id=uuid.uuid4(),
            created_at=utc(2026, 11, 1),
            household_id=user.household_id,
            first_name=user.first_name,
            last_name=user.last_name,
            surname=user.surname,
            email=user.email,
        )

    def _body(self, **overrides):
        body = {
            "first_name": "Ana",
            "email": "Ana@Example.com",
            "password": "12345678",
            "pluggy_client_id": str(uuid.uuid4()),
            "pluggy_client_secret": "secret",
        }
        body.update(overrides)
        return body

    def test_creates_the_user_in_the_household_of_the_logged_user(self):
        response = self.client.post("/users", json=self._body())

        self.assertEqual(response.status_code, 201)
        saved = self.mocks["create_user"].call_args.args[1]
        self.assertEqual(saved.household_id, HOUSEHOLD_ID)
        self.assertEqual(response.json()["household_id"], str(HOUSEHOLD_ID))

    def test_a_household_in_the_body_is_refused(self):
        response = self.client.post(
            "/users", json=self._body(household_id=str(uuid.uuid4()))
        )

        self.assertEqual(response.status_code, 422)
        self.mocks["create_user"].assert_not_called()
        self.session.commit.assert_not_called()

    def test_saves_the_names_and_a_lowercase_email(self):
        self.client.post(
            "/users", json=self._body(last_name="Souza", surname="Aninha")
        )

        saved = self.mocks["create_user"].call_args.args[1]
        self.assertEqual(
            (saved.first_name, saved.last_name, saved.surname, saved.email),
            ("Ana", "Souza", "Aninha", "ana@example.com"),
        )

    def test_blank_last_name_and_nickname_are_saved_as_none(self):
        self.client.post("/users", json=self._body(last_name="  ", surname=""))

        saved = self.mocks["create_user"].call_args.args[1]
        self.assertIsNone(saved.last_name)
        self.assertIsNone(saved.surname)

    def test_the_password_is_hashed_and_the_secret_is_encrypted(self):
        self.client.post("/users", json=self._body(pluggy_client_secret="s3cr3t"))

        saved = self.mocks["create_user"].call_args.args[1]
        self.assertNotEqual(saved.hashed_password, "12345678")
        self.assertTrue(verify_password("12345678", saved.hashed_password))
        self.assertNotEqual(saved.pluggy_client_secret_crypto, "s3cr3t")
        self.assertEqual(decrypt(saved.pluggy_client_secret_crypto), "s3cr3t")

    def test_commits_and_registers_the_webhooks_of_the_new_application(self):
        self.client.post("/users", json=self._body())

        self.session.commit.assert_called_once()
        self.mocks["register_webhooks"].assert_called_once_with()

    def test_the_answer_never_carries_a_secret(self):
        response = self.client.post("/users", json=self._body())

        self.assert_no_secrets(response.json())

    def test_an_email_that_is_taken_is_409_with_a_code_and_does_not_commit(self):
        self.mocks["create_user"].side_effect = EmailAlreadyExistsError("x")

        response = self.client.post("/users", json=self._body())

        self.assertEqual(response.status_code, 409)
        self.assertEqual(response.json()["code"], "EMAIL_ALREADY_EXISTS")
        self.session.commit.assert_not_called()
        self.mocks["register_webhooks"].assert_not_called()

    def test_invalid_bodies_are_422_without_calling_the_service(self):
        for change in (
            {"password": "short"},
            {"email": "not-an-email"},
            {"pluggy_client_id": "not-a-uuid"},
            {"pluggy_client_secret": ""},
            {"first_name": " "},
            {"surname": "x" * 51},
        ):
            response = self.client.post("/users", json=self._body(**change))
            self.assertEqual(response.status_code, 422, change)
        self.mocks["create_user"].assert_not_called()

    def test_without_a_token_it_is_unauthorized(self):
        app.dependency_overrides.pop(get_current_user)

        self.assertEqual(self.client.post("/users", json=self._body()).status_code, 401)


class ListUsersEndpointTests(UsersEndpointTestCase):
    PATCHED = ("list_users_by_household",)

    def test_lists_only_the_household_of_the_logged_user(self):
        self.mocks["list_users_by_household"].return_value = [_stored(), _stored()]

        response = self.client.get("/users")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json()), 2)
        self.assertEqual(
            self.mocks["list_users_by_household"].call_args.args[1], HOUSEHOLD_ID
        )

    def test_the_answer_has_the_names_and_no_secret(self):
        self.mocks["list_users_by_household"].return_value = [
            _stored(last_name="Souza", surname="Aninha")
        ]

        item = self.client.get("/users").json()[0]

        self.assertEqual((item["last_name"], item["surname"]), ("Souza", "Aninha"))
        self.assert_no_secrets(item)

    def test_limit_and_offset_cut_the_page(self):
        people = [_stored(first_name=name) for name in ("A", "B", "C")]
        self.mocks["list_users_by_household"].return_value = people

        response = self.client.get("/users", params={"limit": 1, "offset": 1})

        self.assertEqual([u["first_name"] for u in response.json()], ["B"])

    def test_without_a_token_it_is_unauthorized(self):
        app.dependency_overrides.pop(get_current_user)

        self.assertEqual(self.client.get("/users").status_code, 401)


class GetMeEndpointTests(UsersEndpointTestCase):
    def test_answers_with_the_logged_user_and_the_new_names(self):
        self.current_user = _stored(last_name="Souza", surname="Aninha")

        body = self.client.get("/users/me").json()

        self.assertEqual((body["last_name"], body["surname"]), ("Souza", "Aninha"))
        self.assert_no_secrets(body)


class GetUserEndpointTests(UsersEndpointTestCase):
    PATCHED = ("get_household_user",)

    def test_answers_with_the_user_of_the_household(self):
        user = _stored()
        self.mocks["get_household_user"].return_value = user

        response = self.client.get(f"/users/{user.id}")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            self.mocks["get_household_user"].call_args.args[1:],
            (HOUSEHOLD_ID, user.id),
        )
        self.assert_no_secrets(response.json())

    def test_a_user_of_another_household_is_404(self):
        self.mocks["get_household_user"].side_effect = NotFoundError("x")

        self.assertEqual(self.client.get(f"/users/{uuid.uuid4()}").status_code, 404)

    def test_me_is_not_taken_for_an_id(self):
        self.current_user = _stored()

        self.assertEqual(self.client.get("/users/me").status_code, 200)
        self.mocks["get_household_user"].assert_not_called()


class UpdateUserEndpointTests(UsersEndpointTestCase):
    PATCHED = ("update_user",)

    def setUp(self):
        super().setUp()
        self.user_id = uuid.uuid4()
        self.mocks["update_user"].return_value = _stored(id=self.user_id)

    def test_sends_only_the_fields_of_the_body_and_commits(self):
        response = self.client.patch(
            f"/users/{self.user_id}", json={"surname": "Aninha"}
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            self.mocks["update_user"].call_args.args[1:],
            (HOUSEHOLD_ID, self.user_id, {"surname": "Aninha"}),
        )
        self.session.commit.assert_called_once()
        self.assert_no_secrets(response.json())

    def test_a_nickname_and_a_last_name_can_be_cleared(self):
        self.client.patch(
            f"/users/{self.user_id}", json={"surname": None, "last_name": ""}
        )

        self.assertEqual(
            self.mocks["update_user"].call_args.args[3],
            {"surname": None, "last_name": None},
        )

    def test_can_change_the_four_fields_at_once(self):
        body = {
            "first_name": "Ana",
            "last_name": "Souza",
            "surname": "Aninha",
            "email": "ana@casa.com",
        }

        self.client.patch(f"/users/{self.user_id}", json=body)

        self.assertEqual(self.mocks["update_user"].call_args.args[3], body)

    def test_bad_bodies_are_422_without_calling_the_service(self):
        for body in (
            {},
            {"first_name": None},
            {"email": None},
            {"email": "nope"},
            {"first_name": " "},
            {"pluggy_client_id": str(uuid.uuid4())},
            {"password": "12345678"},
            {"household_id": str(uuid.uuid4())},
        ):
            response = self.client.patch(f"/users/{self.user_id}", json=body)
            self.assertEqual(response.status_code, 422, body)
        self.mocks["update_user"].assert_not_called()

    def test_not_found_is_404_and_does_not_commit(self):
        self.mocks["update_user"].side_effect = NotFoundError("x")

        response = self.client.patch(f"/users/{self.user_id}", json={"surname": "x"})

        self.assertEqual(response.status_code, 404)
        self.session.commit.assert_not_called()

    def test_an_email_that_is_taken_is_409_with_a_code(self):
        self.mocks["update_user"].side_effect = EmailAlreadyExistsError("x")

        response = self.client.patch(
            f"/users/{self.user_id}", json={"email": "bia@casa.com"}
        )

        self.assertEqual(response.status_code, 409)
        self.assertEqual(response.json()["code"], "EMAIL_ALREADY_EXISTS")
        self.session.commit.assert_not_called()

    def test_it_does_not_touch_the_webhooks(self):
        self.client.patch(f"/users/{self.user_id}", json={"surname": "x"})

        self.mocks["register_webhooks"].assert_not_called()


class UpdatePluggyCredentialsEndpointTests(UsersEndpointTestCase):
    PATCHED = ("update_user_pluggy_credentials",)

    def setUp(self):
        super().setUp()
        self.user_id = uuid.uuid4()
        self.client_id = uuid.uuid4()
        self.body = {
            "pluggy_client_id": str(self.client_id),
            "pluggy_client_secret": "new-secret",
        }

    def test_replaces_the_credentials_commits_and_answers_with_no_content(self):
        response = self.client.put(
            f"/users/{self.user_id}/pluggy-credentials", json=self.body
        )

        self.assertEqual(response.status_code, 204)
        self.assertEqual(response.content, b"")
        self.assertEqual(
            self.mocks["update_user_pluggy_credentials"].call_args.args[1:],
            (HOUSEHOLD_ID, self.user_id, self.client_id, "new-secret"),
        )
        self.session.commit.assert_called_once()

    def test_registers_the_webhooks_of_the_new_application(self):
        self.client.put(f"/users/{self.user_id}/pluggy-credentials", json=self.body)

        self.mocks["register_webhooks"].assert_called_once_with()

    def test_both_values_are_required_and_nothing_else_is_accepted(self):
        for body in (
            {"pluggy_client_id": str(self.client_id)},
            {"pluggy_client_secret": "x"},
            {**self.body, "pluggy_client_secret": ""},
            {**self.body, "pluggy_client_id": "not-a-uuid"},
            {**self.body, "hashed_password": "x"},
        ):
            response = self.client.put(
                f"/users/{self.user_id}/pluggy-credentials", json=body
            )
            self.assertEqual(response.status_code, 422, body)
        self.mocks["update_user_pluggy_credentials"].assert_not_called()
        self.session.commit.assert_not_called()

    def test_not_found_is_404_without_commit_or_webhooks(self):
        self.mocks["update_user_pluggy_credentials"].side_effect = NotFoundError("x")

        response = self.client.put(
            f"/users/{self.user_id}/pluggy-credentials", json=self.body
        )

        self.assertEqual(response.status_code, 404)
        self.session.commit.assert_not_called()
        self.mocks["register_webhooks"].assert_not_called()

    def test_the_secret_never_comes_back(self):
        response = self.client.put(
            f"/users/{self.user_id}/pluggy-credentials", json=self.body
        )

        self.assertNotIn(b"new-secret", response.content)

    def test_without_a_token_it_is_unauthorized(self):
        app.dependency_overrides.pop(get_current_user)

        response = self.client.put(
            f"/users/{self.user_id}/pluggy-credentials", json=self.body
        )

        self.assertEqual(response.status_code, 401)


class UpdatePasswordEndpointTests(UsersEndpointTestCase):
    PATCHED = ("update_user_password",)

    def setUp(self):
        super().setUp()
        self.user_id = uuid.uuid4()

    def test_saves_a_hash_of_the_new_password_and_commits(self):
        response = self.client.put(
            f"/users/{self.user_id}/password", json={"password": "new-password"}
        )

        self.assertEqual(response.status_code, 204)
        session, household_id, user_id, hashed = self.mocks[
            "update_user_password"
        ].call_args.args
        self.assertEqual((household_id, user_id), (HOUSEHOLD_ID, self.user_id))
        self.assertNotEqual(hashed, "new-password")
        self.assertTrue(verify_password("new-password", hashed))
        self.session.commit.assert_called_once()

    def test_a_short_or_missing_password_is_422_without_calling_the_service(self):
        for body in ({}, {"password": "short"}, {"password": "long-enough", "x": 1}):
            response = self.client.put(f"/users/{self.user_id}/password", json=body)
            self.assertEqual(response.status_code, 422, body)
        self.mocks["update_user_password"].assert_not_called()
        self.session.commit.assert_not_called()

    def test_not_found_is_404_and_does_not_commit(self):
        self.mocks["update_user_password"].side_effect = NotFoundError("x")

        response = self.client.put(
            f"/users/{self.user_id}/password", json={"password": "new-password"}
        )

        self.assertEqual(response.status_code, 404)
        self.session.commit.assert_not_called()

    def test_without_a_token_it_is_unauthorized(self):
        app.dependency_overrides.pop(get_current_user)

        response = self.client.put(
            f"/users/{self.user_id}/password", json={"password": "new-password"}
        )

        self.assertEqual(response.status_code, 401)


class NoDeleteTests(UsersEndpointTestCase):
    def test_a_user_cannot_be_deleted(self):
        response = self.client.delete(f"/users/{uuid.uuid4()}")

        self.assertEqual(response.status_code, 405)
