from functools import cache

from langchain.agents import create_agent
from langchain.agents.middleware import ModelRequest, dynamic_prompt
from langchain_ollama import ChatOllama
from langchain_openai import ChatOpenAI

from agents.clock import today
from agents.context import TallyContext
from agents.tools.accounts import (
    get_household_bank_accounts,
    get_household_credit_cards,
    get_my_bank_accounts,
    get_my_credit_cards,
)
from agents.tools.transactions import get_household_transactions, get_my_transactions
from settings import settings

TALLY_AI_SYSTEM_PROMPT = (
    "You are Tally AI, a personal finance assistant for a couple. "
    "You help make sense of financial entries, bank reconciliations, and expenses—both on an individual basis and for the household. "
    "Always respond in Brazilian Portuguese, in a clear and objective manner. "
    "Never invent amounts, dates, or transactions; if you do not have the information, state that you do not know."
)

TALLY_AI_TOOLS_PROMPT = (
    "Always call a tool to read the real data before answering. "
    "First choose the tool by WHAT the question is about:\n"
    "- transactions, gastos, compras, recebimentos -> the transactions tools;\n"
    "- bank accounts: saldo, conta, conta corrente, poupança, cheque especial, quanto tenho "
    "-> the bank accounts tools;\n"
    "- credit cards: cartão, fatura, limite, vencimento, pagamento mínimo "
    "-> the credit cards tools.\n"
    "Then choose by WHO the question is about:\n"
    "- the person talking (eu, meu, minha, gastei) -> get_my_transactions, "
    "get_my_bank_accounts or get_my_credit_cards;\n"
    "- the couple or the house (nós, nosso, a gente, casa, vocês, por pessoa, quem gastou mais) "
    "-> get_household_transactions, get_household_bank_accounts or get_household_credit_cards, "
    "which already say whose each line is. "
    "Never answer a question about the couple with a get_my_* tool, and never say you cannot "
    "see the partner's data: the get_household_* tools have it.\n"
    "A credit card's open invoice is money owed, not money the person has: never mix it with "
    "the bank balance. "
    "The tools already return the totals: never add amounts yourself. "
    "Say which period you consulted (for transactions) or the last update date (for accounts "
    "and cards). Never mention tool names to the user."
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


def _build_chat_model():
    """OpenAI model on Bedrock when BEDROCK_API_KEY is filled (production), Ollama otherwise (dev)."""
    if not settings.bedrock_api_key:
        return ChatOllama(
            model=settings.ollama_model, base_url=settings.ollama_base_url
        )

    if not settings.bedrock_model or not settings.bedrock_base_url:
        raise ValueError(
            "BEDROCK_API_KEY is set, so BEDROCK_MODEL and BEDROCK_BASE_URL must be set too"
        )
    return ChatOpenAI(
        model=settings.bedrock_model,
        api_key=settings.bedrock_api_key,  # type: ignore
        base_url=settings.bedrock_base_url,
    )


def build_tally_ai():
    """Builds the Tally AI orchestrator agent."""
    return create_agent(
        model=_build_chat_model(),
        tools=[
            get_my_transactions,
            get_household_transactions,
            get_my_bank_accounts,
            get_household_bank_accounts,
            get_my_credit_cards,
            get_household_credit_cards,
        ],
        middleware=[_system_prompt],
        context_schema=TallyContext,
        name="tally_ai",
    )


@cache
def get_tally_ai():
    """The compiled agent, built once and shared: the user comes in each call's context."""
    return build_tally_ai()
