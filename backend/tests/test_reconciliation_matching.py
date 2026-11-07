import datetime
import decimal
import unittest
import uuid

from domain.entities import FinancialEntry, Transaction
from domain.reconciliation_matching import find_matches, is_match

ACCOUNT = uuid.uuid4()


def make_entry(**overrides) -> FinancialEntry:
    values = dict(
        id=uuid.uuid4(),
        user_id=uuid.uuid4(),
        description="Internet",
        type="DEBIT",
        amount=decimal.Decimal("100.00"),
        reference_month=datetime.date(2026, 11, 1),
        due_date=datetime.date(2026, 11, 10),
    )
    values.update(overrides)
    return FinancialEntry(**values)


def make_transaction(**overrides) -> Transaction:
    values = dict(
        id=uuid.uuid4(),
        bank_account_id=ACCOUNT,
        pluggy_transaction_id=uuid.uuid4(),
        date=datetime.datetime(2026, 11, 10, 12, tzinfo=datetime.UTC),
        currency_code="BRL",
        amount=decimal.Decimal("-100.00"),
        status="POSTED",
        type="DEBIT",
    )
    values.update(overrides)
    return Transaction(**values)


class IsMatchTest(unittest.TestCase):
    def test_exact_match(self):
        self.assertTrue(is_match(make_entry(), make_transaction()))

    def test_opposite_type(self):
        self.assertFalse(is_match(make_entry(), make_transaction(type="CREDIT")))

    def test_different_amount(self):
        self.assertFalse(
            is_match(make_entry(), make_transaction(amount=decimal.Decimal("-99.99")))
        )

    def test_date_within_tolerance(self):
        t = make_transaction(date=datetime.datetime(2026, 11, 13, tzinfo=datetime.UTC))
        self.assertTrue(is_match(make_entry(), t))

    def test_date_outside_tolerance(self):
        t = make_transaction(date=datetime.datetime(2026, 11, 14, tzinfo=datetime.UTC))
        self.assertFalse(is_match(make_entry(), t))

    def test_without_due_date_same_month(self):
        entry = make_entry(due_date=None)
        t = make_transaction(date=datetime.datetime(2026, 11, 28, tzinfo=datetime.UTC))
        self.assertTrue(is_match(entry, t))

    def test_without_due_date_other_month(self):
        entry = make_entry(due_date=None)
        t = make_transaction(date=datetime.datetime(2026, 10, 28, tzinfo=datetime.UTC))
        self.assertFalse(is_match(entry, t))

    def test_without_due_date_same_month_other_year(self):
        entry = make_entry(due_date=None)
        t = make_transaction(date=datetime.datetime(2025, 11, 10, tzinfo=datetime.UTC))
        self.assertFalse(is_match(entry, t))

    def test_other_bank_account(self):
        entry = make_entry(bank_account_id=uuid.uuid4())
        self.assertFalse(is_match(entry, make_transaction()))

    def test_entry_without_account_accepts_any(self):
        self.assertTrue(is_match(make_entry(bank_account_id=None), make_transaction()))


class FindMatchesTest(unittest.TestCase):
    def test_single_pair(self):
        entry, t = make_entry(), make_transaction()
        self.assertEqual(find_matches([entry], [t]), [(entry, t)])

    def test_no_candidate_stays_pending(self):
        self.assertEqual(find_matches([make_entry()], []), [])

    def test_two_equal_entries_one_transaction_match_nothing(self):
        entries = [make_entry(), make_entry()]
        self.assertEqual(find_matches(entries, [make_transaction()]), [])

    def test_one_entry_two_equal_transactions_match_nothing(self):
        transactions = [make_transaction(), make_transaction()]
        self.assertEqual(find_matches([make_entry()], transactions), [])

    def test_unambiguous_pairs_survive_next_to_ambiguous_ones(self):
        clear = make_entry(amount=decimal.Decimal("50.00"))
        clear_t = make_transaction(amount=decimal.Decimal("-50.00"))
        entries = [clear, make_entry(), make_entry()]
        transactions = [clear_t, make_transaction()]
        self.assertEqual(find_matches(entries, transactions), [(clear, clear_t)])


if __name__ == "__main__":
    unittest.main()
