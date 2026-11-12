from langchain_ollama import ChatOllama
from langchain_openai import ChatOpenAI

from settings import settings


def build_chat_model():
    """OpenAI model on Bedrock when BEDROCK_API_KEY is filled (production), Ollama otherwise (dev).

    Shared by every agent, so they all follow the same dev/production choice."""
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
