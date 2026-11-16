"""Tools for recurrences (recorrências): what repeats every month (rent, salary, subscriptions).

A recurrence is a template, not money: each month it creates one financial entry (lançamento) in
the household. It answers "what are our fixed bills?", "what comes in every month?" and is part of
any planning question, together with the entries of the month.
"""

import decimal
from typing import Literal

from langchain.tools import ToolRuntime, tool

from agents.common.context import AgentContext
from agents.common.formatting import clamp_limit, money, scope_line, text
from agents.tools._shared import owner_names, tool_errors
from domain.entities import Recurrence, User
from domain.read_models import RecurrenceFilters
from infra.database.session import get_session
from services.recurrences_service import search_recurrences

DEFAULT_LIMIT = 30
MAX_LIMIT = 50
# A household has few recurrences: read them all, so the "only mine" filter and the totals are
# done over every row, not over one page.
FETCH_LIMIT = 500
SHARED_OWNER = "shared (no owner)"

_FILTERS_HELP = (
    "Filters (all optional): type REVENUES (money that comes in every month) or EXPENSES (money "
    "that goes out every month), status ACTIVE (default, the ones still in use) or CANCELLED, "
    "search (text inside the description), limit (max 50). "
    "The result already has the monthly totals: never add amounts yourself."
)


def _total(recurrences: list[Recurrence], type_: str) -> decimal.Decimal:
    return sum(
        (r.amount for r in recurrences if r.type == type_), start=decimal.Decimal("0")
    )


def _find_recurrences(
    user: User,
    only_mine: bool,
    type: str | None,
    status: str | None,
    search: str | None,
    limit: int,
) -> str:
    limit = clamp_limit(limit, MAX_LIMIT)
    status = status or "ACTIVE"
    household_id = user.household_id
    filters = RecurrenceFilters(
        household_id=household_id,
        type=type,
        status=status,
        search=search or None,
    )

    with get_session() as session:
        items, _ = search_recurrences(session, filters, limit=FETCH_LIMIT)
        names = owner_names(session, household_id)

    if only_mine:
        items = [r for r in items if r.user_id == user.id]

    lines = [f"Recurrences with status {status}", scope_line(only_mine, "recurrences")]
    if not items:
        lines.append("No recurrences found for these filters.")
        return "\n".join(lines)

    lines.append(
        "description | category | type | payment | monthly amount | due day | status | owner"
    )
    for recurrence in items[:limit]:
        lines.append(
            " | ".join([
                recurrence.description,
                text(recurrence.category),
                recurrence.type,
                text(recurrence.payment_type),
                money(recurrence.amount),
                str(recurrence.due_day) if recurrence.due_day else "-",
                recurrence.status,
                names.get(recurrence.user_id, SHARED_OWNER),  # type: ignore[arg-type]
            ])
        )
    lines.append(f"Showing {min(len(items), limit)} of {len(items)} recurrences.")
    lines.append(
        f"Monthly total of these recurrences: expenses {money(_total(items, 'EXPENSES'))}, "
        f"revenues {money(_total(items, 'REVENUES'))}."
    )
    lines.append(
        "Notes: a recurrence is a monthly template that creates one entry (lançamento) per "
        "month; it is not money that already moved in the bank."
    )
    return "\n".join(lines)


@tool(
    "get_my_recurrences",
    description=(
        "ONLY the logged person's own recurrences (recorrências): what repeats every month, like "
        "rent, salary, subscriptions and fixed bills, with monthly amount and due day. Call it "
        "for 'minhas recorrências', 'minhas contas fixas', 'meus gastos fixos', 'minhas "
        "assinaturas', 'meu salário fixo', and for planning questions about the person. Never use "
        "it for the couple or the house. " + _FILTERS_HELP
    ),
)
@tool_errors
def get_my_recurrences(
    runtime: ToolRuntime[AgentContext],
    type: Literal["REVENUES", "EXPENSES"] | None = None,
    status: Literal["ACTIVE", "CANCELLED"] | None = None,
    search: str | None = None,
    limit: int = DEFAULT_LIMIT,
) -> str:
    return _find_recurrences(runtime.context.user, True, type, status, search, limit)


@tool(
    "get_household_recurrences",
    description=(
        "Recurrences (recorrências) of EVERYONE in the household (the couple); each line says "
        "whose it is. What repeats every month, like rent, salary, subscriptions and fixed "
        "bills, with monthly amount and due day. Call it for 'nossas recorrências', 'contas "
        "fixas da casa', 'gastos fixos', 'o que entra e sai todo mês', and for planning "
        "questions about the couple. " + _FILTERS_HELP
    ),
)
@tool_errors
def get_household_recurrences(
    runtime: ToolRuntime[AgentContext],
    type: Literal["REVENUES", "EXPENSES"] | None = None,
    status: Literal["ACTIVE", "CANCELLED"] | None = None,
    search: str | None = None,
    limit: int = DEFAULT_LIMIT,
) -> str:
    return _find_recurrences(runtime.context.user, False, type, status, search, limit)
