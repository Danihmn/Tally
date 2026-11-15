import uuid
from typing import Annotated

from fastapi import APIRouter, BackgroundTasks, Depends, Query, Response, status
from sqlalchemy.orm import Session

from domain.entities import User
from infra.database.session import get_db
from infra.security.encryption import encrypt
from infra.security.password_hasher import get_password_hash
from jobs.webhook_registration import register_webhooks
from presentation.dependencies.auth import get_current_user
from presentation.schemas.user_schemas import (
    UserCreate,
    UserPluggyCredentialsUpdate,
    UserResponse,
    UserUpdate,
)
from services.users_service import (
    create_user,
    get_household_user,
    list_users_by_household,
    update_user,
    update_user_pluggy_credentials,
)

# The app is private: the people of a household see and edit each other. Every route
# works on the household of the logged user, never on one sent by the client.
router = APIRouter(
    prefix="/users", tags=["users"], dependencies=[Depends(get_current_user)]
)


@router.post("", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def create_user_endpoint(
    background_tasks: BackgroundTasks,
    body: UserCreate,
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> User:
    user = User(
        household_id=current_user.household_id,
        first_name=body.first_name,
        last_name=body.last_name,
        surname=body.surname,
        email=body.email.lower(),
        hashed_password=get_password_hash(body.password),
        pluggy_client_id=body.pluggy_client_id,
        pluggy_client_secret_crypto=encrypt(body.pluggy_client_secret),
    )
    created = create_user(session, user)
    session.commit()
    # The new user's Pluggy application needs its webhooks registered.
    background_tasks.add_task(register_webhooks)
    return created  # Pydantic serializes the 'User' entity into 'UserResponse'


@router.get("/me", response_model=UserResponse)
def get_me_endpoint(current_user: Annotated[User, Depends(get_current_user)]) -> User:
    return current_user


@router.get("", response_model=list[UserResponse])
def list_users_endpoint(
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[User]:
    # A household has a handful of people: the page is cut here, not in the query.
    users = list_users_by_household(session, current_user.household_id)
    return users[offset : offset + limit]


@router.get("/{user_id}", response_model=UserResponse)
def get_user_endpoint(
    user_id: uuid.UUID,
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> User:
    return get_household_user(session, current_user.household_id, user_id)


@router.patch("/{user_id}", response_model=UserResponse)
def update_user_endpoint(
    user_id: uuid.UUID,
    body: UserUpdate,
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> User:
    updated = update_user(
        session,
        current_user.household_id,
        user_id,
        body.model_dump(exclude_unset=True),
    )
    session.commit()
    return updated


@router.put("/{user_id}/pluggy-credentials", status_code=status.HTTP_204_NO_CONTENT)
def update_pluggy_credentials_endpoint(
    background_tasks: BackgroundTasks,
    user_id: uuid.UUID,
    body: UserPluggyCredentialsUpdate,
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> Response:
    update_user_pluggy_credentials(
        session,
        current_user.household_id,
        user_id,
        body.pluggy_client_id,
        body.pluggy_client_secret,
    )
    session.commit()
    # The new Pluggy application has no webhooks of ours yet.
    background_tasks.add_task(register_webhooks)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
