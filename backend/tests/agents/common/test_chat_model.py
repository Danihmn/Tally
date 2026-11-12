import unittest
from unittest.mock import MagicMock, patch

from agents.common.chat_model import build_chat_model

MODULE = "agents.common.chat_model"


def make_settings(
    bedrock_api_key=None,
    bedrock_model="openai.gpt-oss-120b-1:0",
    bedrock_base_url="https://bedrock.example/openai/v1",
):
    fake = MagicMock()
    fake.ollama_model = "llama3.2:latest"
    fake.ollama_base_url = "http://localhost:11434"
    fake.bedrock_api_key = bedrock_api_key
    fake.bedrock_model = bedrock_model
    fake.bedrock_base_url = bedrock_base_url
    return fake


@patch(f"{MODULE}.ChatOpenAI")
@patch(f"{MODULE}.ChatOllama")
class TestBuildChatModel(unittest.TestCase):
    def test_no_bedrock_key_uses_ollama_with_its_settings(self, chat_ollama, chat_openai):
        with patch(f"{MODULE}.settings", make_settings(bedrock_api_key=None)):
            model = build_chat_model()

        chat_ollama.assert_called_once_with(model="llama3.2:latest", base_url="http://localhost:11434")
        chat_openai.assert_not_called()
        self.assertIs(model, chat_ollama.return_value)

    def test_empty_bedrock_key_uses_ollama(self, chat_ollama, chat_openai):
        with patch(f"{MODULE}.settings", make_settings(bedrock_api_key="")):
            build_chat_model()

        chat_ollama.assert_called_once()
        chat_openai.assert_not_called()

    def test_filled_bedrock_key_uses_openai_on_bedrock(self, chat_ollama, chat_openai):
        with patch(f"{MODULE}.settings", make_settings(bedrock_api_key="secret")):
            model = build_chat_model()

        chat_openai.assert_called_once_with(
            model="openai.gpt-oss-120b-1:0",
            api_key="secret",
            base_url="https://bedrock.example/openai/v1",
        )
        chat_ollama.assert_not_called()
        self.assertIs(model, chat_openai.return_value)

    def test_bedrock_key_without_model_fails_instead_of_falling_back_to_ollama(self, chat_ollama, chat_openai):
        with patch(f"{MODULE}.settings", make_settings(bedrock_api_key="secret", bedrock_model=None)):
            with self.assertRaises(ValueError):
                build_chat_model()

        chat_ollama.assert_not_called()
        chat_openai.assert_not_called()

    def test_bedrock_key_without_base_url_fails(self, chat_ollama, chat_openai):
        with patch(f"{MODULE}.settings", make_settings(bedrock_api_key="secret", bedrock_base_url="")):
            with self.assertRaises(ValueError):
                build_chat_model()
