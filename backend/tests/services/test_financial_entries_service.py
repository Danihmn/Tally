import datetime
import unittest
from decimal import Decimal
from unittest.mock import MagicMock, patch

import uuid

from domain.read_models import FinancialEntryFilters
from services.financial_entries_service import (
    count_not_reconciled_entries,
    count_reconciled_entries,
    create_financial_entry,
    delete_financial_entry,
    get_financial_entry,
    get_total_not_reconciled,
    get_total_planned,
    get_total_reconciled,
    list_provisioned_recurrence_ids,
    list_upcoming_entries,
    summarize_financial_entries,
    update_financial_entry,
)
from services.common.exceptions import InvalidDataError, NotFoundError
from tests.factories import HOUSEHOLD_ID, make_entry

MODULE = "services.financial_entries_service"


class SummarizeFinancialEntriesTests(unittest.TestCase):
    def _summarize(self, rows):
        session, filters = MagicMock(), FinancialEntryFilters()
        with patch(f"{MODULE}.financial_entries_repository") as repository:
            repository.summarize_financial_entries.return_value = rows
            summary = summarize_financial_entries(session, filters)
        repository.summarize_financial_entries.assert_called_once_with(session, filters)
        return summary

    def test_maps_each_type_and_status_to_its_total_and_count(self):
        summary = self._summarize([
            ("EXPENSES", "PLANNED", Decimal("100"), 2),
            ("EXPENSES", "RECONCILED", Decimal("50.5"), 1),
            ("EXPENSES", "CANCELLED", Decimal("9"), 1),
            ("REVENUES", "RECONCILED", Decimal("7000"), 1),
        ])

        expenses = summary.expenses
        self.assertEqual((expenses.planned_total, expenses.planned_count), (Decimal("100"), 2))
        self.assertEqual((expenses.reconciled_total, expenses.reconciled_count), (Decimal("50.5"), 1))
        self.assertEqual((expenses.cancelled_total, expenses.cancelled_count), (Decimal("9"), 1))
        self.assertEqual(summary.revenues.reconciled_total, Decimal("7000"))
        self.assertEqual(summary.revenues.planned_count, 0)

    def test_no_entries_is_all_zero(self):
        summary = self._summarize([])

        for totals in (summary.revenues, summary.expenses):
            self.assertEqual(totals.planned_total, Decimal("0.00"))
            self.assertEqual(totals.reconciled_count, 0)

    def test_unknown_type_or_status_is_ignored(self):
        summary = self._summarize([
            ("OTHER", "PLANNED", Decimal("1"), 1),
            ("EXPENSES", "WEIRD", Decimal("1"), 1),
        ])

        self.assertEqual(summary.expenses.planned_total, Decimal("0.00"))
        self.assertEqual(summary.revenues.planned_total, Decimal("0.00"))

    def test_each_summary_has_its_own_totals(self):
        first = self._summarize([("EXPENSES", "PLANNED", Decimal("1"), 1)])
        second = self._summarize([])

        self.assertIsNot(first.expenses, second.expenses)
        self.assertEqual(second.expenses.planned_total, Decimal("0.00"))


if __name__ == "__main__":
    unittest.main()


class TotalsAndCountsOfThePeriodTests(unittest.TestCase):
    HOUSEHOLD = uuid.UUID("00000000-0000-0000-0000-00000000c001")

    def _run(self, function, repository_function, answers):
        """Runs `function` with the repository answering `answers` (one per call, in order)."""
        session = MagicMock()
        filters = FinancialEntryFilters(household_id=self.HOUSEHOLD, type="EXPENSES")
        with patch(f"{MODULE}.financial_entries_repository") as repository:
            getattr(repository, repository_function).side_effect = answers
            result = function(session, filters)
        calls = getattr(repository, repository_function).call_args_list
        return result, [c.args[1] for c in calls], filters

    def test_total_reconciled_sums_only_the_reconciled_entries(self):
        total, sent, _ = self._run(
            get_total_reconciled, "sum_financial_entries_amount", [Decimal("700.50")]
        )

        self.assertEqual(total, Decimal("700.50"))
        self.assertEqual([f.status for f in sent], ["RECONCILED"])

    def test_total_not_reconciled_sums_only_the_planned_entries(self):
        total, sent, _ = self._run(
            get_total_not_reconciled, "sum_financial_entries_amount", [Decimal("300")]
        )

        self.assertEqual(total, Decimal("300"))
        self.assertEqual([f.status for f in sent], ["PLANNED"])

    def test_total_planned_is_reconciled_plus_not_reconciled(self):
        total, sent, _ = self._run(
            get_total_planned,
            "sum_financial_entries_amount",
            [Decimal("700.50"), Decimal("299.50")],
        )

        self.assertEqual(total, Decimal("1000.00"))
        self.assertEqual({f.status for f in sent}, {"RECONCILED", "PLANNED"})

    def test_total_planned_never_asks_for_cancelled_entries(self):
        _, sent, _ = self._run(
            get_total_planned, "sum_financial_entries_amount", [Decimal("1"), Decimal("1")]
        )

        self.assertNotIn("CANCELLED", [f.status for f in sent])
        self.assertEqual(len(sent), 2)

    def test_total_planned_without_entries_is_zero(self):
        total, _, _ = self._run(
            get_total_planned, "sum_financial_entries_amount", [Decimal("0.00"), Decimal("0.00")]
        )

        self.assertEqual(total, Decimal("0.00"))

    def test_the_other_filters_are_kept_and_the_callers_filters_are_not_changed(self):
        _, sent, filters = self._run(
            get_total_reconciled, "sum_financial_entries_amount", [Decimal("1")]
        )

        self.assertEqual((sent[0].household_id, sent[0].type), (self.HOUSEHOLD, "EXPENSES"))
        self.assertIsNone(filters.status)

    def test_count_reconciled_counts_only_the_reconciled_entries(self):
        count, sent, _ = self._run(count_reconciled_entries, "count_financial_entries", [4])

        self.assertEqual(count, 4)
        self.assertEqual([f.status for f in sent], ["RECONCILED"])

    def test_count_not_reconciled_counts_only_the_planned_entries(self):
        count, sent, filters = self._run(
            count_not_reconciled_entries, "count_financial_entries", [0]
        )

        self.assertEqual(count, 0)
        self.assertEqual([f.status for f in sent], ["PLANNED"])
        self.assertIsNone(filters.status)


