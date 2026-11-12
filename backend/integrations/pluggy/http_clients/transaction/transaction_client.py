from datetime import datetime

import httpx

from integrations.pluggy.config import base_url
from integrations.pluggy.http_clients._http import (
    api_key_headers,
    drop_none,
    raise_for_pluggy_error,
)
from integrations.pluggy.schemas.base_response_schema import (
    BaseResponseV2Schema,
)
from integrations.pluggy.schemas.transaction.transaction_response_schema import (
    TransactionResponseSchema,
)


def get_all_transactions(
    api_key: str,
    account_id: str,
    ids: list[str] | None = None,
    date_from: str | datetime | None = None,
    date_to: str | datetime | None = None,
    created_at_from: str | datetime | None = None,
    next: str | None = None,
) -> BaseResponseV2Schema:
    """
    Get the transactions of an account.

    Parameters:
        api_key: The authorization API Key
        account_id: Primary ID of the account (UUID). Required.
        ids: List of transaction IDs (UUIDs). Maximum of 500 IDs per request.
        date_from: Only return transactions with a date on or after this date.
            Format: yyyy-mm-dd. Cannot be used together with `created_at_from`.
        date_to: Only return transactions with a date on or before this date.
            Format: yyyy-mm-dd.
        created_at_from: Only return transactions created on or after this date.
            Format: yyyy-mm-ddThh:mm:ss.000Z.
        after: Cursor for the next page of results. Ready-to-use
        query string for the next page: append it as-is to
        the endpoint path (GET /v2/transactions{next}). Null if there are no more results..
    """
    params = {
        "accountId": account_id,
        "ids": ",".join(ids) if ids else None,
        "dateFrom": _to_str(date_from),
        "dateTo": _to_str(date_to),
        "createdAtFrom": _to_str(created_at_from),
    }
    params = drop_none(params)

    # `next` is a ready-to-use query string that already carries the filters and the cursor.
    # httpx replaces the URL's query string with `params`, so passing both would drop the cursor
    # (every page would be the first one again).
    response = httpx.get(
        f"{base_url}/v2/transactions{next}" if next else f"{base_url}/v2/transactions",
        params=None if next else params,
        headers=api_key_headers(api_key),
    )
    raise_for_pluggy_error(response)

    return BaseResponseV2Schema[TransactionResponseSchema].model_validate(
        response.json()
    )


def _to_str(value: str | datetime | None) -> str | None:
    if value is None or isinstance(value, str):
        return value
    if isinstance(value, datetime):
        return value.isoformat()
    return value.isoformat()  # date -> yyyy-mm-dd
