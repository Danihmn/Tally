import hashlib
import secrets


def generate_refresh_token() -> str:
    """A random, URL-safe token. It is not a JWT: it means nothing without the database."""
    return secrets.token_urlsafe(48)


def hash_refresh_token(token: str) -> str:
    """SHA-256 hex digest. Fast hashing is fine: the token is random (384 bits), not a password."""
    return hashlib.sha256(token.encode()).hexdigest()
