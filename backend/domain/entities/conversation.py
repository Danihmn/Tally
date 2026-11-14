import datetime
import uuid
from dataclasses import dataclass


@dataclass(slots=True)
class Conversation:
    user_id: uuid.UUID
    id: uuid.UUID | None = None
    title: str | None = None
    total_input_tokens: int = 0
    total_output_tokens: int = 0
    context_tokens: int = 0
    token_limit: int | None = None
    last_message_at: datetime.datetime | None = None
    created_at: datetime.datetime | None = None
    updated_at: datetime.datetime | None = None
    deleted_at: datetime.datetime | None = None
