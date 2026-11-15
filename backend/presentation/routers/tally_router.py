import logging
import uuid
from collections.abc import Iterator
from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import StreamingResponse
from langchain_core.messages import AIMessageChunk
from pydantic import BaseModel
from sqlalchemy.orm import Session

from agents.tally.agent import get_tally_ai
from agents.tally.context import TallyContext
from agents.tally.history import message_text, to_display_messages
from agents.tally.reasoning import ReasoningFilter
from agents.tally.usage import turn_usage
from domain.entities import Conversation, User
from infra.database.session import get_db, get_session
from presentation.dependencies.auth import get_current_user
from presentation.schemas.common_schemas import Page
from presentation.schemas.tally_schemas import (
    ChatDoneEvent,
    ChatErrorEvent,
    ChatMessageResponse,
    ChatMetaEvent,
    ChatTokenEvent,
    ConversationDetailResponse,
    ConversationResponse,
    TallyChatRequest,
)
from services import conversations_service
from services.users_service import list_users_by_household

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/tally", tags=["tally"])

CONVERSATION_FULL_DETAIL = "conversation_limit_reached"


def _sse(event: str, payload: BaseModel) -> str:
    """One server-sent event. The JSON has no line breaks, so one `data:` line is enough."""
    return f"event: {event}\ndata: {payload.model_dump_json()}\n\n"


def _to_conversation_response(conversation: Conversation) -> ConversationResponse:
    return ConversationResponse(
        id=conversation.id,  # type: ignore[arg-type]
        title=conversation.title,
        context_tokens=conversation.context_tokens,
        token_limit=conversations_service.token_limit_of(conversation),
        total_input_tokens=conversation.total_input_tokens,
        total_output_tokens=conversation.total_output_tokens,
        last_message_at=conversation.last_message_at,
        created_at=conversation.created_at,  # type: ignore[arg-type]
    )


def _thread_config(conversation_id: uuid.UUID) -> dict[str, Any]:
    """The conversation id is the LangGraph thread: its history lives in the checkpointer."""
    return {"configurable": {"thread_id": str(conversation_id)}}


def _saved_messages(agent: Any, config: dict[str, Any]) -> list:
    return agent.get_state(config).values.get("messages", [])


def _answer_text(chunk: Any) -> str:
    """Text of a streamed piece that is part of the answer. The pieces of a tool call are not."""
    if isinstance(chunk, AIMessageChunk) and not chunk.tool_call_chunks:
        return message_text(chunk.content)
    return ""


def _answer_pieces(stream: Iterator[Any]) -> Iterator[str]:
    """The text of the final answer piece by piece, with the model's reasoning taken out.
    Each model call gets its own filter: a call that ends in the middle of a reasoning must not
    swallow the next one."""
    run_id = None
    visible = ReasoningFilter()
    for chunk, _metadata in stream:
        raw = _answer_text(chunk)
        if not raw:
            continue
        if chunk.id != run_id:
            if tail := visible.flush():
                yield tail
            run_id, visible = chunk.id, ReasoningFilter()
        if text := visible.feed(raw):
            yield text
    if tail := visible.flush():
        yield tail


def _record_usage(
    agent: Any, config: dict[str, Any], already_saved: int, conversation: Conversation
) -> Conversation:
    """Adds the finished turn to the conversation, in its own session: the request's one may be closed
    by now, since the stream outlives the dependency."""
    messages = _saved_messages(agent, config)
    usage = turn_usage(messages[already_saved:], messages)
    with get_session() as session:
        updated = conversations_service.record_turn(
            session,
            conversation.id,  # type: ignore[arg-type]
            conversation.user_id,
            usage.input_tokens,
            usage.output_tokens,
            usage.context_tokens,
        )
        session.commit()
    return updated


