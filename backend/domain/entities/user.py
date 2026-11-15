import datetime
import uuid
from dataclasses import dataclass


@dataclass(slots=True)
class User:
    first_name: str
    email: str
    hashed_password: str
    pluggy_client_id: uuid.UUID
    pluggy_client_secret_crypto: str
    household_id: uuid.UUID
    pluggy_webhook_secret_hash: str | None = None
    id: uuid.UUID | None = None
    created_at: datetime.datetime | None = None
    last_name: str | None = None
    surname: str | None = (
        None  # the nickname ("apelido"), shown instead of the first name
    )

    @property
    def display_name(self) -> str:
        """The nickname when there is one, else the first name: how people are named in the app and by the AI."""
        nickname = (self.surname or "").strip()
        return nickname or self.first_name
