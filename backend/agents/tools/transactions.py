import calendar
import datetime
from typing import Literal

from langchain.tools import ToolRuntime, tool

from agents.common.clock import today
from agents.common.context import AgentContext
from agents.common.formatting import (
    clamp_limit,
    day,
    money,
    period_note,
    scope_line,
    text,
)
from agents.tools._shared import owner_names, tool_errors
from domain.entities import User
from domain.read_models import TransactionFilters, TransactionSummary
from infra.database.session import get_session
from services.transactions_service import (
    search_transactions,
    summarize_transactions,
    summarize_transactions_by,
)
from utils.dates import end_of_day_utc, first_day_of_month, start_of_day_utc

DEFAULT_LIMIT = 20
MAX_LIMIT = 50

_FILTERS_HELP = (
    "Filters (all optional): date_from and date_to as YYYY-MM-DD (both inclusive; "
    "without them the current month is used), type DEBIT (money out) or CREDIT (money in), "
    "category, search (text inside the description), limit (max 50). "
    "The result already has the totals of the whole period: never add amounts yourself."
)


def _parse_day(value: str, field: str) -> datetime.date:
    try:
        return datetime.date.fromisoformat(value.strip())
    except ValueError:
        raise ValueError(
            f"{field} must be a date as YYYY-MM-DD, got '{value}'"
        ) from None


def _resolve_period(
    date_from: str | None, date_to: str | None
) -> tuple[datetime.date, datetime.date, bool]:
    """(first day, last day, True when it defaulted to the current month)."""
    if date_from is None and date_to is None:
        now = today()
        last_day = calendar.monthrange(now.year, now.month)[1]
        return first_day_of_month(now), now.replace(day=last_day), True

    start = _parse_day(date_from, "date_from") if date_from else None
    end = _parse_day(date_to, "date_to") if date_to else None
    if start is None:
        assert end is not None
        start = first_day_of_month(end)
    if end is None:
        end = max(today(), start)
    if start > end:
        raise ValueError("date_from must not be after date_to")
    return start, end, False


def _filters(
    user: User,
    only_mine: bool,
    start: datetime.date,
    end: datetime.date,
    type: str | None,
    category: str | None,
    search: str | None,
) -> TransactionFilters:
    """The same filters for the list and the summary tools (the period is in whole UTC days)."""
    return TransactionFilters(
        household_id=user.household_id,
        user_id=user.id if only_mine else None,
        date_from=start_of_day_utc(start),
        date_to=end_of_day_utc(end),
        type=type,
        category=category or None,
        search=search or None,
    )


def _header(
    start: datetime.date, end: datetime.date, defaulted: bool, only_mine: bool
) -> list[str]:
    return [
        f"Period: {start.isoformat()} to {end.isoformat()}{period_note(defaulted)}",
        scope_line(only_mine, "transactions"),
    ]


def _totals_lines(summary: TransactionSummary) -> list[str]:
    return [
        f"Total debits: {money(summary.debit_total)} ({summary.debit_count} transactions)",
        f"Total credits: {money(summary.credit_total)} ({summary.credit_count} transactions)",
    ]


def _find_transactions(
    user: User,
    only_mine: bool,
    date_from: str | None,
    date_to: str | None,
    type: str | None,
    category: str | None,
    search: str | None,
    limit: int,
) -> str:
    start, end, defaulted = _resolve_period(date_from, date_to)
    limit = clamp_limit(limit, MAX_LIMIT)
    filters = _filters(user, only_mine, start, end, type, category, search)

    with get_session() as session:
        items, total = search_transactions(session, filters, limit=limit)
        summary = summarize_transactions(session, filters)
        names = owner_names(session, user.household_id)

    lines = _header(start, end, defaulted, only_mine)
    if not items:
        lines.append("No transactions found for these filters.")
        return "\n".join(lines)

    lines.append("date | amount | type | description | owner")
    for item in items:
        t = item.transaction
        lines.append(
            " | ".join([
                day(t.date),
                money(t.amount),
                t.type,
                text(t.description),
                names.get(item.user_id, "?"),
            ])
        )
    lines.append(f"Showing {len(items)} of {total} transactions (newest first).")
    lines.extend(_totals_lines(summary))
    return "\n".join(lines)


@tool(
    "get_my_transactions",
    description=(
        "ONLY the logged person's own transactions. Call it when they ask about themself: "
        "'eu', 'meu', 'minha', 'gastei', 'recebi'. Never use it for the couple or the house. "
        + _FILTERS_HELP
    ),
)
@tool_errors
def get_my_transactions(
    runtime: ToolRuntime[AgentContext],
    date_from: str | None = None,
    date_to: str | None = None,
    type: Literal["DEBIT", "CREDIT"] | None = None,
    category: str | None = None,
    search: str | None = None,
    limit: int = DEFAULT_LIMIT,
) -> str:
    return _find_transactions(
        runtime.context.user,
        True,
        date_from,
        date_to,
        type,
        category,
        search,
        limit,
    )