def _stream_turn(
    conversation: Conversation, is_new: bool, message: str, context: TallyContext
) -> Iterator[str]:
    """The events of one answer: meta, token..., then done (or error). A plain generator: Starlette
    iterates it in the threadpool, which suits the synchronous agent and checkpointer."""
    agent = get_tally_ai()
    config = _thread_config(conversation.id)  # type: ignore[arg-type]
    yield _sse(
        "meta",
        ChatMetaEvent(
            conversation_id=conversation.id,  # type: ignore[arg-type]
            title=conversation.title,
            is_new=is_new,
        ),
    )
    recorded = False
    already_saved = 0
    try:
        already_saved = len(_saved_messages(agent, config))
        answer: list[str] = []
        for text in _answer_pieces(
            agent.stream(
                {"messages": [{"role": "user", "content": message}]},
                config=config,  # type: ignore
                context=context,
                stream_mode="messages",
            )
        ):
            answer.append(text)
            yield _sse("token", ChatTokenEvent(text=text))
        if not "".join(answer).strip():
            yield _sse("error", ChatErrorEvent(code="empty_answer"))
            return
        updated = _record_usage(agent, config, already_saved, conversation)
        recorded = True
        yield _sse(
            "done",
            ChatDoneEvent(
                context_tokens=updated.context_tokens,
                token_limit=conversations_service.token_limit_of(updated),
                total_input_tokens=updated.total_input_tokens,
                total_output_tokens=updated.total_output_tokens,
            ),
        )
    except Exception:
        logger.exception("Tally AI failed to answer")
        yield _sse("error", ChatErrorEvent(code="ai_unavailable"))
    finally:
        # A failed turn or a client that left mid-answer still used tokens: count them, best effort
        if not recorded:
            try:
                _record_usage(agent, config, already_saved, conversation)
            except Exception:
                logger.exception("Could not record the usage of an unfinished turn")


# A plain `def`: FastAPI runs it in the threadpool, and the agent and the services are synchronous
@router.post(
    "/chat",
    response_class=StreamingResponse,
    responses={200: {"content": {"text/event-stream": {}}}},
)
def chat_endpoint(
    body: TallyChatRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    session: Annotated[Session, Depends(get_db)],
) -> StreamingResponse:
    """Answers as server-sent events: `meta` (conversation id), `token` (pieces of the markdown answer),
    then `done` (usage) or `error`. Without `conversation_id` it starts a new conversation."""
    is_new = body.conversation_id is None
    if body.conversation_id is None:
        conversation = conversations_service.start_conversation(
            session,
            current_user.id,  # type: ignore
            body.message,  # type: ignore[arg-type]
        )
    else:
        conversation = conversations_service.get_conversation(
            session,
            body.conversation_id,
            current_user.id,  # type: ignore[arg-type]
        )
        if conversations_service.is_limit_reached(conversation):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT, detail=CONVERSATION_FULL_DETAIL
            )
    # Loaded once here, not in the prompt: the prompt runs on every model call of the loop
    partner_names = tuple(
        u.display_name
        for u in list_users_by_household(session, current_user.household_id)
        if u.id != current_user.id
    )
    # Committed before streaming: a new conversation must exist even if the stream breaks
    session.commit()
    return StreamingResponse(
        _stream_turn(
            conversation,
            is_new,
            body.message,
            TallyContext(user=current_user, partner_names=partner_names),
        ),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


@router.get("/conversations", response_model=Page[ConversationResponse])
def list_conversations_endpoint(
    current_user: Annotated[User, Depends(get_current_user)],
    session: Annotated[Session, Depends(get_db)],
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> Page[ConversationResponse]:
    conversations, total = conversations_service.list_conversations(
        session,
        current_user.id,  # type: ignore
        limit,
        offset,  # type: ignore[arg-type]
    )
    return Page(
        items=[_to_conversation_response(c) for c in conversations],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.get(
    "/conversations/{conversation_id}", response_model=ConversationDetailResponse
)
def get_conversation_endpoint(
    conversation_id: uuid.UUID,
    current_user: Annotated[User, Depends(get_current_user)],
    session: Annotated[Session, Depends(get_db)],
) -> ConversationDetailResponse:
    """The conversation and its messages (the questions and the final answers), to continue it."""
    conversation = conversations_service.get_conversation(
        session,
        conversation_id,
        current_user.id,  # type: ignore[arg-type]
    )
    messages = _saved_messages(get_tally_ai(), _thread_config(conversation_id))
    return ConversationDetailResponse(
        conversation=_to_conversation_response(conversation),
        messages=[ChatMessageResponse(**m) for m in to_display_messages(messages)],
    )
