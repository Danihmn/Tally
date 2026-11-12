"""Tools for financial entries (lançamentos): what is planned or expected to come in or go out.

Entries are not transactions: a transaction is money that really moved in the bank, an entry is
what the couple planned (a bill, a salary, an installment). An entry is RECONCILED once it was
matched with a transaction. Entries are grouped by `reference_month` (the first day of a month).
"""

import datetime
from typing import Literal

from langchain.tools import ToolRuntime, tool

from agents.common.clock import today
from agents.common.context import AgentContext
from agents.common.formatting import (
    clamp_limit,
    day,
    month,
    money,
    period_note,
    scope_line,
    text,
)
from agents.tools._shared import owner_names, tool_errors
from domain.entities import FinancialEntry, User
from domain.read_models import FinancialEntryFilters, FinancialEntryTotals
from infra.database.session import get_session
from services.financial_entries_service import (
    search_financial_entries,
    summarize_financial_entries,
)
from utils.dates import first_day_of_month

DEFAULT_LIMIT = 20
MAX_LIMIT = 50

_FILTERS_HELP = (
    "Filters (all optional): month_from and month_to as YYYY-MM (both inclusive; without them "
    "the current month is used), type REVENUES (money expected in) or EXPENSES (money expected "
    "out), status PLANNED (not matched with a bank transaction yet), RECONCILED (already matched) "
    "or CANCELLED, category, search (text inside the description), limit (max 50). "
    "The result already has the totals of the whole period: never add amounts yourself."
)


def _parse_month(value: str, field: str) -> datetime.date:
    try:
        return datetime.datetime.strptime(value.strip(), "%Y-%m").date()
    except ValueError:
        raise ValueError(f"{field} must be a month as YYYY-MM, got '{value}'") from None


def _resolve_months(
    month_from: str | None, month_to: str | None
) -> tuple[datetime.date, datetime.date, bool]:
    """(first month, last month, True when it defaulted to the current month), as first days."""
    if month_from is None and month_to is None:
        current = first_day_of_month(today())
        return current, current, True

    start = _parse_month(month_from, "month_from") if month_from else None
    end = _parse_month(month_to, "month_to") if month_to else None
    start = start or end
    end = end or start
    assert start is not None and end is not None
    if start > end:
        raise ValueError("month_from must not be after month_to")
    return start, end, False


def _status(entry: FinancialEntry, now: datetime.date) -> str:
    if (
        entry.status == "PLANNED"
        and entry.due_date is not None
        and entry.due_date < now
    ):
        return "PLANNED (overdue)"
    return entry.status


def _installment(entry: FinancialEntry) -> str:
    if entry.installment_number is None:
        return "-"
    total = entry.installment_total or "?"
    return f"{entry.installment_number}/{total}"


def _totals_line(label: str, totals: FinancialEntryTotals) -> str:
    expected = totals.planned_total + totals.reconciled_total
    count = totals.planned_count + totals.reconciled_count
    line = (
        f"Total {label}: {money(expected)} ({count} entries); "
        f"planned (not reconciled yet): {money(totals.planned_total)} "
        f"({totals.planned_count}); reconciled: {money(totals.reconciled_total)} "
        f"({totals.reconciled_count})"
    )
    if totals.cancelled_count:
        line += (
            f"; cancelled, left out of the total: {money(totals.cancelled_total)} "
            f"({totals.cancelled_count})"
        )
    return line


def _find_entries(
    user: User,
    only_mine: bool,
    month_from: str | None,
    month_to: str | None,
    type: str | None,
    status: str | None,
    category: str | None,
    search: str | None,
    limit: int,
) -> str:
    start, end, defaulted = _resolve_months(month_from, month_to)
    limit = clamp_limit(limit, MAX_LIMIT)
    household_id = user.household_id
    filters = FinancialEntryFilters(
        household_id=household_id,
        user_id=user.id if only_mine else None,
        reference_month_from=start,
        reference_month_to=end,
        type=type,
        status=status,
        category=category or None,
        search=search or None,
    )

    with get_session() as session:
        items, total = search_financial_entries(session, filters, limit=limit)
        summary = summarize_financial_entries(session, filters)
        names = owner_names(session, household_id)

    period = month(start) if start == end else f"{month(start)} to {month(end)}"
    lines = [
        f"Reference months: {period}{period_note(defaulted)}",
        scope_line(only_mine, "entries"),
    ]
    if not items:
        lines.append("No entries found for these filters.")
        return "\n".join(lines)

    now = today()
    lines.append(
        "reference month | due date | description | category | type | payment | amount | "
        "status | installment | owner"
    )
    for entry in items:
        lines.append(
            " | ".join([
                month(entry.reference_month),
                day(entry.due_date),
                entry.description,
                text(entry.category),
                entry.type,
                text(entry.payment_type),
                money(entry.amount),
                _status(entry, now),
                _installment(entry),
                names.get(entry.user_id, "?"),
            ])
        )
    lines.append(f"Showing {len(items)} of {total} entries (newest month first).")
    lines.append(_totals_line("expenses", summary.expenses))
    lines.append(_totals_line("revenues", summary.revenues))
    lines.append(
        "Notes: entries are planned amounts, not money that already moved in the bank. "
        "'overdue' means PLANNED with a due date before today."
    )
    return "\n".join(lines)


@tool(
    "get_my_entries",
    description=(
        "ONLY the logged person's own financial entries (lançamentos): bills, salaries and "
        "installments planned or expected, with due date and whether they were already "
        "reconciled with a bank transaction. Call it for 'meus lançamentos', 'o que eu tenho a "
        "pagar', 'minhas contas do mês', 'minhas parcelas'. Never use it for the couple or the "
        "house. " + _FILTERS_HELP
    ),
)
@tool_errors
def get_my_entries(
    runtime: ToolRuntime[AgentContext],
    month_from: str | None = None,
    month_to: str | None = None,
    type: Literal["REVENUES", "EXPENSES"] | None = None,
    status: Literal["PLANNED", "RECONCILED", "CANCELLED"] | None = None,
    category: str | None = None,
    search: str | None = None,
    limit: int = DEFAULT_LIMIT,
) -> str:
    return _find_entries(
        runtime.context.user,
        True,
        month_from,
        month_to,
        type,
        status,
        category,
        search,
        limit,
    )


@tool(
    "get_household_entries",
    description=(
        "Financial entries (lançamentos) of EVERYONE in the household (the couple); each line "
        "says whose it is. Bills, salaries and installments planned or expected, with due date "
        "and whether they were already reconciled. Call it for 'nossos lançamentos', 'o que "
        "temos a pagar', 'contas da casa', 'o que vence este mês', 'por pessoa'. "
        + _FILTERS_HELP
    ),
)
@tool_errors
def get_household_entries(
    runtime: ToolRuntime[AgentContext],
    month_from: str | None = None,
    month_to: str | None = None,
    type: Literal["REVENUES", "EXPENSES"] | None = None,
    status: Literal["PLANNED", "RECONCILED", "CANCELLED"] | None = None,
    category: str | None = None,
    search: str | None = None,
    limit: int = DEFAULT_LIMIT,
) -> str:
    return _find_entries(
        runtime.context.user,
        False,
        month_from,
        month_to,
        type,
        status,
        category,
        search,
        limit,
    )
