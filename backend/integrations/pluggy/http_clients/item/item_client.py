import httpx

from integrations.pluggy.config import base_url
from integrations.pluggy.http_clients._http import api_key_headers, raise_for_pluggy_error
from integrations.pluggy.schemas.item.item_response_schema import ItemResponseSchema


def get_item(api_key: str, item_id: str) -> ItemResponseSchema:
    """
    Retrieves an item (its consent expiration date included)

    Parameters:
            api_key: The authorization API Key
            item_id: The item's primary identifier
    """
    response = httpx.get(
        f"{base_url}/items/{item_id}",
        headers=api_key_headers(api_key),
    )
    raise_for_pluggy_error(response)

    return ItemResponseSchema.model_validate(response.json())
