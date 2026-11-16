import unittest
import uuid
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from infra.repositories.common.exceptions import DuplicateRecordError
from infra.security.encryption import decrypt
from services.common.exceptions import EmailAlreadyExistsError, NotFoundError
from services.users_service import (
    create_user,
    get_household_user,
    list_users_by_household,
    update_user,
    update_user_password,
    update_user_pluggy_credentials,
)
from tests.factories import HOUSEHOLD_ID, make_user, utc

MODULE = "services.users_service"


def _row(user):
    """The SQLAlchemy row the repository would return: same attributes as the entity."""
    return SimpleNamespace(**{name: getattr(user, name) for name in user.__slots__})


class CreateUserTests(unittest.TestCase):
    def test_passes_the_household_to_the_repository(self):
        user = make_user(created_at=utc(2026, 11, 1))
        session = MagicMock()

        with patch(f"{MODULE}.users_repository") as repository:
            repository.create_user.return_value = _row(user)
            create_user(session, user)

        self.assertEqual(
            repository.create_user.call_args.kwargs["household_id"], HOUSEHOLD_ID
        )

    def test_passes_the_last_name_and_the_nickname(self):
        user = make_user(created_at=utc(2026, 11, 1), last_name="Souza", surname="Aninha")

        with patch(f"{MODULE}.users_repository") as repository:
            repository.create_user.return_value = _row(user)
            created = create_user(MagicMock(), user)

        kwargs = repository.create_user.call_args.kwargs
        self.assertEqual((kwargs["last_name"], kwargs["surname"]), ("Souza", "Aninha"))
        self.assertEqual(created.surname, "Aninha")

    def test_a_duplicate_is_an_email_already_exists_error(self):
        user = make_user()

        with patch(f"{MODULE}.users_repository") as repository:
            repository.create_user.side_effect = DuplicateRecordError("users", "x")
            with self.assertRaises(EmailAlreadyExistsError):
                create_user(MagicMock(), user)


class ListUsersByHouseholdTests(unittest.TestCase):
    def test_returns_the_users_of_the_household_as_entities(self):
        user = make_user()
        session = MagicMock()

        with patch(f"{MODULE}.users_repository") as repository:
            repository.list_users_by_household.return_value = [_row(user)]
            users = list_users_by_household(session, HOUSEHOLD_ID)

        repository.list_users_by_household.assert_called_once_with(session, HOUSEHOLD_ID)
        self.assertEqual(users, [user])


class GetHouseholdUserTests(unittest.TestCase):
    def test_returns_the_user_of_the_household(self):
        user = make_user()
        session = MagicMock()

        with patch(f"{MODULE}.users_repository") as repository:
            repository.get_user_in_household.return_value = _row(user)
            found = get_household_user(session, HOUSEHOLD_ID, user.id)

        repository.get_user_in_household.assert_called_once_with(
            session, user.id, HOUSEHOLD_ID
        )
        self.assertEqual(found, user)

    def test_a_user_of_another_household_is_not_found(self):
        with patch(f"{MODULE}.users_repository") as repository:
            repository.get_user_in_household.return_value = None
            with self.assertRaises(NotFoundError):
                get_household_user(MagicMock(), HOUSEHOLD_ID, uuid.uuid4())


