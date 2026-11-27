from datetime import timedelta
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from infra.database.session import get_db
from infra.security.jwt_tokens import create_access_token
from infra.security.password_hasher import get_password_hash, verify_password
from presentation.schemas.auth_schemas import LoginRequest, RefreshRequest, Token
from services.auth_service import (
    issue_refresh_token,
    revoke_refresh_token,
    rotate_refresh_token,
)
from services.common.exceptions import InvalidRefreshTokenError
from services.users_service import get_user_by_email
from settings import settings

router = APIRouter(prefix="/auth", tags=["auth"])

# Verified when the e-mail is unknown, so both failures cost about the same time.
_DUMMY_HASH = get_password_hash("dummy-password")


def _access_token(user_id) -> str:
    return create_access_token(
        {"sub": str(user_id)},
        timedelta(minutes=settings.access_token_expire_minutes),
    )


@router.post("/login", response_model=Token)
def login(body: LoginRequest, session: Annotated[Session, Depends(get_db)]) -> Token:
    user = get_user_by_email(session, body.email.lower())
    hashed = user.hashed_password if user else _DUMMY_HASH
    password_ok = verify_password(body.password, hashed)
    if user is None or not password_ok:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect e-mail or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    refresh_token = issue_refresh_token(session, user.id)
    session.commit()
    return Token(
        access_token=_access_token(user.id),
        token_type="bearer",
        refresh_token=refresh_token,
    )


@router.post("/refresh", response_model=Token)
def refresh(
    body: RefreshRequest, session: Annotated[Session, Depends(get_db)]
) -> Token:
    """Swaps a refresh token for a new access token and a new refresh token."""
    try:
        user_id, refresh_token = rotate_refresh_token(session, body.refresh_token)
    except InvalidRefreshTokenError:
        # Saves the revocation of every token when a used token was sent again
        session.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    session.commit()
    return Token(
        access_token=_access_token(user_id),
        token_type="bearer",
        refresh_token=refresh_token,
    )


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(
    body: RefreshRequest, session: Annotated[Session, Depends(get_db)]
) -> Response:
    """Revokes the refresh token. Needs no access token, which may already be expired."""
    revoke_refresh_token(session, body.refresh_token)
    session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
