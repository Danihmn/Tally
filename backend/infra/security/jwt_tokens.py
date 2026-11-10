import uuid
from datetime import UTC, datetime, timedelta

import jwt

from settings import settings


def create_access_token(data: dict, expires_delta: timedelta | None = None):
    """Created the access token and returns it"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(UTC) + expires_delta
    else:
        expire = datetime.now(UTC) + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(
        to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm
    )
    return encoded_jwt


def decode_access_token(token: str) -> uuid.UUID:
    """Returns the user id (`sub`) of a valid token.

    Raises jwt.InvalidTokenError when the token is invalid or expired,
    and ValueError when `sub` is missing or is not a UUID.
    """
    payload = jwt.decode(
        token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm]
    )
    user_id = payload.get("sub")
    if user_id is None:
        raise ValueError("token without sub")
    return uuid.UUID(str(user_id))
