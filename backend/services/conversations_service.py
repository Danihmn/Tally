import datetime
import uuid

from sqlalchemy.orm import Session

from domain.entities import Conversation
from infra.repositories import conversations_repository
from services.common.exceptions import translate_repository_errors
from services.common.mappers import to_entities, to_entity
from settings import settings

TITLE_MAX_LENGTH = 60


def _title_from(message: str) -> str:
    """The first question, on one line and short enough for a list row."""
    one_line = " ".join(message.split())
    if len(one_line) <= TITLE_MAX_LENGTH:
        return one_line
    return one_line[: TITLE_MAX_LENGTH - 1].rstrip() + "…"


def token_limit_of(conversation: Conversation) -> int:
    """The conversation's own limit, or the default when the row has none."""
    return conversation.token_limit or settings.conversation_token_limit


def is_limit_reached(conversation: Conversation) -> bool:
    return conversation.context_tokens >= token_limit_of(conversation)


@translate_repository_errors
def get_conversation(
    session: Session, conversation_id: uuid.UUID, user_id: uuid.UUID
) -> Conversation:
    """Another user's conversation raises NotFoundError, same as one that does not exist."""
    return to_entity(
        Conversation,
        conversations_repository.get_conversation_for_user(
            session, conversation_id, user_id
        ),
    )


@translate_repository_errors
def start_conversation(
    session: Session, user_id: uuid.UUID, first_message: str
) -> Conversation:
    return to_entity(
        Conversation,
        conversations_repository.create_conversation(
            session,
            {
                "user_id": user_id,
                "title": _title_from(first_message),
                "token_limit": settings.conversation_token_limit,
            },
        ),
    )


@translate_repository_errors
def list_conversations(
    session: Session, user_id: uuid.UUID, limit: int, offset: int
) -> tuple[list[Conversation], int]:
    """A page of the user's conversations (most recent first) and how many they have."""
    items = to_entities(
        Conversation,
        conversations_repository.list_conversations_by_user(
            session, user_id, limit, offset
        ),
    )
    return items, conversations_repository.count_conversations_by_user(session, user_id)


@translate_repository_errors
def record_turn(
    session: Session,
    conversation_id: uuid.UUID,
    user_id: uuid.UUID,
    input_tokens: int,
    output_tokens: int,
    context_tokens: int,
) -> Conversation:
    """Adds a finished turn: the totals grow, the context size is the one of the last model call."""
    model = conversations_repository.get_conversation_for_user(
        session, conversation_id, user_id
    )
    now = datetime.datetime.now(datetime.UTC)
    return to_entity(
        Conversation,
        conversations_repository.update_conversation(
            session,
            model,
            {
                "total_input_tokens": model.total_input_tokens + input_tokens,
                "total_output_tokens": model.total_output_tokens + output_tokens,
                "context_tokens": context_tokens,
                "last_message_at": now,
                "updated_at": now,
            },
        ),
    )
