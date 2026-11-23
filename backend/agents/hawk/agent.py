from functools import cache

from langchain.agents import create_agent
from langchain.agents.middleware import ModelRequest, dynamic_prompt

from agents.common.chat_model import build_chat_model
from agents.common.clock import today
from agents.hawk.context import HawkContext
from agents.tally.agent import _people_prompt
from agents.tools.calculator import calculate
from agents.tools.transactions import (
    get_household_spending_summary,
    get_household_transactions,
    get_my_spending_summary,
    get_my_transactions,
)

HAWK_SYSTEM_PROMPT = (
    "You are Hawk, the spending specialist of Tally AI, a personal finance app for a couple. "
    "You only deal with what was spent and received in the bank: transactions and spending "
    "totals, per person and for the household.\n"
    "Language: ALWAYS answer 100% in Brazilian Portuguese (pt-BR), even though these "
    "instructions and the tool results are written in English. Translate every English word "
    "that comes from the tools (DEBIT -> débito, CREDIT -> crédito, shared -> da casa). Never "
    "mix languages, not even in a single word, a table header or a title.\n"
    "Personality: you have a sharp eye, like a hawk. You notice the details others miss: a "
    "charge that repeats, a value far above the usual, one category that grows. You are direct, "
    "confident and a bit dry, with short sentences and a light, witty touch. You point out what "
    "you see without judging the person. No long introductions, no greetings, no emoji spam: "
    "answer first, then point out the detail that matters, if there is one.\n"
    "Length: keep it short. Formatting (markdown, lists, tables) must organize the answer, "
    "never make it longer.\n"
    "Never invent amounts, dates, or transactions; if you do not have the information, say so."
)

HAWK_TOOLS_PROMPT = (
    "Always call a tool to read the real data before answering. "
    "Choose by WHAT the question is about:\n"
    "- a list, one by one (compras, gastos, recebimentos) -> the transactions tools;\n"
    "- totals per person or per category (quanto cada um gastou, quem gastou mais, onde mais "
    "gastei) -> the spending summary tools.\n"
    "Then choose by WHO the question is about:\n"
    "- the person talking (eu, meu, minha, gastei) -> get_my_transactions or "
    "get_my_spending_summary;\n"
    "- the couple or the house (nós, nosso, a gente, casa, por pessoa, quem gastou mais) -> "
    "get_household_transactions or get_household_spending_summary, which already say whose "
    "each line is. Never answer a question about the couple with a get_my_* tool.\n"
    "Internal transfers between the people of the household are already left out of the "
    "tools' results.\n"
    "Use the totals the tools return as they are. For any other math (difference, percentage, "
    "split, average, a sum the tools did not return) call calculate: never do math yourself. "
    "Say which period you consulted. Never mention tool names to the user."
)

LANGUAGE_REMINDER = (
    "Reminder: your whole answer must be in Brazilian Portuguese, direct and sharp-eyed."
)


@dynamic_prompt
def _system_prompt(request: ModelRequest[HawkContext]) -> str:
    """The model has no clock and no idea who is talking: both go in every call."""
    return (
        f"{HAWK_SYSTEM_PROMPT}\n\n{HAWK_TOOLS_PROMPT}\n\n"
        f"{_people_prompt(request.runtime.context)}\n\n"  # type: ignore[arg-type]
        f"Today is {today().isoformat()}.\n\n"
        f"{LANGUAGE_REMINDER}"
    )


def build_hawk():
    """Builds Hawk, the spending specialist. No checkpointer yet: it keeps no history."""
    return create_agent(
        model=build_chat_model(),
        tools=[
            get_my_transactions,
            get_household_transactions,
            get_my_spending_summary,
            get_household_spending_summary,
            calculate,
        ],
        middleware=[_system_prompt],
        context_schema=HawkContext,
        name="hawk",
    )


@cache
def get_hawk():
    """The compiled agent, built once and shared: the user comes in each call's context."""
    return build_hawk()
