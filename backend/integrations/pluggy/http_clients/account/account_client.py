import httpx

from integrations.pluggy.config import base_url
from integrations.pluggy.http_clients._http import (
    api_key_headers,
    drop_none,
    raise_for_pluggy_error,
)
from integrations.pluggy.schemas.account.account_response_schema import (
    AccountResponseSchema,
)
from integrations.pluggy.schemas.base_response_schema import (
    BaseResponseV1Schema,
)


def get_all_accounts(
    api_key: str, item_id: str, type: str | None = None
) -> BaseResponseV1Schema:
    """
    Gets all the accounts for the given 'item_id'

    Parameters:
            api_key: The authorization API Key
            item_id: Primary item's identifier.
            type: Filter between bank accounts and credit accounts ('BANK' or 'CREDIT'). None returns both
    """
    params = {"itemId": item_id, "type": type}
    params = drop_none(params)

    response = httpx.get(
        f"{base_url}/accounts",
        params=params,
        headers=api_key_headers(api_key),
    )
    raise_for_pluggy_error(response)

    return BaseResponseV1Schema[AccountResponseSchema].model_validate(response.json())
