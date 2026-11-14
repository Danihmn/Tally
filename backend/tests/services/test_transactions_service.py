import datetime
import unittest
import uuid
from decimal import Decimal
from unittest.mock import MagicMock, patch

from domain.read_models import TransactionFilters
from services.transactions_service import (
    get_average_daily_expenses,
    get_balance,
    get_daily_expenses,
    get_top_expenses,
    get_total_expenses,
    get_total_revenues,
    list_unclassified_transactions,
    mark_internal_transfer,
    summarize_transactions,
    summarize_transactions_by,
    update_transactions,
    upsert_transactions,
)
from tests.factories import make_transaction

MODULE = "services.transactions_service"


class SyncKeepsTheInternalTransferClassificationTests(unittest.TestCase):
    """The Pluggy sync must never send the classification columns (it would reset them to NULL)."""

    CLASSIFICATION = {"internal_transfer", "internal_transfer_classification_source"}

    def _classified(self):
        return make_transaction(
            internal_transfer="SAME_PERSON",
            internal_transfer_classification_source="MANUAL",
        )

    def test_the_upsert_does_not_send_the_classification_columns(self):
        with patch(f"{MODULE}.transactions_repository") as repository:
            repository.upsert_transactions.return_value = []
            upsert_transactions(MagicMock(), [self._classified()])

        (values,) = repository.upsert_transactions.call_args.args[1]
        self.assertFalse(self.CLASSIFICATION & values.keys())
        self.assertIn("description", values)

    def test_the_update_does_not_send_the_classification_columns(self):
        with patch(f"{MODULE}.transactions_repository") as repository:
            update_transactions(MagicMock(), [self._classified()])

        (values,) = repository.update_transactions.call_args.args[1]
        self.assertFalse(self.CLASSIFICATION & values.keys())
        self.assertIn("description", values)


class ListUnclassifiedTransactionsTests(unittest.TestCase):
    def test_asks_the_repository_for_the_accounts_and_returns_entities(self):
        session, accounts = MagicMock(), [uuid.uuid4(), uuid.uuid4()]
        stored = make_transaction()
        with patch(f"{MODULE}.transactions_repository") as repository:
            repository.list_unclassified_posted_by_accounts.return_value = [stored]
            result = list_unclassified_transactions(session, accounts)

        repository.list_unclassified_posted_by_accounts.assert_called_once_with(
            session, accounts
        )
        self.assertEqual(result, [stored])

    def test_no_accounts_does_not_hit_the_repository(self):
        with patch(f"{MODULE}.transactions_repository") as repository:
            result = list_unclassified_transactions(MagicMock(), [])

        self.assertEqual(result, [])
        repository.list_unclassified_posted_by_accounts.assert_not_called()


class MarkInternalTransferTests(unittest.TestCase):
    def test_sends_the_ids_the_value_and_the_source_and_returns_how_many_changed(self):
        session, ids = MagicMock(), [uuid.uuid4(), uuid.uuid4()]
        with patch(f"{MODULE}.transactions_repository") as repository:
            repository.set_internal_transfer.return_value = 2
            changed = mark_internal_transfer(session, ids, "SAME_PERSON", "AUTO")

        repository.set_internal_transfer.assert_called_once_with(
            session, ids, "SAME_PERSON", "AUTO"
        )
        self.assertEqual(changed, 2)

    def test_no_ids_does_not_hit_the_repository(self):
        with patch(f"{MODULE}.transactions_repository") as repository:
            changed = mark_internal_transfer(MagicMock(), [], "SAME_PERSON", "AUTO")

        self.assertEqual(changed, 0)
        repository.set_internal_transfer.assert_not_called()


