import datetime
import unittest
import uuid
from decimal import Decimal

from domain.recurrence_provisioning import build_entry, due_date_for
from tests.factories import HOUSEHOLD_ID, USER_ID, make_recurrence

NOVEMBER = datetime.date(2026, 11, 1)
FALLBACK_USER_ID = uuid.UUID("00000000-0000-0000-0000-00000000b002")


class DueDateForTests(unittest.TestCase):
    def test_no_due_day_has_no_due_date(self):
        self.assertIsNone(due_date_for(NOVEMBER, None))

    def test_due_day_inside_the_month(self):
        self.assertEqual(due_date_for(NOVEMBER, 10), datetime.date(2026, 11, 10))

    def test_day_31_in_a_30_day_month_is_the_last_day(self):
        self.assertEqual(due_date_for(NOVEMBER, 31), datetime.date(2026, 11, 30))

    def test_day_31_in_february_is_the_last_day(self):
        self.assertEqual(
            due_date_for(datetime.date(2026, 2, 1), 31), datetime.date(2026, 2, 28)
        )

    def test_day_29_in_february_of_a_leap_year_is_kept(self):
        self.assertEqual(
            due_date_for(datetime.date(2028, 2, 1), 29), datetime.date(2028, 2, 29)
        )


class BuildEntryTests(unittest.TestCase):
    def test_entry_copies_the_recurrence_fields(self):
        recurrence = make_recurrence(
            description="Internet",
            notes="Fiber plan",
            category="Home",
            type="EXPENSES",
            payment_type="DEBIT",
            amount=Decimal("99.90"),
            currency_code="BRL",
            due_day=5,
        )

        entry = build_entry(recurrence, NOVEMBER, FALLBACK_USER_ID)

        self.assertEqual(entry.recurrence_id, recurrence.id)
        self.assertEqual(entry.household_id, HOUSEHOLD_ID)
        self.assertEqual(entry.user_id, USER_ID)
        self.assertEqual(entry.description, "Internet")
        self.assertEqual(entry.notes, "Fiber plan")
        self.assertEqual(entry.category, "Home")
        self.assertEqual(entry.type, "EXPENSES")
        self.assertEqual(entry.payment_type, "DEBIT")
        self.assertEqual(entry.amount, Decimal("99.90"))
        self.assertEqual(entry.currency_code, "BRL")
        self.assertEqual(entry.reference_month, NOVEMBER)
        self.assertEqual(entry.due_date, datetime.date(2026, 11, 5))

    def test_new_entry_is_planned_and_has_no_id_yet(self):
        entry = build_entry(make_recurrence(), NOVEMBER, FALLBACK_USER_ID)

        self.assertEqual(entry.status, "PLANNED")
        self.assertIsNone(entry.id)
        self.assertIsNone(entry.bank_account_id)

    def test_recurrence_without_user_gives_the_entry_to_the_fallback_user(self):
        entry = build_entry(make_recurrence(user_id=None), NOVEMBER, FALLBACK_USER_ID)

        self.assertEqual(entry.user_id, FALLBACK_USER_ID)

    def test_recurrence_without_due_day_gives_an_entry_without_due_date(self):
        entry = build_entry(make_recurrence(due_day=None), NOVEMBER, FALLBACK_USER_ID)

        self.assertIsNone(entry.due_date)

    def test_recurrence_without_id_is_rejected(self):
        with self.assertRaises(ValueError):
            build_entry(make_recurrence(id=None), NOVEMBER, FALLBACK_USER_ID)


if __name__ == "__main__":
    unittest.main()
