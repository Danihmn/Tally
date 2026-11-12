import datetime
from zoneinfo import ZoneInfo

_TIMEZONE = ZoneInfo("America/Sao_Paulo")


def today() -> datetime.date:
    """Today's date where the couple lives (the model has no clock, so the agent tells it)."""
    return datetime.datetime.now(_TIMEZONE).date()
