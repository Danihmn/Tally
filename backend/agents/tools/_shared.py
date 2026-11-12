"""Helpers shared by the agent tools (the ones that need the services or LangChain)."""

import functools
import uuid
from collections.abc import Callable

from sqlalchemy.orm import Session

from services.users_service import list_users_by_household


def owner_names(session: Session, household_id: uuid.UUID) -> dict[uuid.UUID, str]:
    """First name of each household member, by user id: the tools name owners by first name."""
    return {u.id: u.first_name for u in list_users_by_household(session, household_id)}  # type: ignore[misc]


def tool_errors[**P](func: Callable[P, str]) -> Callable[P, str]:
    """A ValueError (a bad filter from the model) becomes "Error: ..." in the tool result, so the
    model can read it and call the tool again with a fixed value.

    Goes under `@tool`: `functools.wraps` keeps the signature, so the tool schema is the same."""

    @functools.wraps(func)
    def wrapper(*args: P.args, **kwargs: P.kwargs) -> str:
        try:
            return func(*args, **kwargs)
        except ValueError as error:
            return f"Error: {error}"

    return wrapper
