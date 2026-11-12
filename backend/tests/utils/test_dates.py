import datetime
import unittest
from unittest.mock import patch

from utils.dates import (
    end_of_day_utc,
    first_day_of_month,
    start_of_day_utc,
    today_utc,
    utcnow,
)


class TestUtcnow(unittest.TestCase):
    def test_is_timezone_aware_in_utc(self):
        self.assertEqual(utcnow().tzinfo, datetime.UTC)


class TestTodayUtc(unittest.TestCase):
    def test_is_the_date_of_utcnow(self):
        now = datetime.datetime(2026, 11, 10, 23, 30, tzinfo=datetime.UTC)
        with patch("utils.dates.utcnow", return_value=now):
            self.assertEqual(today_utc(), datetime.date(2026, 11, 10))


class TestStartOfDayUtc(unittest.TestCase):
    def test_is_midnight_utc_of_the_day(self):
        self.assertEqual(
            start_of_day_utc(datetime.date(2026, 11, 10)),
            datetime.datetime(2026, 11, 10, tzinfo=datetime.UTC),
        )


class TestEndOfDayUtc(unittest.TestCase):
    def test_is_the_next_midnight_utc(self):
        self.assertEqual(
            end_of_day_utc(datetime.date(2026, 12, 31)),
            datetime.datetime(2027, 1, 1, tzinfo=datetime.UTC),
        )


class TestFirstDayOfMonth(unittest.TestCase):
    def test_moves_the_day_to_one(self):
        self.assertEqual(
            first_day_of_month(datetime.date(2026, 2, 28)), datetime.date(2026, 2, 1)
        )
