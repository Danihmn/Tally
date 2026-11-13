"""Date helpers shared by every layer. Everything is in UTC, like the database columns."""

import datetime
from zoneinfo import ZoneInfo

_LOCAL_TIMEZONE = ZoneInfo("America/Sao_Paulo")


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


def today_local() -> datetime.date:
    """Today where the couple lives. Near midnight it differs from `today_utc()`."""
    return datetime.datetime.now(_LOCAL_TIMEZONE).date()


def to_local_date(moment: datetime.datetime) -> datetime.date:
    """The day of `moment` where the couple lives (a 22h Pix is already tomorrow in UTC)."""
    return moment.astimezone(_LOCAL_TIMEZONE).date()


def default_analysis_period(today: datetime.date) -> tuple[datetime.date, datetime.date]:
    """Day 1 of the month until yesterday (both inclusive).

    On day 1 yesterday is in the previous month, so the whole previous month is used.
    """
    if today.day > 1:
        return first_day_of_month(today), today - datetime.timedelta(days=1)
    last_day = today - datetime.timedelta(days=1)
    return first_day_of_month(last_day), last_day
