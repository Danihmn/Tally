from domain.entities import User
from infra.security.encryption import decrypt
from integrations.pluggy.http_clients.auth.auth_client import authenticate


def authenticate_user(user: User) -> str:
    """The user's Pluggy apiKey: each person has their own Pluggy application (Meu Pluggy), so
    the login uses their Client ID and their Client Secret (stored encrypted)."""
    return authenticate(
        client_id=user.pluggy_client_id,
        client_secret=decrypt(user.pluggy_client_secret_crypto),
    )
