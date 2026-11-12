"""Money helpers shared by every layer. Money is always a `Decimal`, never a float."""

import decimal

CENTS = decimal.Decimal("0.01")
# Rounding to cents needs room for the integer part too, so the precision is high
_ROUNDING_CONTEXT = decimal.Context(prec=60, rounding=decimal.ROUND_HALF_UP)


def round_to_cents(value: decimal.Decimal) -> decimal.Decimal:
    """Half up, like money is usually rounded. Never '-0.00'."""
    with decimal.localcontext(_ROUNDING_CONTEXT):
        try:
            rounded = value.quantize(CENTS)
        except decimal.InvalidOperation:
            raise ValueError("the result is too large") from None
    return abs(rounded) if rounded == 0 else rounded


def round_to_cents_or_none(value: decimal.Decimal | None) -> decimal.Decimal | None:
    """Same as `round_to_cents`, for optional amounts (None stays None)."""
    return None if value is None else round_to_cents(value)
