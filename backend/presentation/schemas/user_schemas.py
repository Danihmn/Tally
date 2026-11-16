from __future__ import annotations

import datetime
import uuid
from typing import Annotated

from pydantic import (
    AfterValidator,
    BaseModel,
    ConfigDict,
    EmailStr,
    Field,
    model_validator,
)


def _blank_to_none(value: str | None) -> str | None:
    """A name left blank is the same as no name."""
    if value is None:
        return None
    value = value.strip()
    return value or None


_FirstName = Annotated[str, Field(min_length=1, max_length=100)]
_LastName = Annotated[
    str | None, Field(max_length=100), AfterValidator(_blank_to_none)
]
_Surname = Annotated[str | None, Field(max_length=50), AfterValidator(_blank_to_none)]


class UserCreate(BaseModel):
    """Body of POST /users. The household is the one of the logged user: a
    `household_id` in the body is refused."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    first_name: _FirstName
    last_name: _LastName = None
    surname: _Surname = None
    email: EmailStr
    password: str = Field(min_length=8)
    pluggy_client_id: uuid.UUID
    pluggy_client_secret: str = Field(min_length=1)


class UserUpdate(BaseModel):
    """Body of PATCH /users/{id}: only the fields sent change. `last_name` and
    `surname` accept `null` to be cleared. The Pluggy credentials and the
    password have their own routes (`/pluggy-credentials` and `/password`)."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    first_name: _FirstName | None = None
    last_name: _LastName = None
    surname: _Surname = None
    email: EmailStr | None = None

    @model_validator(mode="after")
    def _check_fields(self) -> UserUpdate:
        if not self.model_fields_set:
            raise ValueError("send at least one field")
        for name in ("first_name", "email"):
            if name in self.model_fields_set and getattr(self, name) is None:
                raise ValueError(f"{name} cannot be null")
        return self


class UserPluggyCredentialsUpdate(BaseModel):
    """Body of PUT /users/{id}/pluggy-credentials: both values, always."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    pluggy_client_id: uuid.UUID
    pluggy_client_secret: str = Field(min_length=1)


class UserPasswordUpdate(BaseModel):
    """Body of PUT /users/{id}/password: the new password."""

    model_config = ConfigDict(extra="forbid")

    password: str = Field(min_length=8)


class UserResponse(BaseModel):
    """A user as the app sees it. Never the password, the Pluggy credentials or
    the webhook secret."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    first_name: str
    last_name: str | None = None
    surname: str | None = None
    email: str
    household_id: uuid.UUID
    created_at: datetime.datetime
