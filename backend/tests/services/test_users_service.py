import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from services.users_service import create_user, list_users_by_household
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


class ListUsersByHouseholdTests(unittest.TestCase):
    def test_returns_the_users_of_the_household_as_entities(self):
        user = make_user()
        session = MagicMock()

        with patch(f"{MODULE}.users_repository") as repository:
            repository.list_users_by_household.return_value = [_row(user)]
            users = list_users_by_household(session, HOUSEHOLD_ID)

        repository.list_users_by_household.assert_called_once_with(session, HOUSEHOLD_ID)
        self.assertEqual(users, [user])
