import inspect
import unittest
import uuid
from unittest.mock import MagicMock, patch

from agents.tools._shared import owner_names, tool_errors
from tests.factories import make_user

MODULE = "agents.tools._shared"


class TestOwnerNames(unittest.TestCase):
    def test_maps_each_household_member_to_their_first_name(self):
        ana = make_user(id=uuid.uuid4(), first_name="Ana")
        bia = make_user(id=uuid.uuid4(), first_name="Bia")
        session = MagicMock()
        household_id = uuid.uuid4()

        with patch(f"{MODULE}.list_users_by_household", return_value=[ana, bia]) as list_users:
            names = owner_names(session, household_id)

        list_users.assert_called_once_with(session, household_id)
        self.assertEqual(names, {ana.id: "Ana", bia.id: "Bia"})


class TestToolErrors(unittest.TestCase):
    def test_returns_the_result_when_nothing_fails(self):
        @tool_errors
        def ok(value: str) -> str:
            return f"got {value}"

        self.assertEqual(ok("x"), "got x")

    def test_a_value_error_becomes_an_error_text_for_the_model(self):
        @tool_errors
        def bad() -> str:
            raise ValueError("date_from must not be after date_to")

        self.assertEqual(bad(), "Error: date_from must not be after date_to")

    def test_other_errors_are_not_hidden(self):
        @tool_errors
        def broken() -> str:
            raise RuntimeError("database is down")

        with self.assertRaises(RuntimeError):
            broken()

    def test_keeps_the_signature_so_the_tool_schema_does_not_change(self):
        def find(month_from: str | None = None, limit: int = 20) -> str:
            return ""

        self.assertEqual(inspect.signature(tool_errors(find)), inspect.signature(find))
        self.assertEqual(tool_errors(find).__name__, "find")
