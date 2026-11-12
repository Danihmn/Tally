import httpx

from integrations.pluggy.config import base_url
from integrations.pluggy.http_clients._http import api_key_headers, raise_for_pluggy_error
from integrations.pluggy.schemas.identity.identity_response_schema import (
    IdentityResponseSchema,
)


def get_identity(api_key: str, item_id: str) -> IdentityResponseSchema:
    """
    Recovers identity of an item if available

    Parameters:
            api_key: The authorization API Key
            item_id: Primary item's identifier.
    """
    response = httpx.get(
        f"{base_url}/identity",
        params={"itemId": item_id},
        headers=api_key_headers(api_key),
    )
    raise_for_pluggy_error(response)

    return IdentityResponseSchema.model_validate(response.json())
