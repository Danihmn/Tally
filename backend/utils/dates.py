"""Date helpers shared by every layer. Everything is in UTC, like the database columns."""

import datetime


def utcnow() -> datetime.datetime:
    return datetime.datetime.now(datetime.UTC)


def today_utc() -> datetime.date:
    return utcnow().date()


def start_of_day_utc(day: datetime.date) -> datetime.datetime:
    return datetime.datetime.combine(day, datetime.time.min, tzinfo=datetime.UTC)


def end_of_day_utc(day: datetime.date) -> datetime.datetime:
    """Exclusive upper bound that includes the whole `day` (the next UTC midnight)."""
    return start_of_day_utc(day + datetime.timedelta(days=1))


def first_day_of_month(day: datetime.date) -> datetime.date:
    return day.replace(day=1)