@tool(
    "get_household_transactions",
    description=(
        "Transactions of EVERYONE in the household (the couple); each line says whose it is. "
        "Call it for 'nós', 'nosso', 'nossos', 'a gente', 'casa', 'família', 'juntos', 'o casal', "
        "'por pessoa', 'quem gastou mais', or to compare the people. " + _FILTERS_HELP
    ),
)
@tool_errors
def get_household_transactions(
    runtime: ToolRuntime[AgentContext],
    date_from: str | None = None,
    date_to: str | None = None,
    type: Literal["DEBIT", "CREDIT"] | None = None,
    category: str | None = None,
    search: str | None = None,
    limit: int = DEFAULT_LIMIT,
) -> str:
    return _find_transactions(
        runtime.context.user,
        False,
        date_from,
        date_to,
        type,
        category,
        search,
        limit,
    )


GroupBy = Literal["owner", "category", "owner_and_category"]

_SUMMARY_HELP = (
    "Totals grouped by person (owner), by category, or both (group_by: owner, category or "
    "owner_and_category), biggest spending first. Filters (all optional): date_from and date_to "
    "as YYYY-MM-DD (both inclusive; without them the current month is used), type DEBIT or "
    "CREDIT, category, search (text inside the description). "
    "The result already has every total: never add amounts yourself."
)


def _summarize(
    user: User,
    only_mine: bool,
    group_by: str,
    date_from: str | None,
    date_to: str | None,
    type: str | None,
    category: str | None,
    search: str | None,
) -> str:
    if group_by not in ("owner", "category", "owner_and_category"):
        raise ValueError(
            f"group_by must be owner, category or owner_and_category, got '{group_by}'"
        )
    by_owner = group_by in ("owner", "owner_and_category")
    by_category = group_by in ("category", "owner_and_category")
    start, end, defaulted = _resolve_period(date_from, date_to)
    filters = _filters(user, only_mine, start, end, type, category, search)

    with get_session() as session:
        groups = summarize_transactions_by(session, filters, by_owner, by_category)
        summary = summarize_transactions(session, filters)
        names = owner_names(session, user.household_id)

    lines = _header(start, end, defaulted, only_mine)
    lines.append(f"Grouped by: {group_by}")
    if not groups:
        lines.append("No transactions found for these filters.")
        return "\n".join(lines)

    columns = (["owner"] if by_owner else []) + (["category"] if by_category else [])
    lines.append(
        " | ".join(
            columns + ["total debits", "debit count", "total credits", "credit count"]
        )
    )
    for group in groups:
        keys = []
        if by_owner:
            keys.append(names.get(group.user_id, "?"))  # type: ignore[arg-type]
        if by_category:
            keys.append(group.category or "sem categoria")
        lines.append(
            " | ".join(
                keys
                + [
                    money(group.debit_total),
                    str(group.debit_count),
                    money(group.credit_total),
                    str(group.credit_count),
                ]
            )
        )
    lines.append(f"{len(groups)} groups (biggest debit total first).")
    lines.extend(_totals_lines(summary))
    lines.append(
        "Notes: debits are money out, credits are money in. Card bill payments and transfers "
        "between the couple's own accounts are inside these totals; filter by category to "
        "leave them out."
    )
    return "\n".join(lines)


@tool(
    "get_my_spending_summary",
    description=(
        "ONLY the logged person's own spending and income, totaled by category (default) or "
        "by person. Call it for 'quanto eu gastei por categoria', 'onde eu mais gastei', "
        "'com o que eu gastei'. Never use it for the couple or the house. "
        + _SUMMARY_HELP
    ),
)
@tool_errors
def get_my_spending_summary(
    runtime: ToolRuntime[AgentContext],
    group_by: GroupBy = "category",
    date_from: str | None = None,
    date_to: str | None = None,
    type: Literal["DEBIT", "CREDIT"] | None = None,
    category: str | None = None,
    search: str | None = None,
) -> str:
    return _summarize(
        runtime.context.user,
        True,
        group_by,
        date_from,
        date_to,
        type,
        category,
        search,
    )


@tool(
    "get_household_spending_summary",
    description=(
        "Spending and income of EVERYONE in the household (the couple), totaled by person "
        "(default), by category, or both. Call it for 'quem gastou mais', 'quanto cada um "
        "gastou', 'por pessoa', 'onde a gente mais gastou', 'gastos da casa por categoria'. "
        + _SUMMARY_HELP
    ),
)
@tool_errors
def get_household_spending_summary(
    runtime: ToolRuntime[AgentContext],
    group_by: GroupBy = "owner",
    date_from: str | None = None,
    date_to: str | None = None,
    type: Literal["DEBIT", "CREDIT"] | None = None,
    category: str | None = None,
    search: str | None = None,
) -> str:
    return _summarize(
        runtime.context.user,
        False,
        group_by,
        date_from,
        date_to,
        type,
        category,
        search,
    )
