import unittest
from decimal import Decimal

from domain.transaction_amounts import amount_in_currency, is_unconverted
from tests.factories import make_transaction


class AmountInCurrencyTests(unittest.TestCase):
    def test_a_transaction_in_the_account_currency_uses_its_own_amount(self):
        t = make_transaction(currency_code="BRL", amount=Decimal("-100.00"))

        self.assertEqual(amount_in_currency(t, "BRL"), Decimal("100.00"))

    def test_a_foreign_purchase_uses_the_value_converted_by_the_bank(self):
        t = make_transaction(
            currency_code="USD",
            amount=Decimal("20.00"),
            amount_in_account_currency=Decimal("120.00"),
        )

        self.assertEqual(amount_in_currency(t, "BRL"), Decimal("120.00"))

    def test_the_converted_value_is_absolute_whatever_its_sign(self):
        t = make_transaction(
            currency_code="USD",
            amount=Decimal("-20.00"),
            amount_in_account_currency=Decimal("-120.00"),
        )

        self.assertEqual(amount_in_currency(t, "BRL"), Decimal("120.00"))

    def test_a_foreign_purchase_without_the_converted_value_has_no_amount(self):
        t = make_transaction(currency_code="USD", amount=Decimal("20.00"))

        self.assertIsNone(amount_in_currency(t, "BRL"))
        self.assertTrue(is_unconverted(t, "BRL"))

    def test_a_normal_transaction_is_not_unconverted(self):
        self.assertFalse(is_unconverted(make_transaction(), "BRL"))
