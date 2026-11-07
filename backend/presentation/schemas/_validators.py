import datetime
import decimal


def check_amount_range(
    min_amount: decimal.Decimal | None, max_amount: decimal.Decimal | None
) -> None:
    if min_amount is not None and max_amount is not None and min_amount > max_amount:
        raise ValueError("min_amount must not be greater than max_amount")


def check_date_range(
    start: datetime.date | None,
    end: datetime.date | None,
    start_name: str,
    end_name: str,
) -> None:
    if start and end and start > end:
        raise ValueError(f"{start_name} must not be after {end_name}")
