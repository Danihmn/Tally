from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

ENV_FILE = Path(__file__).parent / ".env"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=ENV_FILE, extra="ignore")

    database_url: str
    jwt_secret_key: str
    jwt_algorithm: str
    access_token_expire_minutes: int
    # How long a refresh token lives. Each use rotates it, so this is the time away from the app before a new login
    refresh_token_expire_days: int = 30
    encryption_key: str
    # Public HTTPS base url Pluggy reaches this backend at (e.g. an ngrok url). Unset skips the webhook registration
    public_base_url: str | None = None
    # Local Ollama server and chat model used by the AI agents
    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = "llama3.2:latest"
    # OpenAI model on AWS Bedrock. When the key is filled, the agents use it instead of Ollama
    bedrock_api_key: str | None = None
    bedrock_base_url: str | None = None
    bedrock_model: str | None = None
    # Context size (tokens the model reads) at which a Tally AI conversation is full. Copied to conversations.token_limit
    conversation_token_limit: int = 50_000


settings = Settings()  # type: ignore
