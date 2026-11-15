import uuid
from functools import wraps
from typing import Any

from sqlalchemy.orm import Session

from domain.entities import User
from infra.repositories import users_repository
from infra.security.encryption import encrypt
from services.common.exceptions import (
    AlreadyExistsError,
    EmailAlreadyExistsError,
    NotFoundError,
    translate_repository_errors,
)
from services.common.mappers import to_entities, to_entity, to_entity_or_none


def _email_taken_is_explicit(func):
    """The only unique column a user can set is the e-mail, so a duplicate means
    "e-mail already used". Lets the app say so instead of a generic conflict."""

    @wraps(func)
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except AlreadyExistsError as exc:
            raise EmailAlreadyExistsError(str(exc)) from exc

    return wrapper


def _load_user(session: Session, household_id: uuid.UUID, user_id: uuid.UUID):
    """The stored user of the household. Another household's one is "not found"."""
    user = users_repository.get_user_in_household(session, user_id, household_id)
    if user is None:
        raise NotFoundError("User not found")
    return user


@translate_repository_errors
def get_user_by_id(session: Session, user_id: uuid.UUID) -> User:
    return to_entity(User, users_repository.get_user_by_id(session, user_id))


@translate_repository_errors
def get_user_by_email(session: Session, email: str) -> User | None:
    user = users_repository.get_user_by_email(session, email)
    return to_entity_or_none(User, user)


@translate_repository_errors
def get_user_by_webhook_secret_hash(session: Session, secret_hash: str) -> User | None:
    user = users_repository.get_user_by_pluggy_webhook_secret_hash(session, secret_hash)
    return to_entity_or_none(User, user)


@translate_repository_errors
def list_users(session: Session, limit: int = 10, offset: int = 0) -> list[User]:
    users = users_repository.list_users(session, limit=limit, offset=offset)
    return to_entities(User, users)


@translate_repository_errors
def list_users_by_household(session: Session, household_id: uuid.UUID) -> list[User]:
    users = users_repository.list_users_by_household(session, household_id)
    return to_entities(User, users)


@translate_repository_errors
def get_household_user(
    session: Session, household_id: uuid.UUID, user_id: uuid.UUID
) -> User:
    return to_entity(User, _load_user(session, household_id, user_id))


@_email_taken_is_explicit
@translate_repository_errors
def create_user(session: Session, user: User) -> User:
    created = users_repository.create_user(
        session,
        first_name=user.first_name,
        last_name=user.last_name,
        surname=user.surname,
        email=user.email,
        hashed_password=user.hashed_password,
        pluggy_client_id=user.pluggy_client_id,
        pluggy_client_secret_crypto=user.pluggy_client_secret_crypto,
        household_id=user.household_id,
    )
    return to_entity(User, created)


@translate_repository_errors
def update_user_webhook_secret_hash(
    session: Session, user_id: uuid.UUID, secret_hash: str
) -> User:
    user = users_repository.update_user_pluggy_webhook_secret_hash(
        session, user_id, secret_hash
    )
    return to_entity(User, user)


@_email_taken_is_explicit
@translate_repository_errors
def update_user(
    session: Session,
    household_id: uuid.UUID,
    user_id: uuid.UUID,
    values: dict[str, Any],
) -> User:
    """Edits the name, nickname and e-mail of a user of the household."""
    values = dict(values)
    if values.get("email") is not None:
        values["email"] = values["email"].lower()
    stored = _load_user(session, household_id, user_id)
    return to_entity(User, users_repository.update_user(session, stored, values))


@translate_repository_errors
def update_user_pluggy_credentials(
    session: Session,
    household_id: uuid.UUID,
    user_id: uuid.UUID,
    client_id: uuid.UUID,
    client_secret: str,
) -> None:
    """Replaces the Pluggy credentials. The webhook secret is cleared: it belonged
    to the old Pluggy application, so the next registration makes a new one."""
    stored = _load_user(session, household_id, user_id)
    users_repository.update_user(
        session,
        stored,
        {
            "pluggy_client_id": client_id,
            "pluggy_client_secret_crypto": encrypt(client_secret),
            "pluggy_webhook_secret_hash": None,
        },
    )
