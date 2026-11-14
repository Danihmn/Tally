import unittest

from domain.transfer_documents import (
    EXTERNAL,
    SAME_HOUSEHOLD,
    SAME_PERSON,
    classify_by_documents,
    normalize_cpf,
)
from tests.factories import make_transaction

# Invented documents (never real ones)
ME = "11144477735"
PARTNER = "52998224725"
STRANGER = "39053344705"
HOUSEHOLD = {ME, PARTNER}


def cpf(digits: str) -> dict:
    formatted = f"{digits[:3]}.{digits[3:6]}.{digits[6:9]}-{digits[9:]}"
    return {"type": "CPF", "value": formatted}


def cnpj() -> dict:
    return {"type": "CNPJ", "value": "11.222.333/0001-81"}


def party(document=None) -> dict:
    return {
        "name": None,
        "branchNumber": None,
        "accountNumber": None,
        "routingNumber": None,
        "documentNumber": document,
        "routingNumberISPB": None,
    }


def payment(payer=None, receiver=None) -> dict:
    return {
        "payer": party(payer),
        "receiver": party(receiver),
        "reason": None,
        "paymentMethod": "PIX",
    }


def debit(payer=None, receiver=None, **overrides):
    return make_transaction(
        type="DEBIT", payment_data=payment(payer, receiver), **overrides
    )


def credit(payer=None, receiver=None, **overrides):
    return make_transaction(
        type="CREDIT", payment_data=payment(payer, receiver), **overrides
    )


def classify(transaction, owner=ME, household=HOUSEHOLD, all_known=True):
    return classify_by_documents(transaction, owner, household, all_known)


class NormalizeCpfTests(unittest.TestCase):
    def test_keeps_only_the_digits(self):
        self.assertEqual(normalize_cpf("111.444.777-35"), ME)
        self.assertEqual(normalize_cpf(ME), ME)

    def test_a_masked_short_or_empty_cpf_is_unknown(self):
        for value in ("***.444.777-**", "111.444.777", "", "   ", None, 11144477735):
            with self.subTest(value=value):
                self.assertIsNone(normalize_cpf(value))

    def test_a_cpf_of_one_repeated_digit_is_unknown(self):
        self.assertIsNone(normalize_cpf("111.111.111-11"))


class TransferToMyselfTests(unittest.TestCase):
    def test_a_debit_to_my_own_cpf_is_a_transfer_between_my_accounts(self):
        self.assertEqual(classify(debit(cpf(ME), cpf(ME))), SAME_PERSON)

    def test_a_credit_from_my_own_cpf_is_a_transfer_between_my_accounts(self):
        self.assertEqual(classify(credit(cpf(ME), cpf(ME))), SAME_PERSON)

    def test_one_document_is_enough_the_direction_says_who_is_the_counterparty(self):
        self.assertEqual(classify(debit(payer=None, receiver=cpf(ME))), SAME_PERSON)
        self.assertEqual(classify(credit(payer=cpf(ME), receiver=None)), SAME_PERSON)


class TransferToMyPartnerTests(unittest.TestCase):
    def test_a_debit_to_the_partners_cpf_is_a_transfer_inside_the_household(self):
        self.assertEqual(classify(debit(cpf(ME), cpf(PARTNER))), SAME_HOUSEHOLD)

    def test_a_credit_from_the_partners_cpf_is_a_transfer_inside_the_household(self):
        self.assertEqual(classify(credit(cpf(PARTNER), cpf(ME))), SAME_HOUSEHOLD)

    def test_the_counterparty_alone_is_enough(self):
        self.assertEqual(classify(debit(receiver=cpf(PARTNER))), SAME_HOUSEHOLD)


class ThirdPartiesTests(unittest.TestCase):
    def test_a_company_is_external(self):
        self.assertEqual(classify(debit(cpf(ME), cnpj())), EXTERNAL)
        self.assertEqual(classify(credit(cnpj(), cpf(ME))), EXTERNAL)

    def test_a_company_is_external_even_when_a_cpf_of_the_household_is_unknown(self):
        self.assertEqual(classify(debit(cpf(ME), cnpj()), all_known=False), EXTERNAL)

    def test_a_cpf_outside_the_household_is_external(self):
        self.assertEqual(classify(debit(cpf(ME), cpf(STRANGER))), EXTERNAL)

    def test_a_cpf_outside_the_household_is_not_conclusive_when_someone_has_no_known_cpf(self):
        self.assertIsNone(classify(debit(cpf(ME), cpf(STRANGER)), all_known=False))

    def test_a_household_cpf_is_still_recognized_when_someone_has_no_known_cpf(self):
        transaction = debit(cpf(ME), cpf(PARTNER))

        self.assertEqual(classify(transaction, all_known=False), SAME_HOUSEHOLD)


class WhenTheDocumentsDoNotSettleItTests(unittest.TestCase):
    def test_no_payment_data_is_unknown(self):
        self.assertIsNone(classify(make_transaction(type="DEBIT", payment_data=None)))

    def test_an_empty_or_malformed_payment_data_is_unknown(self):
        for payment_data in ({}, [], "text", 42, {"payer": None, "receiver": None}):
            with self.subTest(payment_data=payment_data):
                transaction = make_transaction(type="DEBIT", payment_data=payment_data)

                self.assertIsNone(classify(transaction))

    def test_a_party_without_document_is_unknown(self):
        self.assertIsNone(classify(debit(cpf(ME), None)))

    def test_a_document_that_is_not_an_object_or_has_no_value_is_unknown(self):
        for document in ("434.550.828-23", {"type": "CPF"}, {"value": "x"}, {"type": "CPF", "value": None}):
            with self.subTest(document=document):
                self.assertIsNone(classify(debit(cpf(ME), document)))

    def test_a_masked_cpf_is_unknown(self):
        masked = {"type": "CPF", "value": "***.444.777-**"}

        self.assertIsNone(classify(debit(cpf(ME), masked)))

    def test_an_unknown_document_type_is_unknown(self):
        self.assertIsNone(classify(debit(cpf(ME), {"type": "RG", "value": "123456789"})))

    def test_an_account_without_a_known_cpf_is_unknown(self):
        self.assertIsNone(classify(debit(cpf(ME), cpf(ME)), owner=None))

    def test_the_owners_side_must_be_the_owner_otherwise_the_data_is_odd(self):
        # A debit whose payer is not the owner of the account
        self.assertIsNone(classify(debit(cpf(PARTNER), cpf(STRANGER))))
        self.assertIsNone(classify(debit(cnpj(), cpf(ME))))
