import logging
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from agents.context import TallyContext
from agents.tally_ai import get_tally_ai
from domain.entities import User
from infra.database.session import get_db
from presentation.dependencies.auth import get_current_user
from presentation.schemas.tally_schemas import TallyChatRequest, TallyChatResponse
from services.users_service import list_users_by_household

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/tally", tags=["tally"])


def _text_of(content: str | list) -> str:
    """A message's content is a string, or a list of blocks (strings or {"type": "text", ...})."""
    if isinstance(content, str):
        return content
    parts = [
        block if isinstance(block, str) else block.get("text", "")
        for block in content
        if isinstance(block, str) or block.get("type") == "text"
    ]
    return "".join(parts)


# A plain `def`: FastAPI runs it in the threadpool, and the agent and the services are synchronous
@router.post("/chat", response_model=TallyChatResponse)
def chat_endpoint(
    body: TallyChatRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    session: Annotated[Session, Depends(get_db)],
) -> TallyChatResponse:
    try:
        # Loaded once here, not in the prompt: the prompt runs on every model call of the loop
        partner_names = tuple(
            u.first_name
            for u in list_users_by_household(session, current_user.household_id)
            if u.id != current_user.id
        )
        result = get_tally_ai().invoke(
            {"messages": [{"role": "user", "content": body.message}]},
            context=TallyContext(user=current_user, partner_names=partner_names),
        )
        answer = _text_of(result["messages"][-1].content).strip()
    except Exception:
        logger.exception("Tally AI failed to answer")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="AI unavailable"
        )
    if not answer:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="AI unavailable"
        )
    return TallyChatResponse(answer=answer)
