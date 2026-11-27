import datetime
import uuid

from sqlalchemy import delete, select, update
from sqlalchemy.orm import Session

from infra.database.models import RefreshTokens
from infra.repositories.common.exceptions import (
    RecordNotFoundError,
    translate_db_errors,
)


@translate_db_errors("refresh_tokens")
def create_refresh_token(
    session: Session,
    user_id: uuid.UUID,
    token_hash: str,
    expires_at: datetime.datetime,
) -> RefreshTokens:
    token = RefreshTokens(
        user_id=user_id, token_hash=token_hash, expires_at=expires_at
    )
    session.add(token)
    session.flush()
    return token


@translate_db_errors("refresh_tokens")
def get_refresh_token_by_hash(
    session: Session, token_hash: str
) -> RefreshTokens | None:
    """Locks the row (`FOR UPDATE`): two requests with the same token cannot both rotate it."""
    stmt = (
        select(RefreshTokens)
        .where(RefreshTokens.token_hash == token_hash)
        .with_for_update()
    )
    return session.scalars(stmt).one_or_none()


@translate_db_errors("refresh_tokens")
def revoke_refresh_token(
    session: Session,
    token_id: uuid.UUID,
    revoked_at: datetime.datetime,
    replaced_by_id: uuid.UUID | None = None,
) -> RefreshTokens:
    token = session.get(RefreshTokens, token_id)
    if token is None:
        raise RecordNotFoundError("refresh_tokens", "revoke_refresh_token")
    token.revoked_at = revoked_at
    token.replaced_by_id = replaced_by_id
    session.flush()
    return token


@translate_db_errors("refresh_tokens")
def revoke_all_user_refresh_tokens(
    session: Session, user_id: uuid.UUID, revoked_at: datetime.datetime
) -> None:
    """Revokes every token of the user that is still valid."""
    stmt = (
        update(RefreshTokens)
        .where(RefreshTokens.user_id == user_id, RefreshTokens.revoked_at.is_(None))
        .values(revoked_at=revoked_at)
    )
    session.execute(stmt)


@translate_db_errors("refresh_tokens")
def delete_expired_refresh_tokens(session: Session, now: datetime.datetime) -> None:
    session.execute(delete(RefreshTokens).where(RefreshTokens.expires_at < now))
