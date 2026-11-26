"""Tools that suggest recurrences (recorrências) from the bank transactions and create the
ones the person confirms.

The candidates come from deterministic rules (`domain/recurrence_detection.py`), never from the
model. Suggesting is read only. Creating takes only a candidate id, and only after the
candidate was shown to the person and the person wrote back (the confirmation)."""

from langchain.tools import ToolRuntime, tool
from langchain_core.messages import HumanMessage, ToolMessage

from agents.common.clock import today
from agents.common.context import AgentContext
from agents.common.formatting import clamp_limit, day, money, scope_line, text
from agents.tools._shared import owner_names, tool_errors
from domain.entities import User
from domain.recurrence_detection import RecurrenceCandidate
from infra.database.session import get_session
from services.common.exceptions import ServiceError
from services.recurrence_detection_service import (
    LOOKBACK_MONTHS,
    create_recurrence_from_candidate,
    find_recurrence_candidates,
)

DEFAULT_LIMIT = 10
MAX_LIMIT = 30
SUGGEST_TOOL_NAMES = ("suggest_my_recurrences", "suggest_household_recurrences")
CANDIDATE_LABEL = "candidate"

_SUGGEST_HELP = (
    "Read only: it creates nothing. Each candidate has an id, the monthly amount (the median), "
    "the due day, a confidence from 0 to 1 and the transactions it came from. Show the "
    "candidates to the person and ask which ones they want as recurrences; never create one "
    "without their explicit yes for that candidate. Optional: limit (max 30)."
)


def _evidence_text(candidate: RecurrenceCandidate) -> str:
    return ", ".join(f"{day(e.date)} {money(e.amount)}" for e in candidate.evidence)


def _suggest(user: User, only_mine: bool, limit: int) -> str:
    limit = clamp_limit(limit, MAX_LIMIT)
    household_id = user.household_id

    with get_session() as session:
        candidates = find_recurrence_candidates(
            session, household_id, today(), user_id=user.id if only_mine else None
        )
        names = owner_names(session, household_id)

    lines = [
        f"Recurrence candidates found in the transactions of the last {LOOKBACK_MONTHS} months",
        scope_line(only_mine, "transactions"),
    ]
    if not candidates:
        lines.append(
            "No new monthly pattern found: every pattern is already a recurrence, or no "
            "transaction repeats for 3 months or more."
        )
        return "\n".join(lines)

    lines.append(
        f"{CANDIDATE_LABEL} id | description | category | type | payment | monthly amount | "
        "due day | months | confidence | owner | evidence (date amount)"
    )
    for candidate in candidates[:limit]:
        lines.append(
            " | ".join(
                [
                    f"{CANDIDATE_LABEL} {candidate.candidate_id}",
                    candidate.description,
                    text(candidate.category),
                    candidate.type,
                    candidate.payment_type,
                    money(candidate.amount),
                    str(candidate.due_day),
                    str(candidate.months),
                    f"{candidate.confidence:.2f}",
                    names.get(candidate.user_id, "?"),
                    _evidence_text(candidate),
                ]
            )
        )
    lines.append(
        f"Showing {min(len(candidates), limit)} of {len(candidates)} candidates."
    )
    lines.append(
        "Notes: these are suggestions, NOT recurrences yet. To create one, the person must "
        "confirm that specific candidate; then call create_suggested_recurrence with its id."
    )
    return "\n".join(lines)


@tool(
    "suggest_my_recurrences",
    description=(
        "Finds, in the logged person's OWN bank transactions, what repeats every month and is "
        "not a recurrence yet (salary, rent, subscriptions), and suggests them as recurrences. "
        "Call it for 'sugira recorrências', 'o que se repete nos meus gastos', 'tem alguma "
        "conta fixa que eu não cadastrei', 'crie minhas recorrências'. Never use it for the "
        "couple or the house. " + _SUGGEST_HELP
    ),
)
@tool_errors
def suggest_my_recurrences(
    runtime: ToolRuntime[AgentContext], limit: int = DEFAULT_LIMIT
) -> str:
    return _suggest(runtime.context.user, True, limit)


@tool(
    "suggest_household_recurrences",
    description=(
        "Finds, in the bank transactions of EVERYONE in the household (the couple), what "
        "repeats every month and is not a recurrence yet, and suggests them as recurrences; "
        "each line says whose it is. Call it for 'sugira recorrências da casa', 'o que se "
        "repete nos nossos gastos', 'contas fixas que a gente não cadastrou', 'crie as "
        "recorrências a partir das transações'. " + _SUGGEST_HELP
    ),
)
@tool_errors
def suggest_household_recurrences(
    runtime: ToolRuntime[AgentContext], limit: int = DEFAULT_LIMIT
) -> str:
    return _suggest(runtime.context.user, False, limit)


def _was_confirmed(messages: list, candidate_id: str) -> bool:
    """True when a suggest tool showed this candidate in the conversation and the person wrote
    after it. Whether that message is a yes is the model's reading; this rule makes sure the
    yes can only come from the person, after they saw the candidate."""
    marker = f"{CANDIDATE_LABEL} {candidate_id}"
    shown_at = None
    for index, message in enumerate(messages):
        if (
            isinstance(message, ToolMessage)
            and message.name in SUGGEST_TOOL_NAMES
            and marker in str(message.content)
        ):
            shown_at = index
    if shown_at is None:
        return False
    return any(isinstance(m, HumanMessage) for m in messages[shown_at + 1 :])


@tool(
    "create_suggested_recurrence",
    description=(
        "Creates ONE recurrence from a candidate that a suggest tool showed in this "
        "conversation. Call it ONLY after the person explicitly confirmed THAT candidate in "
        "their last message (for example 'sim, cria a do Netflix'). Never call it on your own "
        "initiative, never for candidates the person did not name, and never with an id you "
        "did not get from a suggest tool. One call per confirmed candidate. The amount, "
        "description and due day come from the candidate: you cannot change them here."
    ),
)
@tool_errors
def create_suggested_recurrence(
    candidate_id: str, runtime: ToolRuntime[AgentContext]
) -> str:
    candidate_id = candidate_id.strip().lower()
    messages = (runtime.state or {}).get("messages", [])
    if not _was_confirmed(messages, candidate_id):
        raise ValueError(
            f"candidate {candidate_id} was not shown to the person, or they did not answer "
            "yet. Call a suggest tool, show the candidate and wait for the person to confirm it."
        )

    user = runtime.context.user
    with get_session() as session:
        try:
            recurrence = create_recurrence_from_candidate(
                session, user.household_id, candidate_id, today()
            )
        except ServiceError as error:
            session.rollback()
            raise ValueError(
                f"could not create the recurrence of candidate {candidate_id} ({error}). "
                "It may already be a recurrence: call a suggest tool again."
            ) from None
        session.commit()
        names = owner_names(session, user.household_id)

    return "\n".join(
        [
            f"Recurrence created from candidate {candidate_id} (status ACTIVE, source AI).",
            "description | category | type | payment | monthly amount | due day | owner",
            " | ".join(
                [
                    recurrence.description,
                    text(recurrence.category),
                    recurrence.type,
                    text(recurrence.payment_type),
                    money(recurrence.amount),
                    str(recurrence.due_day) if recurrence.due_day else "-",
                    names.get(recurrence.user_id, "?"),  # type: ignore[arg-type]
                ]
            ),
            "Like every recurrence, it creates one planned entry (lançamento) per month.",
        ]
    )