class ListUpcomingEntriesTests(unittest.TestCase):
    def _run(self, rows):
        session = MagicMock()
        filters = FinancialEntryFilters(
            household_id=uuid.UUID("00000000-0000-0000-0000-00000000c001")
        )
        with patch(f"{MODULE}.financial_entries_repository") as repository:
            repository.list_financial_entries_by_due_date.return_value = rows
            result = list_upcoming_entries(session, filters)
        return result, repository.list_financial_entries_by_due_date.call_args, filters

    def test_asks_only_for_the_entries_not_reconciled_yet(self):
        _, call, filters = self._run([])

        self.assertEqual(call.args[1].status, "PLANNED")
        self.assertEqual(call.args[1].household_id, filters.household_id)
        self.assertIsNone(filters.status)

    def test_keeps_the_order_of_the_repository(self):
        from tests.factories import make_entry

        first = make_entry(description="Rent")
        second = make_entry(description="Internet")

        result, _, _ = self._run([first, second])

        self.assertEqual([e.description for e in result], ["Rent", "Internet"])

    def test_without_entries_the_list_is_empty(self):
        result, _, _ = self._run([])

        self.assertEqual(result, [])


def _as_model(entry):
    """What the repository returns: an object with the columns of the entry."""
    import dataclasses
    from types import SimpleNamespace

    return SimpleNamespace(**{f.name: getattr(entry, f.name) for f in dataclasses.fields(entry)})


class GetFinancialEntryTests(unittest.TestCase):
    def test_returns_the_entry_of_the_household(self):
        entry = make_entry()
        with patch(f"{MODULE}.financial_entries_repository") as repository:
            repository.get_financial_entry.return_value = _as_model(entry)
            result = get_financial_entry(MagicMock(), HOUSEHOLD_ID, entry.id)

        self.assertEqual(result, entry)
        self.assertEqual(repository.get_financial_entry.call_args.args[1:], (entry.id, HOUSEHOLD_ID))

    def test_an_entry_outside_the_household_is_not_found(self):
        with patch(f"{MODULE}.financial_entries_repository") as repository:
            repository.get_financial_entry.return_value = None
            with self.assertRaises(NotFoundError):
                get_financial_entry(MagicMock(), HOUSEHOLD_ID, uuid.uuid4())


class CreateFinancialEntryTests(unittest.TestCase):
    def test_stores_the_entry_and_returns_it(self):
        entry = make_entry(id=None)
        with patch(f"{MODULE}.financial_entries_repository") as repository:
            repository.create_financial_entry.side_effect = lambda session, values: _as_model(
                make_entry(**{**values, "id": uuid.uuid4()})
            )
            result = create_financial_entry(MagicMock(), entry)

        values = repository.create_financial_entry.call_args.args[1]
        self.assertNotIn("id", values)
        self.assertEqual(values["description"], entry.description)
        self.assertIsNotNone(result.id)

    def test_a_bank_account_of_another_household_is_invalid_data(self):
        entry = make_entry(id=None, bank_account_id=uuid.uuid4())
        with (
            patch(f"{MODULE}.financial_entries_repository") as repository,
            patch(f"{MODULE}.bank_account_repository") as accounts,
        ):
            accounts.get_bank_account_with_owner.return_value = None
            with self.assertRaises(InvalidDataError):
                create_financial_entry(MagicMock(), entry)

        repository.create_financial_entry.assert_not_called()

    def test_a_bank_account_of_the_household_is_accepted(self):
        entry = make_entry(id=None, bank_account_id=uuid.uuid4())
        with (
            patch(f"{MODULE}.financial_entries_repository") as repository,
            patch(f"{MODULE}.bank_account_repository") as accounts,
        ):
            accounts.get_bank_account_with_owner.return_value = (MagicMock(), uuid.uuid4())
            repository.create_financial_entry.return_value = _as_model(make_entry())
            create_financial_entry(MagicMock(), entry)

        repository.create_financial_entry.assert_called_once()


