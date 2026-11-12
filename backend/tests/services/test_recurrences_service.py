import datetime
import unittest
import uuid
from unittest.mock import MagicMock, patch

from services.recurrences_service import provision_entries_from_recurrences
from tests.factories import HOUSEHOLD_ID, make_entry, make_recurrence

MODULE = "services.recurrences_service"
NOVEMBER = datetime.date(2026, 11, 1)
FALLBACK_USER_ID = uuid.UUID("00000000-0000-0000-0000-00000000b002")


class ProvisionEntriesFromRecurrencesTests(unittest.TestCase):
    def setUp(self):
        self.session = MagicMock()
        self.mocks = {}
        for name in (
            "list_recurrences_by_household",
            "list_financial_entries_by_household",
            "create_financial_entry",
        ):
            patcher = patch(f"{MODULE}.{name}")
            self.mocks[name] = patcher.start()
            self.addCleanup(patcher.stop)
        self.mocks["list_financial_entries_by_household"].return_value = []
        # The created entry comes back from the database with an id
        self.mocks["create_financial_entry"].side_effect = lambda session, entry: (
            make_entry(
                recurrence_id=entry.recurrence_id,
                reference_month=entry.reference_month,
                description=entry.description,
            )
        )

    def _provision(self, recurrences, month=NOVEMBER):
        self.mocks["list_recurrences_by_household"].return_value = recurrences
        return provision_entries_from_recurrences(
            self.session, HOUSEHOLD_ID, month, FALLBACK_USER_ID
        )

    def _created_entries(self):
        return [c.args[1] for c in self.mocks["create_financial_entry"].call_args_list]

    def test_creates_an_entry_for_each_recurrence_without_one_in_the_month(self):
        rent, internet = make_recurrence(), make_recurrence(description="Internet")

        result = self._provision([rent, internet])

        self.assertEqual(
            [e.recurrence_id for e in self._created_entries()], [rent.id, internet.id]
        )
        self.assertEqual(len(result.created), 2)
        self.assertEqual(result.skipped_count, 0)
        self.assertEqual(result.reference_month, NOVEMBER)

    def test_recurrence_with_an_entry_in_the_month_is_skipped(self):
        rent, internet = make_recurrence(), make_recurrence(description="Internet")
        self.mocks["list_financial_entries_by_household"].return_value = [
            make_entry(recurrence_id=rent.id)
        ]

        result = self._provision([rent, internet])

        self.assertEqual(
            [e.recurrence_id for e in self._created_entries()], [internet.id]
        )
        self.assertEqual(result.skipped_count, 1)

    def test_cancelled_entry_counts_as_existing(self):
        rent = make_recurrence()
        self.mocks["list_financial_entries_by_household"].return_value = [
            make_entry(recurrence_id=rent.id, status="CANCELLED")
        ]

        result = self._provision([rent])

        self.mocks["create_financial_entry"].assert_not_called()
        self.assertEqual(result.skipped_count, 1)

    def test_entries_not_created_from_a_recurrence_do_not_block_it(self):
        rent = make_recurrence(description="Rent")
        self.mocks["list_financial_entries_by_household"].return_value = [
            make_entry(description="Rent", amount=rent.amount, recurrence_id=None)
        ]

        result = self._provision([rent])

        self.assertEqual(len(result.created), 1)

    def test_no_recurrences_creates_nothing_and_skips_the_entries_query(self):
        result = self._provision([])

        self.assertEqual(result.created, [])
        self.assertEqual(result.skipped_count, 0)
        self.mocks["list_financial_entries_by_household"].assert_not_called()
        self.mocks["create_financial_entry"].assert_not_called()

    def test_looks_for_entries_only_inside_the_month_of_the_household(self):
        self._provision([make_recurrence()], month=datetime.date(2026, 12, 20))

        self.mocks["list_recurrences_by_household"].assert_called_once_with(
            self.session, HOUSEHOLD_ID
        )
        self.mocks["list_financial_entries_by_household"].assert_called_once_with(
            self.session,
            HOUSEHOLD_ID,
            reference_month_from=datetime.date(2026, 12, 1),
            reference_month_to=datetime.date(2027, 1, 1),
        )

    def test_any_day_of_the_month_creates_entries_on_the_first_day(self):
        result = self._provision([make_recurrence()], month=datetime.date(2026, 11, 20))

        self.assertEqual(self._created_entries()[0].reference_month, NOVEMBER)
        self.assertEqual(result.reference_month, NOVEMBER)

    def test_recurrence_without_user_gives_the_entry_to_the_fallback_user(self):
        self._provision([make_recurrence(user_id=None)])

        self.assertEqual(self._created_entries()[0].user_id, FALLBACK_USER_ID)

    def test_does_not_commit(self):
        self._provision([make_recurrence()])

        self.session.commit.assert_not_called()


if __name__ == "__main__":
    unittest.main()
