import uuid
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from infra.database.models import Conversations
from infra.repositories.common.exceptions import (
    RecordNotFoundError,
    translate_db_errors,
)


@translate_db_errors("conversations")
def get_conversation_for_user(
    session: Session, conversation_id: uuid.UUID, user_id: uuid.UUID
) -> Conversations:
    """A conversation is private: one that belongs to another user is 'not found', never 'forbidden'."""
    stmt = (
        select(Conversations)
        .where(Conversations.id == conversation_id)
        .where(Conversations.user_id == user_id)
        .where(Conversations.deleted_at.is_(None))
    )
    conversation = session.scalars(stmt).first()
    if conversation is None:
        raise RecordNotFoundError("conversations", "get_conversation_for_user")
    return conversation


@translate_db_errors("conversations")
def create_conversation(session: Session, values: dict[str, Any]) -> Conversations:
    """`values` uses Conversations column names."""
    conversation = Conversations(**values)
    session.add(conversation)
    session.flush()
    return conversation


@translate_db_errors("conversations")
def update_conversation(
    session: Session, conversation: Conversations, values: dict[str, Any]
) -> Conversations:
    for column, value in values.items():
        setattr(conversation, column, value)
    session.flush()
    return conversation


@translate_db_errors("conversations")
def list_conversations_by_user(
    session: Session, user_id: uuid.UUID, limit: int, offset: int
) -> list[Conversations]:
    """Most recently used first. A conversation without messages yet goes by its creation date."""
    stmt = (
        select(Conversations)
        .where(Conversations.user_id == user_id)
        .where(Conversations.deleted_at.is_(None))
        .order_by(
            func.coalesce(
                Conversations.last_message_at, Conversations.created_at
            ).desc(),
            Conversations.id,
        )
        .limit(limit)
        .offset(offset)
    )
    return list(session.scalars(stmt).all())


@translate_db_errors("conversations")
def count_conversations_by_user(session: Session, user_id: uuid.UUID) -> int:
    stmt = (
        select(func.count())
        .select_from(Conversations)
        .where(Conversations.user_id == user_id)
        .where(Conversations.deleted_at.is_(None))
    )
    return session.scalar(stmt) or 0
