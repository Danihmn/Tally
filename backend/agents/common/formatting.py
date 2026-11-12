"""Text helpers for the tool results the model reads.

Tool results are plain text tables ("a | b | c"), so every tool writes amounts, dates and empty
values the same way, and the model sees one format everywhere."""

import datetime
import decimal

EMPTY = "-"
PERIOD_DEFAULTED = " (current month, no period was given)"


def money(value: decimal.Decimal | None) -> str:
    """Two decimal places, '.' as the separator (the calculator reads the same format)."""
    return EMPTY if value is None else f"{value:.2f}"


def day(value: datetime.date | datetime.datetime | None) -> str:
    """YYYY-MM-DD. A datetime keeps only its date."""
    if value is None:
        return EMPTY
    if isinstance(value, datetime.datetime):
        value = value.date()
    return value.isoformat()


def month(value: datetime.date) -> str:
    """YYYY-MM."""
    return value.strftime("%Y-%m")


def text(value: str | None) -> str:
    return value or EMPTY


def scope_line(only_mine: bool, noun: str) -> str:
    """Says whose data the result has: "Scope: only the logged user's <noun>" or the household."""
    if only_mine:
        return f"Scope: only the logged user's {noun}"
    return "Scope: the whole household"


def period_note(defaulted: bool) -> str:
    """Added to the period line when the tool used the current month because none was given."""
    return PERIOD_DEFAULTED if defaulted else ""


def clamp_limit(limit: int, max_limit: int) -> int:
    """The model can ask for any number: keep it between 1 and max_limit."""
    return max(1, min(limit, max_limit))