class SummarizeTransactionsTests(unittest.TestCase):
    def _summarize(self, rows):
        session, filters = MagicMock(), TransactionFilters()
        with patch(f"{MODULE}.transactions_repository") as repository:
            repository.summarize_transactions.return_value = rows
            summary = summarize_transactions(session, filters)
        repository.summarize_transactions.assert_called_once_with(session, filters)
        return summary

    def test_maps_each_type_to_its_total_and_count(self):
        summary = self._summarize([
            ("DEBIT", Decimal("10.50"), 3),
            ("CREDIT", Decimal("99"), 1),
        ])

        self.assertEqual(
            (
                summary.debit_total,
                summary.debit_count,
                summary.credit_total,
                summary.credit_count,
            ),
            (Decimal("10.50"), 3, Decimal("99"), 1),
        )

    def test_a_missing_type_is_zero(self):
        summary = self._summarize([("DEBIT", Decimal("10.50"), 3)])

        self.assertEqual(summary.credit_total, Decimal("0.00"))
        self.assertEqual(summary.credit_count, 0)

    def test_no_transactions_is_all_zero(self):
        summary = self._summarize([])

        self.assertEqual(
            (summary.debit_total, summary.credit_total),
            (Decimal("0.00"), Decimal("0.00")),
        )


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

        self.assertEqual(
            (groups[0].debit_total, groups[0].debit_count), (Decimal("0.00"), 0)
        )

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
        balance, calls, _ = self._run(
            get_balance, [Decimal("3000.00"), Decimal("1200.50")]
        )

        self.assertEqual(balance, Decimal("1799.50"))
        self.assertEqual([c.args[1].type for c in calls], ["CREDIT", "DEBIT"])

    def test_balance_is_negative_when_it_spent_more_than_it_received(self):
        balance, _, _ = self._run(get_balance, [Decimal("100.00"), Decimal("250.25")])

        self.assertEqual(balance, Decimal("-150.25"))

    def test_balance_without_transactions_is_zero(self):
        balance, _, _ = self._run(get_balance, [Decimal("0.00"), Decimal("0.00")])

        self.assertEqual(balance, Decimal("0.00"))


def _utc_day(day: int) -> datetime.datetime:
    return datetime.datetime(2026, 11, day, tzinfo=datetime.UTC)


class TopExpensesTests(unittest.TestCase):
    def _run(self, rows, limit=5):
        session, filters = MagicMock(), TransactionFilters()
        with patch(f"{MODULE}.transactions_repository") as repository:
            repository.list_top_transactions.return_value = rows
            result = get_top_expenses(session, filters, limit)
        return result, repository.list_top_transactions.call_args, filters

    def test_asks_only_for_debits_and_passes_the_limit(self):
        _, call, _ = self._run([], limit=3)

        self.assertEqual(call.args[1].type, "DEBIT")
        self.assertEqual(call.args[2], 3)

    def test_keeps_the_order_of_the_repository_and_maps_the_three_fields(self):
        result, _, _ = self._run([
            (_utc_day(10), "Rent", Decimal("1500.00")),
            (_utc_day(3), None, Decimal("20.50")),
        ])

        self.assertEqual(
            [(e.date, e.description, e.amount) for e in result],
            [
                (datetime.date(2026, 11, 10), "Rent", Decimal("1500.00")),
                (datetime.date(2026, 11, 3), None, Decimal("20.50")),
            ],
        )

    def test_the_day_is_the_utc_day_even_when_the_driver_sends_another_time_zone(self):
        minus_three = datetime.timezone(datetime.timedelta(hours=-3))
        # 22:00 on the 9th at UTC-3 is 01:00 on the 10th in UTC
        late = datetime.datetime(2026, 11, 9, 22, 0, tzinfo=minus_three)

        result, _, _ = self._run([(late, "Dinner", Decimal("80"))])

        self.assertEqual(result[0].date, datetime.date(2026, 11, 10))

    def test_the_callers_filters_are_not_changed(self):
        _, _, filters = self._run([])

        self.assertIsNone(filters.type)


