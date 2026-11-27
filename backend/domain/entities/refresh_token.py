import datetime
import uuid
from dataclasses import dataclass


@dataclass(slots=True)
class RefreshToken:
    """A stored login refresh token. Holds the hash only, never the token itself."""

    user_id: uuid.UUID
    token_hash: str
    expires_at: datetime.datetime
    id: uuid.UUID | None = None
    created_at: datetime.datetime | None = None
    revoked_at: datetime.datetime | None = None
    # Set when the token was rotated: the one that replaced it. Empty for a logout.
    replaced_by_id: uuid.UUID | None = None