class UpdateFinancialEntryTests(unittest.TestCase):
    def _update(self, stored, values):
        with patch(f"{MODULE}.financial_entries_repository") as repository:
            repository.get_financial_entry.return_value = _as_model(stored)
            repository.update_financial_entry.side_effect = lambda session, model, vals: _as_model(
                make_entry(**{**vars(model), **vals})
            )
            result = update_financial_entry(MagicMock(), HOUSEHOLD_ID, stored.id, values)
        return result, repository

    def test_writes_only_the_given_values(self):
        stored = make_entry()

        result, repository = self._update(stored, {"notes": "new"})

        self.assertEqual(repository.update_financial_entry.call_args.args[2], {"notes": "new"})
        self.assertEqual(result.notes, "new")

    def test_an_entry_outside_the_household_is_not_found(self):
        with patch(f"{MODULE}.financial_entries_repository") as repository:
            repository.get_financial_entry.return_value = None
            with self.assertRaises(NotFoundError):
                update_financial_entry(MagicMock(), HOUSEHOLD_ID, uuid.uuid4(), {"notes": "x"})

    def test_a_reconciled_entry_cannot_change_amount_type_month_or_status(self):
        stored = make_entry(status="RECONCILED")
        for values in (
            {"amount": Decimal("1")},
            {"type": "REVENUES"},
            {"status": "CANCELLED"},
            {"reference_month": datetime.date(2027, 1, 1)},
        ):
            with self.assertRaises(InvalidDataError, msg=values):
                self._update(stored, values)

    def test_a_reconciled_entry_accepts_the_locked_fields_with_the_same_value(self):
        stored = make_entry(status="RECONCILED")

        result, _ = self._update(
            stored,
            {"amount": stored.amount, "type": stored.type, "notes": "n"},
        )

        self.assertEqual(result.notes, "n")

    def test_a_reconciled_entry_can_still_change_its_notes_and_category(self):
        stored = make_entry(status="RECONCILED")

        result, _ = self._update(stored, {"notes": "n", "category": "Moradia"})

        self.assertEqual((result.notes, result.category), ("n", "Moradia"))

    def test_installments_must_stay_together_after_the_change(self):
        stored = make_entry(installment_number=1, installment_total=3)

        with self.assertRaises(InvalidDataError):
            self._update(stored, {"installment_total": None})

    def test_the_total_of_installments_cannot_be_below_the_number(self):
        stored = make_entry(installment_number=2, installment_total=3)

        with self.assertRaises(InvalidDataError):
            self._update(stored, {"installment_total": 1})


class DeleteFinancialEntryTests(unittest.TestCase):
    def test_soft_deletes_a_planned_entry(self):
        stored = make_entry()
        model = _as_model(stored)
        with patch(f"{MODULE}.financial_entries_repository") as repository:
            repository.get_financial_entry.return_value = model
            delete_financial_entry(MagicMock(), HOUSEHOLD_ID, stored.id)

        repository.soft_delete_financial_entry.assert_called_once()
        self.assertIs(repository.soft_delete_financial_entry.call_args.args[1], model)

    def test_a_reconciled_entry_is_not_deleted(self):
        stored = make_entry(status="RECONCILED")
        with patch(f"{MODULE}.financial_entries_repository") as repository:
            repository.get_financial_entry.return_value = _as_model(stored)
            with self.assertRaises(InvalidDataError):
                delete_financial_entry(MagicMock(), HOUSEHOLD_ID, stored.id)

        repository.soft_delete_financial_entry.assert_not_called()

    def test_an_entry_outside_the_household_is_not_found(self):
        with patch(f"{MODULE}.financial_entries_repository") as repository:
            repository.get_financial_entry.return_value = None
            with self.assertRaises(NotFoundError):
                delete_financial_entry(MagicMock(), HOUSEHOLD_ID, uuid.uuid4())


class ListProvisionedRecurrenceIdsTests(unittest.TestCase):
    def test_returns_the_recurrences_the_repository_finds_in_the_month(self):
        session, month = MagicMock(), datetime.date(2026, 12, 1)
        found = {uuid.uuid4(), uuid.uuid4()}
        with patch(f"{MODULE}.financial_entries_repository") as repository:
            repository.list_recurrence_ids_in_month.return_value = found
            result = list_provisioned_recurrence_ids(session, HOUSEHOLD_ID, month)

        self.assertEqual(result, found)
        repository.list_recurrence_ids_in_month.assert_called_once_with(
            session, HOUSEHOLD_ID, month
        )
