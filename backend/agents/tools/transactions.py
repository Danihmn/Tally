import calendar
import datetime
from typing import Literal

from langchain.tools import ToolRuntime, tool

from agents.clock import today
from agents.context import TallyContext
from domain.entities import User
from domain.read_models import TransactionFilters
from infra.database.session import get_session
from presentation.schemas.common_schemas import end_of_day_utc, start_of_day_utc
from services.transactions_service import search_transactions, summarize_transactions
from services.users_service import list_users_by_household

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
        return now.replace(day=1), now.replace(day=last_day), True

    start = _parse_day(date_from, "date_from") if date_from else None
    end = _parse_day(date_to, "date_to") if date_to else None
    if start is None:
        assert end is not None
        start = end.replace(day=1)
    if end is None:
        end = max(today(), start)
    if start > end:
        raise ValueError("date_from must not be after date_to")
    return start, end, False


def _money(value) -> str:
    return f"{value:.2f}"


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
    limit = max(1, min(limit, MAX_LIMIT))
    household_id = user.household_id
    filters = TransactionFilters(
        household_id=household_id,
        user_id=user.id if only_mine else None,
        date_from=start_of_day_utc(start),
        date_to=end_of_day_utc(end),
        type=type,
        category=category or None,
        search=search or None,
    )

    with get_session() as session:
        items, total = search_transactions(session, filters, limit=limit)
        summary = summarize_transactions(session, filters)
        names = {
            u.id: u.first_name for u in list_users_by_household(session, household_id)
        }

    period = f"{start.isoformat()} to {end.isoformat()}"
    lines = [
        f"Period: {period}"
        + (" (current month, no period was given)" if defaulted else ""),
        "Scope: only the logged user's transactions"
        if only_mine
        else "Scope: the whole household",
    ]
    if not items:
        lines.append("No transactions found for these filters.")
        return "\n".join(lines)

    lines.append("date | amount | type | description | owner")
    for item in items:
        t = item.transaction
        lines.append(
            " | ".join([
                t.date.date().isoformat(),
                _money(t.amount),
                t.type,
                t.description or "-",
                names.get(item.user_id, "?"),
            ])
        )
    lines.append(f"Showing {len(items)} of {total} transactions (newest first).")
    lines.append(
        f"Total debits: {_money(summary.debit_total)} ({summary.debit_count} transactions)"
    )
    lines.append(
        f"Total credits: {_money(summary.credit_total)} ({summary.credit_count} transactions)"
    )
    return "\n".join(lines)


@tool(
    "get_my_transactions",
    description=(
        "ONLY the logged person's own transactions. Call it when they ask about themself: "
        "'eu', 'meu', 'minha', 'gastei', 'recebi'. Never use it for the couple or the house. "
        + _FILTERS_HELP
    ),
)
def get_my_transactions(
    runtime: ToolRuntime[TallyContext],
    date_from: str | None = None,
    date_to: str | None = None,
    type: Literal["DEBIT", "CREDIT"] | None = None,
    category: str | None = None,
    search: str | None = None,
    limit: int = DEFAULT_LIMIT,
) -> str:
    try:
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
    except ValueError as error:
        return f"Error: {error}"


@tool(
    "get_household_transactions",
    description=(
        "Transactions of EVERYONE in the household (the couple); each line says whose it is. "
        "Call it for 'nós', 'nosso', 'nossos', 'a gente', 'casa', 'família', 'juntos', 'o casal', "
        "'por pessoa', 'quem gastou mais', or to compare the people. " + _FILTERS_HELP
    ),
)
def get_household_transactions(
    runtime: ToolRuntime[TallyContext],
    date_from: str | None = None,
    date_to: str | None = None,
    type: Literal["DEBIT", "CREDIT"] | None = None,
    category: str | None = None,
    search: str | None = None,
    limit: int = DEFAULT_LIMIT,
) -> str:
    try:
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
    except ValueError as error:
        return f"Error: {error}"