class UpdateUserTests(unittest.TestCase):
    def test_updates_the_stored_user_and_returns_the_entity(self):
        user = make_user(surname="Aninha")
        stored = _row(make_user(id=user.id))
        session = MagicMock()

        with patch(f"{MODULE}.users_repository") as repository:
            repository.get_user_in_household.return_value = stored
            repository.update_user.return_value = _row(user)
            updated = update_user(session, HOUSEHOLD_ID, user.id, {"surname": "Aninha"})

        repository.update_user.assert_called_once_with(
            session, stored, {"surname": "Aninha"}
        )
        self.assertEqual(updated.surname, "Aninha")

    def test_the_email_is_saved_in_lowercase(self):
        user = make_user()

        with patch(f"{MODULE}.users_repository") as repository:
            repository.get_user_in_household.return_value = _row(user)
            repository.update_user.return_value = _row(user)
            update_user(MagicMock(), HOUSEHOLD_ID, user.id, {"email": "Ana@Casa.COM"})

        self.assertEqual(
            repository.update_user.call_args.args[2], {"email": "ana@casa.com"}
        )

    def test_a_user_of_another_household_is_not_found_and_nothing_changes(self):
        with patch(f"{MODULE}.users_repository") as repository:
            repository.get_user_in_household.return_value = None
            with self.assertRaises(NotFoundError):
                update_user(MagicMock(), HOUSEHOLD_ID, uuid.uuid4(), {"surname": "x"})

        repository.update_user.assert_not_called()

    def test_an_email_that_is_taken_is_an_email_already_exists_error(self):
        user = make_user()

        with patch(f"{MODULE}.users_repository") as repository:
            repository.get_user_in_household.return_value = _row(user)
            repository.update_user.side_effect = DuplicateRecordError("users", "x")
            with self.assertRaises(EmailAlreadyExistsError):
                update_user(MagicMock(), HOUSEHOLD_ID, user.id, {"email": "b@c.com"})


class UpdatePluggyCredentialsTests(unittest.TestCase):
    def test_saves_the_id_and_the_encrypted_secret_and_clears_the_webhook_secret(self):
        user = make_user(pluggy_webhook_secret_hash="old-hash")
        stored = _row(user)
        new_id = uuid.uuid4()
        session = MagicMock()

        with patch(f"{MODULE}.users_repository") as repository:
            repository.get_user_in_household.return_value = stored
            update_user_pluggy_credentials(
                session, HOUSEHOLD_ID, user.id, new_id, "new-secret"
            )

        values = repository.update_user.call_args.args[2]
        self.assertEqual(values["pluggy_client_id"], new_id)
        self.assertNotEqual(values["pluggy_client_secret_crypto"], "new-secret")
        self.assertEqual(decrypt(values["pluggy_client_secret_crypto"]), "new-secret")
        self.assertIsNone(values["pluggy_webhook_secret_hash"])
        self.assertEqual(repository.update_user.call_args.args[1], stored)

    def test_only_those_three_columns_change(self):
        user = make_user()

        with patch(f"{MODULE}.users_repository") as repository:
            repository.get_user_in_household.return_value = _row(user)
            update_user_pluggy_credentials(
                MagicMock(), HOUSEHOLD_ID, user.id, uuid.uuid4(), "s"
            )

        self.assertEqual(
            set(repository.update_user.call_args.args[2]),
            {
                "pluggy_client_id",
                "pluggy_client_secret_crypto",
                "pluggy_webhook_secret_hash",
            },
        )

    def test_a_user_of_another_household_is_not_found_and_nothing_changes(self):
        with patch(f"{MODULE}.users_repository") as repository:
            repository.get_user_in_household.return_value = None
            with self.assertRaises(NotFoundError):
                update_user_pluggy_credentials(
                    MagicMock(), HOUSEHOLD_ID, uuid.uuid4(), uuid.uuid4(), "s"
                )

        repository.update_user.assert_not_called()


class UpdateUserPasswordTests(unittest.TestCase):
    def test_saves_only_the_new_hash_on_the_stored_user(self):
        user = make_user()
        stored = _row(user)

        with patch(f"{MODULE}.users_repository") as repository:
            repository.get_user_in_household.return_value = stored
            update_user_password(MagicMock(), HOUSEHOLD_ID, user.id, "new-hash")

        self.assertEqual(
            repository.update_user.call_args.args[1:],
            (stored, {"hashed_password": "new-hash"}),
        )

    def test_a_user_of_another_household_is_not_found_and_nothing_changes(self):
        with patch(f"{MODULE}.users_repository") as repository:
            repository.get_user_in_household.return_value = None
            with self.assertRaises(NotFoundError):
                update_user_password(MagicMock(), HOUSEHOLD_ID, uuid.uuid4(), "h")

        repository.update_user.assert_not_called()