class DailyExpensesTests(unittest.TestCase):
    def _run(self, rows, date_from=1, date_to=6):
        """Period from day `date_from` until the end of day `date_to - 1` (exclusive bound)."""
        session = MagicMock()
        filters = TransactionFilters(
            date_from=_utc_day(date_from), date_to=_utc_day(date_to)
        )
        with patch(f"{MODULE}.transactions_repository") as repository:
            repository.sum_transactions_by_day.return_value = rows
            result = get_daily_expenses(session, filters)
        return result, repository.sum_transactions_by_day.call_args, filters

    def test_asks_only_for_debits(self):
        _, call, filters = self._run([])

        self.assertEqual(call.args[1].type, "DEBIT")
        self.assertIsNone(filters.type)

    def test_days_without_spending_are_in_the_list_with_zero(self):
        result, _, _ = self._run([
            (datetime.date(2026, 11, 2), Decimal("100.00")),
            (datetime.date(2026, 11, 4), Decimal("50.25")),
        ])

        self.assertEqual(
            [(d.day.day, d.total) for d in result],
            [
                (1, Decimal("0.00")),
                (2, Decimal("100.00")),
                (3, Decimal("0.00")),
                (4, Decimal("50.25")),
                (5, Decimal("0.00")),
            ],
        )

    def test_the_list_has_one_item_per_day_of_the_period_oldest_first(self):
        result, _, _ = self._run([], date_from=1, date_to=13)  # Days 1 to 12

        self.assertEqual(len(result), 12)
        self.assertEqual(result[0].day, datetime.date(2026, 11, 1))
        self.assertEqual(result[-1].day, datetime.date(2026, 11, 12))

    def test_a_period_of_one_day_has_one_item(self):
        result, _, _ = self._run(
            [(datetime.date(2026, 11, 5), Decimal("9"))], date_from=5, date_to=6
        )

        self.assertEqual([(d.day.day, d.total) for d in result], [(5, Decimal("9"))])

    def test_a_filter_without_the_period_is_an_error(self):
        with self.assertRaises(ValueError):
            get_daily_expenses(MagicMock(), TransactionFilters())


class AverageDailyExpensesTests(unittest.TestCase):
    def _average(self, rows, date_from=1, date_to=13):
        session = MagicMock()
        filters = TransactionFilters(
            date_from=_utc_day(date_from), date_to=_utc_day(date_to)
        )
        with patch(f"{MODULE}.transactions_repository") as repository:
            repository.sum_transactions_by_day.return_value = rows
            return get_average_daily_expenses(session, filters)

    def test_days_without_spending_count_in_the_average(self):
        # 600 spent in 3 days of a 12 days period
        rows = [
            (datetime.date(2026, 11, 2), Decimal("100")),
            (datetime.date(2026, 11, 5), Decimal("200")),
            (datetime.date(2026, 11, 9), Decimal("300")),
        ]

        self.assertEqual(self._average(rows), Decimal("50.00"))

    def test_is_rounded_to_cents(self):
        average = self._average(
            [(datetime.date(2026, 11, 1), Decimal("100"))], date_from=1, date_to=4
        )

        self.assertEqual(average, Decimal("33.33"))

    def test_a_period_without_spending_is_zero(self):
        self.assertEqual(self._average([]), Decimal("0.00"))

    def test_reuses_the_daily_totals(self):
        session = MagicMock()
        filters = TransactionFilters(date_from=_utc_day(1), date_to=_utc_day(3))
        with patch(f"{MODULE}.get_daily_expenses") as daily:
            from domain.read_models import DailyTotal

            daily.return_value = [
                DailyTotal(datetime.date(2026, 11, 1), Decimal("10.00")),
                DailyTotal(datetime.date(2026, 11, 2), Decimal("21.00")),
            ]
            average = get_average_daily_expenses(session, filters)

        daily.assert_called_once_with(session, filters)
        self.assertEqual(average, Decimal("15.50"))
