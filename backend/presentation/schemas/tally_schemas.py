import datetime
import uuid
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class TallyChatRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    message: str = Field(min_length=1, max_length=2000)
    # Empty starts a new conversation; an id continues that one
    conversation_id: uuid.UUID | None = None


class ConversationResponse(BaseModel):
    id: uuid.UUID
    title: str | None
    # Tokens the model reads in this conversation now, against the limit that makes it full
    context_tokens: int
    token_limit: int
    total_input_tokens: int
    total_output_tokens: int
    last_message_at: datetime.datetime | None
    created_at: datetime.datetime


class ChatMessageResponse(BaseModel):
    id: str | None
    role: Literal["user", "assistant"]
    content: str


class ConversationDetailResponse(BaseModel):
    conversation: ConversationResponse
    messages: list[ChatMessageResponse]


# Payloads of the server-sent events of POST /tally/chat (`event: <name>` + `data: <json>`)


class ChatMetaEvent(BaseModel):
    """First event: which conversation this answer belongs to (the new id when it was just created)."""

    conversation_id: uuid.UUID
    title: str | None
    is_new: bool


class ChatTokenEvent(BaseModel):
    """A piece of the answer, in markdown. Append it to the text received so far."""

    text: str


class ChatDoneEvent(BaseModel):
    """Last event of a good answer, with the conversation's usage after it."""

    context_tokens: int
    token_limit: int
    total_input_tokens: int
    total_output_tokens: int


class ChatErrorEvent(BaseModel):
    """Last event of a failed answer. The code never carries internal details."""

    code: Literal["ai_unavailable", "empty_answer"]
