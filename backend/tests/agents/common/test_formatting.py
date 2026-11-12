import datetime
import unittest
from decimal import Decimal

from agents.common.formatting import (
    clamp_limit,
    day,
    money,
    month,
    period_note,
    scope_line,
    text,
)


class TestMoney(unittest.TestCase):
    def test_has_two_decimal_places_with_a_dot(self):
        self.assertEqual(money(Decimal("1234.5")), "1234.50")
        self.assertEqual(money(Decimal("-10")), "-10.00")

    def test_none_is_a_dash(self):
        self.assertEqual(money(None), "-")


class TestDay(unittest.TestCase):
    def test_a_date_is_iso(self):
        self.assertEqual(day(datetime.date(2026, 11, 10)), "2026-11-10")

    def test_a_datetime_keeps_only_its_date(self):
        value = datetime.datetime(2026, 11, 10, 23, 59, tzinfo=datetime.UTC)

        self.assertEqual(day(value), "2026-11-10")

    def test_none_is_a_dash(self):
        self.assertEqual(day(None), "-")


class TestMonth(unittest.TestCase):
    def test_is_year_and_month(self):
        self.assertEqual(month(datetime.date(2026, 3, 1)), "2026-03")


class TestText(unittest.TestCase):
    def test_keeps_the_text(self):
        self.assertEqual(text("Mercado"), "Mercado")

    def test_none_or_empty_is_a_dash(self):
        self.assertEqual(text(None), "-")
        self.assertEqual(text(""), "-")


class TestScopeLine(unittest.TestCase):
    def test_only_mine_names_what_was_read(self):
        self.assertEqual(scope_line(True, "entries"), "Scope: only the logged user's entries")

    def test_household(self):
        self.assertEqual(scope_line(False, "entries"), "Scope: the whole household")


class TestPeriodNote(unittest.TestCase):
    def test_says_when_the_current_month_was_used(self):
        self.assertEqual(period_note(True), " (current month, no period was given)")

    def test_is_empty_when_a_period_was_given(self):
        self.assertEqual(period_note(False), "")


class TestClampLimit(unittest.TestCase):
    def test_keeps_a_limit_inside_the_range(self):
        self.assertEqual(clamp_limit(20, 50), 20)

    def test_caps_at_the_max(self):
        self.assertEqual(clamp_limit(500, 50), 50)

    def test_never_below_one(self):
        self.assertEqual(clamp_limit(0, 50), 1)
        self.assertEqual(clamp_limit(-3, 50), 1)
