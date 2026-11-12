"""Helpers shared by the Pluggy HTTP clients.

Every Pluggy error has the same body on every endpoint (guide `reference/error-codes`):
{"code": 404, "codeDescription": "ITEM_NOT_FOUND", "message": "Item not found"}.
"""

from typing import Any

import httpx

from integrations.pluggy.exceptions.pluggy_exception_error import PluggyExceptionError
from integrations.pluggy.schemas.base_error_schema import BaseErrorSchema


def api_key_headers(api_key: str) -> dict[str, str]:
    """The authorization header of every call after `POST /auth`."""
    return {"X-API-KEY": api_key}


def drop_none(values: dict[str, Any]) -> dict[str, Any]:
    """Only the given values: Pluggy reads a missing param as "no filter", not None."""
    return {key: value for key, value in values.items() if value is not None}


def raise_for_pluggy_error(response: httpx.Response) -> None:
    """Raises PluggyExceptionError for a Pluggy error body, or httpx.HTTPStatusError when the
    error has no Pluggy body (a proxy or gateway error, for example). Does nothing on success."""
    if not response.is_error:
        return
    try:
        error = BaseErrorSchema.model_validate(response.json())
    except ValueError:
        response.raise_for_status()
        raise
    raise PluggyExceptionError(error)
