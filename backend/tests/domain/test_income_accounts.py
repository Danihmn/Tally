import unittest
from decimal import Decimal

from domain.income_accounts import (
    bank_code_from_transfer_number,
    is_income_transfer,
    normalize_bank_code,
    payer_bank_code,
)
from tests.factories import make_transaction


def _ted(bank_code="001", method="TED", type_="CREDIT"):
    return make_transaction(
        type=type_,
        amount=Decimal("5000.00"),
        payment_data={"payer": {"routingNumber": bank_code}, "paymentMethod": method},
    )


class NormalizeBankCodeTests(unittest.TestCase):
    def test_a_short_code_is_padded_to_three_digits(self):
        self.assertEqual(normalize_bank_code("1"), "001")
        self.assertEqual(normalize_bank_code("001"), "001")

    def test_anything_that_is_not_a_bank_code_is_none(self):
        for value in (None, "", "abc", "1234", 1):
            with self.subTest(value=value):
                self.assertIsNone(normalize_bank_code(value))


class BankCodeFromTransferNumberTests(unittest.TestCase):
    def test_reads_the_bank_code_before_the_branch_and_the_account(self):
        self.assertEqual(bank_code_from_transfer_number("001/0514/00050338-0"), "001")
        self.assertEqual(bank_code_from_transfer_number("341/0121/00057846-2"), "341")

    def test_a_short_bank_code_is_padded(self):
        self.assertEqual(bank_code_from_transfer_number("1/0514/00050338-0"), "001")

    def test_a_number_with_only_branch_and_account_has_no_bank_code(self):
        self.assertIsNone(bank_code_from_transfer_number("0001/12345-0"))

    def test_anything_else_has_no_bank_code(self):
        for value in (None, "", "abc/0514/123", "0001/0514/123", "001/0514/1/2", 1):
            with self.subTest(value=value):
                self.assertIsNone(bank_code_from_transfer_number(value))


class PayerBankCodeTests(unittest.TestCase):
    def test_reads_the_routing_number_of_the_payer(self):
        self.assertEqual(payer_bank_code({"payer": {"routingNumber": "341"}}), "341")

    def test_missing_data_is_none(self):
        for data in (None, [], {}, {"payer": None}, {"payer": {}}):
            with self.subTest(data=data):
                self.assertIsNone(payer_bank_code(data))


class IsIncomeTransferTests(unittest.TestCase):
    def test_a_ted_credit_from_one_of_the_banks_is_income(self):
        self.assertTrue(is_income_transfer(_ted("001"), {"001"}))

    def test_the_code_of_the_payer_is_compared_without_leading_zeros_mattering(self):
        self.assertTrue(is_income_transfer(_ted("1"), {"001"}))

    def test_a_pix_from_the_same_bank_is_not_income(self):
        self.assertFalse(is_income_transfer(_ted(method="PIX"), {"001"}))

    def test_a_ted_from_another_bank_is_not_income(self):
        self.assertFalse(is_income_transfer(_ted("341"), {"001"}))

    def test_a_debit_is_never_income(self):
        self.assertFalse(is_income_transfer(_ted(type_="DEBIT"), {"001"}))

    def test_without_bank_codes_nothing_is_income(self):
        self.assertFalse(is_income_transfer(_ted("001"), set()))

    def test_without_payment_data_or_payer_bank_it_is_not_income(self):
        no_data = make_transaction(type="CREDIT", payment_data=None)
        no_bank = make_transaction(type="CREDIT", payment_data={"paymentMethod": "TED"})
        self.assertFalse(is_income_transfer(no_data, {"001"}))
        self.assertFalse(is_income_transfer(no_bank, {"001"}))
