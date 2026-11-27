import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy.orm import Session

from domain.entities import RefreshToken
from infra.repositories import refresh_tokens_repository
from infra.security.refresh_tokens import generate_refresh_token, hash_refresh_token
from services.common.exceptions import (
    InvalidRefreshTokenError,
    translate_repository_errors,
)
from services.common.mappers import to_entity, to_entity_or_none
from settings import settings


def _find(session: Session, raw_token: str) -> RefreshToken | None:
    """The stored token for the one the app sent, locked for update."""
    stored = refresh_tokens_repository.get_refresh_token_by_hash(
        session, hash_refresh_token(raw_token)
    )
    return to_entity_or_none(RefreshToken, stored)


def _store_new_token(
    session: Session, user_id: uuid.UUID, now: datetime
) -> tuple[RefreshToken, str]:
    """Creates a refresh token. Returns the stored row and the token to give to the app."""
    # Old rows go away here, so the table does not grow forever
    refresh_tokens_repository.delete_expired_refresh_tokens(session, now)
    raw_token = generate_refresh_token()
    stored = refresh_tokens_repository.create_refresh_token(
        session,
        user_id,
        hash_refresh_token(raw_token),
        now + timedelta(days=settings.refresh_token_expire_days),
    )
    return to_entity(RefreshToken, stored), raw_token


@translate_repository_errors
def issue_refresh_token(session: Session, user_id: uuid.UUID) -> str:
    """A new refresh token for the user (login). Does not commit."""
    _, raw_token = _store_new_token(session, user_id, datetime.now(UTC))
    return raw_token


@translate_repository_errors
def rotate_refresh_token(session: Session, raw_token: str) -> tuple[uuid.UUID, str]:
    """Swaps a valid refresh token for a new one. Returns the user id and the new token.

    The old token stops working. If a token that was already swapped is sent again, it was
    probably stolen, so every token of that user is revoked. In that case the caller must
    commit the session before answering, or the revocation is lost. Does not commit.

    Raises InvalidRefreshTokenError when the token is unknown, expired, revoked or reused.
    """
    now = datetime.now(UTC)
    stored = _find(session, raw_token)
    if stored is None:
        raise InvalidRefreshTokenError("Unknown refresh token")
    if stored.revoked_at is not None:
        # A logout revokes without a replacement: that one is only invalid, not a theft sign
        if stored.replaced_by_id is not None:
            refresh_tokens_repository.revoke_all_user_refresh_tokens(
                session, stored.user_id, now
            )
        raise InvalidRefreshTokenError("Refresh token already used or revoked")
    if stored.expires_at <= now:
        raise InvalidRefreshTokenError("Refresh token expired")

    user_id = stored.user_id
    replacement, new_raw_token = _store_new_token(session, user_id, now)
    refresh_tokens_repository.revoke_refresh_token(
        session, stored.id, now, replaced_by_id=replacement.id
    )
    return user_id, new_raw_token


@translate_repository_errors
def revoke_refresh_token(session: Session, raw_token: str) -> None:
    """Logout: the token stops working. An unknown or already revoked token is ignored. Does not commit."""
    stored = _find(session, raw_token)
    if stored is None or stored.revoked_at is not None:
        return
    refresh_tokens_repository.revoke_refresh_token(
        session, stored.id, datetime.now(UTC)
    )
