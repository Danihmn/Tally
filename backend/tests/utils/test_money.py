import unittest
from decimal import Decimal

from utils.money import round_to_cents, round_to_cents_or_none


class TestRoundToCents(unittest.TestCase):
    def test_rounds_half_up(self):
        self.assertEqual(round_to_cents(Decimal("2.345")), Decimal("2.35"))
        self.assertEqual(round_to_cents(Decimal("-2.345")), Decimal("-2.35"))
        self.assertEqual(round_to_cents(Decimal("2.344")), Decimal("2.34"))

    def test_keeps_two_decimal_places(self):
        self.assertEqual(str(round_to_cents(Decimal("10"))), "10.00")

    def test_never_returns_negative_zero(self):
        self.assertEqual(str(round_to_cents(Decimal("-0.001"))), "0.00")

    def test_a_large_value_is_still_rounded(self):
        value = Decimal("12345678901234567890123456789.005")

        self.assertEqual(round_to_cents(value), Decimal("12345678901234567890123456789.01"))

    def test_a_value_too_large_to_round_is_a_value_error(self):
        with self.assertRaises(ValueError):
            round_to_cents(Decimal("1e70"))


class TestRoundToCentsOrNone(unittest.TestCase):
    def test_none_stays_none(self):
        self.assertIsNone(round_to_cents_or_none(None))

    def test_a_value_is_rounded(self):
        self.assertEqual(round_to_cents_or_none(Decimal("1.005")), Decimal("1.01"))
