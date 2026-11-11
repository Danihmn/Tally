import unittest
from decimal import Decimal
from unittest.mock import MagicMock, patch

from domain.read_models import TransactionFilters
from services.transactions_service import summarize_transactions

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
