import datetime
import unittest
import uuid
from decimal import Decimal

from domain.reconciliation_matching import find_matches, is_match
from tests.factories import make_entry, make_transaction, utc


class IsMatchTests(unittest.TestCase):
    def test_expense_matches_debit_with_same_absolute_amount(self):
        entry = make_entry(type="EXPENSES", amount=Decimal("100.00"))
        transaction = make_transaction(type="DEBIT", amount=Decimal("-100.00"))

        self.assertTrue(is_match(entry, transaction))

    def test_revenue_matches_credit(self):
        entry = make_entry(type="REVENUES", amount=Decimal("50.00"))
        transaction = make_transaction(type="CREDIT", amount=Decimal("50.00"))

        self.assertTrue(is_match(entry, transaction))

    def test_wrong_direction_does_not_match(self):
        self.assertFalse(
            is_match(make_entry(type="EXPENSES"), make_transaction(type="CREDIT"))
        )
        self.assertFalse(
            is_match(make_entry(type="REVENUES"), make_transaction(type="DEBIT"))
        )

    def test_unknown_entry_type_does_not_match(self):
        self.assertFalse(is_match(make_entry(type="OTHER"), make_transaction()))

    def test_different_amount_does_not_match(self):
        entry = make_entry(amount=Decimal("100.00"))
        transaction = make_transaction(amount=Decimal("-100.01"))

        self.assertFalse(is_match(entry, transaction))

    def test_different_currency_does_not_match(self):
        self.assertFalse(
            is_match(
                make_entry(currency_code="BRL"), make_transaction(currency_code="USD")
            )
        )

    def test_entry_account_must_be_the_transaction_account(self):
        account = uuid.uuid4()
        transaction = make_transaction(bank_account_id=account)

        self.assertTrue(is_match(make_entry(bank_account_id=account), transaction))
        self.assertFalse(
            is_match(make_entry(bank_account_id=uuid.uuid4()), transaction)
        )

    def test_entry_without_account_matches_any_account(self):
        entry = make_entry(bank_account_id=None)

        self.assertTrue(is_match(entry, make_transaction(bank_account_id=uuid.uuid4())))

    def test_due_date_tolerance_is_three_days(self):
        entry = make_entry(due_date=datetime.date(2026, 11, 10))

        self.assertTrue(is_match(entry, make_transaction(date=utc(2026, 11, 7))))
        self.assertTrue(is_match(entry, make_transaction(date=utc(2026, 11, 13))))
        self.assertFalse(is_match(entry, make_transaction(date=utc(2026, 11, 6))))
        self.assertFalse(is_match(entry, make_transaction(date=utc(2026, 11, 14))))

    def test_due_date_wins_over_reference_month(self):
        # Paid in the next month, but inside the tolerance of the due date
        entry = make_entry(
            reference_month=datetime.date(2026, 10, 1),
            due_date=datetime.date(2026, 10, 31),
        )

        self.assertTrue(is_match(entry, make_transaction(date=utc(2026, 11, 2))))

    def test_without_due_date_the_month_must_be_the_reference_month(self):
        entry = make_entry(reference_month=datetime.date(2026, 11, 1), due_date=None)

        self.assertTrue(is_match(entry, make_transaction(date=utc(2026, 11, 30))))
        self.assertFalse(is_match(entry, make_transaction(date=utc(2026, 10, 31))))
        self.assertFalse(is_match(entry, make_transaction(date=utc(2025, 11, 15))))


class FindMatchesTests(unittest.TestCase):
    def test_pairs_one_entry_with_its_only_transaction(self):
        entry = make_entry()
        transaction = make_transaction()
        other = make_transaction(amount=Decimal("-999.00"))

        self.assertEqual(
            find_matches([entry], [transaction, other]), [(entry, transaction)]
        )

    def test_entry_with_two_candidates_is_left_out(self):
        entry = make_entry()

        self.assertEqual(
            find_matches([entry], [make_transaction(), make_transaction()]), []
        )

    def test_transaction_wanted_by_two_entries_is_left_out(self):
        transaction = make_transaction()

        self.assertEqual(find_matches([make_entry(), make_entry()], [transaction]), [])

    def test_ambiguous_pair_does_not_block_the_clear_ones(self):
        clear_entry = make_entry(amount=Decimal("30.00"))
        clear_transaction = make_transaction(amount=Decimal("-30.00"))
        ambiguous = [make_entry(), make_entry()]

        pairs = find_matches(
            [clear_entry, *ambiguous], [clear_transaction, make_transaction()]
        )

        self.assertEqual(pairs, [(clear_entry, clear_transaction)])

    def test_items_without_id_are_ignored(self):
        self.assertEqual(find_matches([make_entry(id=None)], [make_transaction()]), [])
        self.assertEqual(find_matches([make_entry()], [make_transaction(id=None)]), [])

    def test_empty_inputs(self):
        self.assertEqual(find_matches([], [make_transaction()]), [])
        self.assertEqual(find_matches([make_entry()], []), [])


if __name__ == "__main__":
    unittest.main()
