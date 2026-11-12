import unittest
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import MagicMock

from services.common.sync import diff_fields, log_critical_changes


class TestDiffFields(unittest.TestCase):
    def test_returns_only_the_compared_fields_that_differ(self):
        stored = SimpleNamespace(amount=Decimal("10.00"), name="A", status="X")
        incoming = SimpleNamespace(amount=Decimal("12.00"), name="A", status="Y")

        changes = diff_fields(stored, incoming, ("amount", "name"))

        self.assertEqual(changes, {"amount": (Decimal("10.00"), Decimal("12.00"))})

    def test_equal_objects_have_no_changes(self):
        same = SimpleNamespace(amount=Decimal("10.00"))

        self.assertEqual(diff_fields(same, SimpleNamespace(amount=Decimal("10.0")), ("amount",)), {})


class TestLogCriticalChanges(unittest.TestCase):
    def test_logs_a_warning_with_the_critical_fields_and_returns_true(self):
        logger = MagicMock()
        changes = {"amount": (Decimal("10.00"), Decimal("12.00")), "description": ("a", "b")}

        result = log_critical_changes(logger, "transaction", "tx-1", changes, ("amount", "date"))

        self.assertTrue(result)
        logger.warning.assert_called_once_with(
            "%s %s changed on Pluggy: %s",
            "transaction",
            "tx-1",
            {"amount": "10.00 -> 12.00"},
        )

    def test_no_critical_change_logs_nothing_and_returns_false(self):
        logger = MagicMock()

        result = log_critical_changes(logger, "account", "acc-1", {"name": ("a", "b")}, ("number",))

        self.assertFalse(result)
        logger.warning.assert_not_called()
