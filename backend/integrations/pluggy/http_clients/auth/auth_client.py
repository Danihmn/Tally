import httpx

from integrations.pluggy.config import base_url
from integrations.pluggy.http_clients._http import raise_for_pluggy_error


def authenticate(client_id, client_secret) -> str:
    """Returns an apiKey string, or raises PluggyError if status_code is not 200"""
    response = httpx.post(
        f"{base_url}/auth",
        json={"clientId": str(client_id), "clientSecret": client_secret},
    )
    raise_for_pluggy_error(response)

    return response.json()["apiKey"]
