import datetime
import unittest
from unittest.mock import patch

from utils.dates import (
    default_analysis_period,
    end_of_day_utc,
    clamp_day_to_month,
    first_day_of_month,
    next_month_start,
    start_of_day_utc,
    today_local,
    to_local_date,
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


class TestTodayLocal(unittest.TestCase):
    def test_uses_the_sao_paulo_day_when_utc_is_already_the_next_day(self):
        # 01:00 UTC on the 14th is 22:00 on the 13th in Sao Paulo
        real_datetime = datetime.datetime
        now_utc = real_datetime(2026, 11, 14, 1, 0, tzinfo=datetime.UTC)

        class FrozenDatetime(real_datetime):
            @classmethod
            def now(cls, tz=None):
                return now_utc.astimezone(tz)

        with patch("utils.dates.datetime.datetime", FrozenDatetime):
            self.assertEqual(today_local(), datetime.date(2026, 11, 13))


class TestDefaultAnalysisPeriod(unittest.TestCase):
    def test_is_day_one_until_yesterday(self):
        self.assertEqual(
            default_analysis_period(datetime.date(2026, 11, 13)),
            (datetime.date(2026, 11, 1), datetime.date(2026, 11, 12)),
        )

    def test_on_day_two_it_is_only_day_one(self):
        self.assertEqual(
            default_analysis_period(datetime.date(2026, 11, 2)),
            (datetime.date(2026, 11, 1), datetime.date(2026, 11, 1)),
        )

    def test_on_day_one_it_is_the_whole_previous_month(self):
        self.assertEqual(
            default_analysis_period(datetime.date(2026, 11, 1)),
            (datetime.date(2026, 10, 1), datetime.date(2026, 10, 31)),
        )

    def test_on_january_first_it_is_the_whole_december(self):
        self.assertEqual(
            default_analysis_period(datetime.date(2027, 1, 1)),
            (datetime.date(2026, 12, 1), datetime.date(2026, 12, 31)),
        )

    def test_on_march_first_it_ends_on_the_last_day_of_february(self):
        self.assertEqual(
            default_analysis_period(datetime.date(2027, 3, 1)),
            (datetime.date(2027, 2, 1), datetime.date(2027, 2, 28)),
        )


class TestToLocalDate(unittest.TestCase):
    def test_a_late_evening_in_brazil_is_already_the_next_day_in_utc_but_stays_the_same_local_day(self):
        moment = datetime.datetime(2026, 11, 11, 1, 30, tzinfo=datetime.UTC)  # 22:30 on the 10th

        self.assertEqual(to_local_date(moment), datetime.date(2026, 11, 10))

    def test_midday_is_the_same_day_everywhere(self):
        moment = datetime.datetime(2026, 11, 10, 15, 0, tzinfo=datetime.UTC)

        self.assertEqual(to_local_date(moment), datetime.date(2026, 11, 10))


class TestNextMonthStart(unittest.TestCase):
    def test_is_day_1_of_the_following_month(self):
        self.assertEqual(next_month_start(datetime.date(2026, 11, 15)), datetime.date(2026, 12, 1))

    def test_december_goes_to_january_of_the_next_year(self):
        self.assertEqual(next_month_start(datetime.date(2026, 12, 31)), datetime.date(2027, 1, 1))

    def test_the_last_day_of_a_month_still_gives_the_following_one(self):
        self.assertEqual(next_month_start(datetime.date(2026, 1, 31)), datetime.date(2026, 2, 1))


class TestClampDayToMonth(unittest.TestCase):
    def test_a_day_inside_the_month_is_kept(self):
        self.assertEqual(
            clamp_day_to_month(datetime.date(2026, 12, 1), 5), datetime.date(2026, 12, 5)
        )

    def test_day_31_in_a_30_day_month_becomes_the_30th(self):
        self.assertEqual(
            clamp_day_to_month(datetime.date(2026, 11, 1), 31), datetime.date(2026, 11, 30)
        )

    def test_day_30_in_february_becomes_the_last_day(self):
        self.assertEqual(
            clamp_day_to_month(datetime.date(2026, 2, 1), 30), datetime.date(2026, 2, 28)
        )
        self.assertEqual(
            clamp_day_to_month(datetime.date(2028, 2, 1), 30), datetime.date(2028, 2, 29)
        )
