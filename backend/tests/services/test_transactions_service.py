import unittest
import uuid
from decimal import Decimal
from unittest.mock import MagicMock, patch

from domain.read_models import TransactionFilters
from services.transactions_service import summarize_transactions, summarize_transactions_by

MODULE = "services.transactions_service"


class SummarizeTransactionsTests(unittest.TestCase):
    def _summarize(self, rows):
        session, filters = MagicMock(), TransactionFilters()
        with patch(f"{MODULE}.transactions_repository") as repository:
            repository.summarize_transactions.return_value = rows
            summary = summarize_transactions(session, filters)
        repository.summarize_transactions.assert_called_once_with(session, filters)
        return summary

    def test_maps_each_type_to_its_total_and_count(self):
        summary = self._summarize([("DEBIT", Decimal("10.50"), 3), ("CREDIT", Decimal("99"), 1)])

        self.assertEqual(
            (summary.debit_total, summary.debit_count, summary.credit_total, summary.credit_count),
            (Decimal("10.50"), 3, Decimal("99"), 1),
        )

    def test_a_missing_type_is_zero(self):
        summary = self._summarize([("DEBIT", Decimal("10.50"), 3)])

        self.assertEqual(summary.credit_total, Decimal("0.00"))
        self.assertEqual(summary.credit_count, 0)

    def test_no_transactions_is_all_zero(self):
        summary = self._summarize([])

        self.assertEqual((summary.debit_total, summary.credit_total), (Decimal("0.00"), Decimal("0.00")))


class SummarizeTransactionsByTests(unittest.TestCase):
    ANA = uuid.UUID("00000000-0000-0000-0000-00000000b001")
    BIA = uuid.UUID("00000000-0000-0000-0000-00000000b002")

    def _summarize(self, rows, by_owner=True, by_category=False):
        session, filters = MagicMock(), TransactionFilters()
        with patch(f"{MODULE}.transactions_repository") as repository:
            repository.summarize_transactions_by.return_value = rows
            groups = summarize_transactions_by(session, filters, by_owner, by_category)
        repository.summarize_transactions_by.assert_called_once_with(
            session, filters, by_owner, by_category
        )
        return groups

    def test_debit_and_credit_rows_of_the_same_group_are_merged(self):
        groups = self._summarize([
            (self.ANA, None, "DEBIT", Decimal("100"), 3),
            (self.ANA, None, "CREDIT", Decimal("40"), 1),
        ])

        self.assertEqual(len(groups), 1)
        group = groups[0]
        self.assertEqual(group.user_id, self.ANA)
        self.assertEqual((group.debit_total, group.debit_count), (Decimal("100"), 3))
        self.assertEqual((group.credit_total, group.credit_count), (Decimal("40"), 1))

    def test_groups_are_sorted_by_debit_total_biggest_first(self):
        groups = self._summarize([
            (self.ANA, None, "DEBIT", Decimal("100"), 3),
            (self.BIA, None, "DEBIT", Decimal("900"), 9),
            (self.BIA, None, "CREDIT", Decimal("5"), 1),
        ])

        self.assertEqual([g.user_id for g in groups], [self.BIA, self.ANA])

    def test_owner_and_category_make_separate_groups(self):
        groups = self._summarize(
            [
                (self.ANA, "Food", "DEBIT", Decimal("10"), 1),
                (self.ANA, None, "DEBIT", Decimal("5"), 1),
                (self.BIA, "Food", "DEBIT", Decimal("7"), 1),
            ],
            by_category=True,
        )

        self.assertEqual(
            [(g.user_id, g.category) for g in groups],
            [(self.ANA, "Food"), (self.BIA, "Food"), (self.ANA, None)],
        )

    def test_a_group_with_only_credits_has_zero_debits(self):
        groups = self._summarize([(self.ANA, None, "CREDIT", Decimal("40"), 1)])

        self.assertEqual((groups[0].debit_total, groups[0].debit_count), (Decimal("0.00"), 0))

    def test_no_transactions_is_no_groups(self):
        self.assertEqual(self._summarize([]), [])
