from functools import cache

from langchain.agents import create_agent
from langchain.agents.middleware import ModelRequest, dynamic_prompt

from agents.common.chat_model import build_chat_model
from agents.common.checkpointer import get_checkpointer
from agents.common.clock import today
from agents.tally.context import TallyContext
from agents.tools.accounts import (
    get_household_bank_accounts,
    get_household_credit_cards,
    get_my_bank_accounts,
    get_my_credit_cards,
)
from agents.tools.calculator import calculate
from agents.tools.entries import get_household_entries, get_my_entries
from agents.tools.transactions import (
    get_household_spending_summary,
    get_household_transactions,
    get_my_spending_summary,
    get_my_transactions,
)

TALLY_AI_SYSTEM_PROMPT = (
    "You are Tally AI, a personal finance assistant for a couple. "
    "You help make sense of financial entries, bank reconciliations, and expenses—both on an individual basis and for the household. "
    "Always respond in Brazilian Portuguese, in a clear and objective manner. "
    "Format your response in markdown, with lists and tables when they help. "
    "Even so, be direct: answer the question first, in as few words as possible, "
    "and do not add introductions, summaries, repetitions, or extra suggestions that were not asked for. "
    "Formatting must organize the answer, never make it longer. "
    "Never invent amounts, dates, or transactions; if you do not have the information, state that you do not know."
)

TALLY_AI_TOOLS_PROMPT = (
    "Always call a tool to read the real data before answering. "
    "First choose the tool by WHAT the question is about:\n"
    "- transactions, gastos, compras, recebimentos (one by one, a list) "
    "-> the transactions tools;\n"
    "- totals per person or per category: quanto cada um gastou, quem gastou mais, por pessoa, "
    "por categoria, onde mais gastei -> the spending summary tools;\n"
    "- financial entries (lançamentos): previsto, planejado, a pagar, a receber, contas do mês, "
    "vencimento, atrasado, parcela, conciliado -> the entries tools;\n"
    "- bank accounts: saldo, conta, conta corrente, poupança, cheque especial, quanto tenho "
    "-> the bank accounts tools;\n"
    "- credit cards: cartão, fatura, limite, vencimento da fatura, pagamento mínimo "
    "-> the credit cards tools.\n"
    "Then choose by WHO the question is about:\n"
    "- the person talking (eu, meu, minha, gastei) -> get_my_transactions, "
    "get_my_spending_summary, get_my_entries, get_my_bank_accounts or get_my_credit_cards;\n"
    "- the couple or the house (nós, nosso, a gente, casa, vocês, por pessoa, quem gastou mais) "
    "-> get_household_transactions, get_household_spending_summary, get_household_entries, "
    "get_household_bank_accounts or get_household_credit_cards, "
    "which already say whose each line is. "
    "Never answer a question about the couple with a get_my_* tool, and never say you cannot "
    "see the partner's data: the get_household_* tools have it.\n"
    "Entries are what was planned or expected; transactions are money that really moved in the "
    "bank: never mix the two. "
    "A credit card's open invoice is money owed, not money the person has: never mix it with "
    "the bank balance.\n"
    "Use the totals the tools return as they are. For any other math (difference, percentage, "
    "split, average, a sum the tools did not return) call calculate: never do math yourself. "
    "Say which period you consulted (for transactions and entries) or the last update date "
    "(for accounts and cards). Never mention tool names to the user."
)


def _people_prompt(context: TallyContext) -> str:
    """Who is talking and who the partner is: the tools name each owner by first name."""
    me = context.user.first_name
    text = (
        f"You are talking to {me}. In the tool results, the owner column uses first names: "
        f'"eu", "meu", "minha", "gastei" mean {me}.'
    )
    if not context.partner_names:
        return text + " No other person is in the household yet."
    partners = " and ".join(context.partner_names)
    return (
        f"{text} The other person in the household is {partners}: "
        '"ele", "ela", "meu marido", "minha esposa", "meu parceiro", "minha parceira" '
        f"mean {partners}."
    )


@dynamic_prompt
def _system_prompt(request: ModelRequest[TallyContext]) -> str:
    """The model has no clock and no idea who is talking: both go in every call."""
    return (
        f"{TALLY_AI_SYSTEM_PROMPT}\n\n{TALLY_AI_TOOLS_PROMPT}\n\n"
        f"{_people_prompt(request.runtime.context)}\n\n"
        f"Today is {today().isoformat()}."
    )


def build_tally_ai():
    """Builds the Tally AI orchestrator agent."""
    return create_agent(
        model=build_chat_model(),
        tools=[
            get_my_transactions,
            get_household_transactions,
            get_my_spending_summary,
            get_household_spending_summary,
            get_my_entries,
            get_household_entries,
            get_my_bank_accounts,
            get_household_bank_accounts,
            get_my_credit_cards,
            get_household_credit_cards,
            calculate,
        ],
        middleware=[_system_prompt],
        context_schema=TallyContext,
        checkpointer=get_checkpointer(),
        name="tally_ai",
    )


@cache
def get_tally_ai():
    """The compiled agent, built once and shared: the user comes in each call's context."""
    return build_tally_ai()
