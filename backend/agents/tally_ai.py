from langchain.agents import create_agent
from langchain_ollama import ChatOllama
from langchain_openai import ChatOpenAI

from settings import settings

TALLY_AI_SYSTEM_PROMPT = (
    "You are Tally AI, a personal finance assistant for a couple."
    "You help make sense of financial entries, bank reconciliations, and expenses—both on an individual basis and for the household."
    "Always respond in Brazilian Portuguese, in a clear and objective manner."
    "Never invent amounts, dates, or transactions; if you do not have the information, state that you do not know."
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
        tools=[],
        system_prompt=TALLY_AI_SYSTEM_PROMPT,
        name="tally_ai",
    )
