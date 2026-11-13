import unittest
import uuid
from decimal import Decimal
from unittest.mock import MagicMock, patch

from domain.read_models import TransactionFilters
from services.transactions_service import (
    get_balance,
    get_total_expenses,
    get_total_revenues,
    summarize_transactions,
    summarize_transactions_by,
)

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


class TotalsOfThePeriodTests(unittest.TestCase):
    HOUSEHOLD = uuid.UUID("00000000-0000-0000-0000-00000000c001")

    def _run(self, function, sums):
        """Runs `function` with the repository answering `sums` (one per call, in order)."""
        session = MagicMock()
        filters = TransactionFilters(household_id=self.HOUSEHOLD)
        with patch(f"{MODULE}.transactions_repository") as repository:
            repository.sum_transactions_amount.side_effect = sums
            result = function(session, filters)
        return result, repository.sum_transactions_amount.call_args_list, filters

    def test_expenses_sum_only_the_debits(self):
        total, calls, _ = self._run(get_total_expenses, [Decimal("150.75")])

        self.assertEqual(total, Decimal("150.75"))
        self.assertEqual(calls[0].args[1].type, "DEBIT")

    def test_revenues_sum_only_the_credits(self):
        total, calls, _ = self._run(get_total_revenues, [Decimal("3000")])

        self.assertEqual(total, Decimal("3000"))
        self.assertEqual(calls[0].args[1].type, "CREDIT")

    def test_the_other_filters_are_kept_and_the_callers_filters_are_not_changed(self):
        _, calls, filters = self._run(get_total_expenses, [Decimal("1")])

        self.assertEqual(calls[0].args[1].household_id, self.HOUSEHOLD)
        self.assertIsNone(filters.type)

    def test_balance_is_revenues_minus_expenses(self):
        # get_balance asks for the revenues first, then for the expenses
        balance, calls, _ = self._run(get_balance, [Decimal("3000.00"), Decimal("1200.50")])

        self.assertEqual(balance, Decimal("1799.50"))
        self.assertEqual([c.args[1].type for c in calls], ["CREDIT", "DEBIT"])

    def test_balance_is_negative_when_it_spent_more_than_it_received(self):
        balance, _, _ = self._run(get_balance, [Decimal("100.00"), Decimal("250.25")])

        self.assertEqual(balance, Decimal("-150.25"))

    def test_balance_without_transactions_is_zero(self):
        balance, _, _ = self._run(get_balance, [Decimal("0.00"), Decimal("0.00")])

        self.assertEqual(balance, Decimal("0.00"))
