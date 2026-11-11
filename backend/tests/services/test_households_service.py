import unittest
import uuid
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from domain.entities import Household
from infra.repositories.common.exceptions import RecordNotFoundError
from services.common.exceptions import NotFoundError
from services.households_service import create_household, get_household_by_id
from tests.factories import utc

MODULE = "services.households_service"


class GetHouseholdByIdTests(unittest.TestCase):
    def test_returns_the_household_entity(self):
        household_id = uuid.uuid4()
        row = SimpleNamespace(id=household_id, created_at=utc(2026, 11, 1))

        with patch(f"{MODULE}.households_repository") as repository:
            repository.get_household_by_id.return_value = row
            household = get_household_by_id(MagicMock(), household_id)

        self.assertEqual(household, Household(id=household_id, created_at=row.created_at))

    def test_unknown_household_is_a_not_found_error(self):
        with patch(f"{MODULE}.households_repository") as repository:
            repository.get_household_by_id.side_effect = RecordNotFoundError("households", "get")
            with self.assertRaises(NotFoundError):
                get_household_by_id(MagicMock(), uuid.uuid4())


class CreateHouseholdTests(unittest.TestCase):
    def test_returns_the_created_household(self):
        row = SimpleNamespace(id=uuid.uuid4(), created_at=utc(2026, 11, 1))
        session = MagicMock()

        with patch(f"{MODULE}.households_repository") as repository:
            repository.create_household.return_value = row
            household = create_household(session)

        repository.create_household.assert_called_once_with(session)
        self.assertEqual(household.id, row.id)
