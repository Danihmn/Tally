import re

from langchain.tools import ToolRuntime, tool
from langchain_core.messages import BaseMessage, ToolMessage

from agents.common.subagents import final_answer, invoke_subagent
from agents.owl.agent import get_owl
from agents.owl.context import OwlContext
from agents.tally.context import TallyContext
from agents.tools.recurrence_detection import (
    ASK_OWL_TOOL_NAME,
    CANDIDATE_LABEL,
    SUGGEST_TOOL_NAMES,
)
from domain.recurrence_detection import CANDIDATE_ID_LENGTH

CANDIDATES_HEADER = (
    "Candidates exactly as the detection rules returned them (use these ids with "
    "create_suggested_recurrence). Columns: candidate id | description | category | type | "
    "payment | monthly amount | due day | months | confidence | owner | evidence (date amount)"
)
# A candidate row of the suggest tools ("candidate ab12cd34 | ..."), not their header row
_CANDIDATE_ROW = re.compile(rf"^{CANDIDATE_LABEL} [0-9a-f]{{{CANDIDATE_ID_LENGTH}}} \|")


def _candidate_lines(messages: list[BaseMessage]) -> list[str]:
    """The candidate lines of Owl's suggest tools, as the rules wrote them (not Owl's words),
    without repeats."""
    lines: list[str] = []
    for message in messages:
        if (
            not isinstance(message, ToolMessage)
            or message.name not in SUGGEST_TOOL_NAMES
        ):
            continue
        for line in str(message.content).splitlines():
            if _CANDIDATE_ROW.match(line) and line not in lines:
                lines.append(line)
    return lines


@tool(
    ASK_OWL_TOOL_NAME,
    description=(
        "Asks Owl, the planning specialist, to analyse what is planned: financial entries "
        "(lançamentos: previsto, a pagar, a receber, atrasado, conciliado), recurrences "
        "(recorrências: contas fixas, assinaturas, salário), the month plan (orçamento, "
        "previsão, sobra no fim do mês), and what repeats every month in the bank transactions "
        "and is not a recurrence yet. For those, Owl only SUGGESTS candidates (with an id, "
        "amount, due day, confidence and evidence); it creates and changes nothing. "
        "Owl has no memory of the conversation: write ONE complete request in Portuguese with "
        "the period when it matters, WHO it is about (the person talking, the partner, or the "
        "whole household) and what is wanted."
    ),
)
def ask_owl(request: str, runtime: ToolRuntime[TallyContext]) -> str:
    context = OwlContext(
        user=runtime.context.user, partner_names=runtime.context.partner_names
    )
    messages = invoke_subagent(get_owl(), request, context)
    answer = final_answer(messages)
    candidates = _candidate_lines(messages)
    if not candidates:
        return answer
    return "\n".join([answer, "", CANDIDATES_HEADER, *candidates])
