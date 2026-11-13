"""Helpers shared by the background jobs."""

from collections.abc import Iterator

import httpx
from sqlalchemy.orm import Session

from domain.entities import User
from integrations.pluggy.exceptions.pluggy_exception_error import PluggyExceptionError
from services.common.exceptions import ServiceError
from services.users_service import list_users

USERS_PAGE_SIZE = 20

# What a job catches for one user (then rolls back and logs) so the other users still run
JOB_ERRORS = (ServiceError, PluggyExceptionError, httpx.HTTPError, ValueError)


def iter_all_users(
    session: Session, page_size: int = USERS_PAGE_SIZE
) -> Iterator[User]:
    """Every user, loaded one page at a time (the next page is read only when needed)."""
    offset = 0
    while True:
        users = list_users(session=session, limit=page_size, offset=offset)
        if not users:
            return
        yield from users
        offset += page_size
