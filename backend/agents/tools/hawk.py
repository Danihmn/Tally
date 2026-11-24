from langchain.tools import ToolRuntime, tool

from agents.common.subagents import run_subagent
from agents.hawk.agent import get_hawk
from agents.hawk.context import HawkContext
from agents.tally.context import TallyContext


@tool(
    "ask_hawk",
    description=(
        "Asks Hawk, the spending specialist, to analyse the bank transactions (what was spent "
        "and received): lists of purchases and receipts, totals per person or per category, who "
        "spent more, where the money goes. Hawk reads the data and returns the analysis. "
        "Hawk has no memory of the conversation: write ONE complete request in Portuguese with "
        "everything it needs: the period (dates), WHO it is about (the person talking, the "
        "partner, or the whole household), and what is wanted (a list, totals, a comparison)."
    ),
)
def ask_hawk(request: str, runtime: ToolRuntime[TallyContext]) -> str:
    context = HawkContext(
        user=runtime.context.user, partner_names=runtime.context.partner_names
    )
    return run_subagent(get_hawk(), request, context)
