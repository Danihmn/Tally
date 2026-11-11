import datetime
import unittest
from unittest.mock import MagicMock, patch

from agents.context import TallyContext
from agents.tally_ai import (
    TALLY_AI_SYSTEM_PROMPT,
    _system_prompt,
    build_tally_ai,
    get_tally_ai,
)
from agents.tools.transactions import get_household_transactions, get_my_transactions


def make_settings(bedrock_api_key=None, bedrock_model="openai.gpt-oss-120b-1:0", bedrock_base_url="https://bedrock.example/openai/v1"):
    fake = MagicMock()
    fake.ollama_model = "llama3.2:latest"
    fake.ollama_base_url = "http://localhost:11434"
    fake.bedrock_api_key = bedrock_api_key
    fake.bedrock_model = bedrock_model
    fake.bedrock_base_url = bedrock_base_url
    return fake


@patch("agents.tally_ai.create_agent")
@patch("agents.tally_ai.ChatOpenAI")
@patch("agents.tally_ai.ChatOllama")
class TestModelChoice(unittest.TestCase):
    def test_no_bedrock_key_uses_ollama_with_its_settings(self, chat_ollama, chat_openai, create_agent):
        with patch("agents.tally_ai.settings", make_settings(bedrock_api_key=None)):
            build_tally_ai()

        chat_ollama.assert_called_once_with(model="llama3.2:latest", base_url="http://localhost:11434")
        chat_openai.assert_not_called()
        self.assertIs(create_agent.call_args.kwargs["model"], chat_ollama.return_value)

    def test_empty_bedrock_key_uses_ollama(self, chat_ollama, chat_openai, create_agent):
        with patch("agents.tally_ai.settings", make_settings(bedrock_api_key="")):
            build_tally_ai()

        chat_ollama.assert_called_once()
        chat_openai.assert_not_called()

    def test_filled_bedrock_key_uses_openai_on_bedrock(self, chat_ollama, chat_openai, create_agent):
        with patch("agents.tally_ai.settings", make_settings(bedrock_api_key="secret")):
            build_tally_ai()

        chat_openai.assert_called_once_with(
            model="openai.gpt-oss-120b-1:0",
            api_key="secret",
            base_url="https://bedrock.example/openai/v1",
        )
        chat_ollama.assert_not_called()
        self.assertIs(create_agent.call_args.kwargs["model"], chat_openai.return_value)

    def test_bedrock_key_without_model_fails_instead_of_falling_back_to_ollama(self, chat_ollama, chat_openai, create_agent):
        with patch("agents.tally_ai.settings", make_settings(bedrock_api_key="secret", bedrock_model=None)):
            with self.assertRaises(ValueError):
                build_tally_ai()

        chat_ollama.assert_not_called()
        chat_openai.assert_not_called()

    def test_bedrock_key_without_base_url_fails(self, chat_ollama, chat_openai, create_agent):
        with patch("agents.tally_ai.settings", make_settings(bedrock_api_key="secret", bedrock_base_url="")):
            with self.assertRaises(ValueError):
                build_tally_ai()


@patch("agents.tally_ai.create_agent")
@patch("agents.tally_ai.ChatOllama")
class TestBuildTallyAi(unittest.TestCase):
    def test_agent_gets_the_transaction_tools_and_the_context_schema(self, chat_ollama, create_agent):
        with patch("agents.tally_ai.settings", make_settings()):
            agent = build_tally_ai()

        kwargs = create_agent.call_args.kwargs
        self.assertEqual(kwargs["model"], chat_ollama.return_value)
        self.assertEqual(kwargs["tools"], [get_my_transactions, get_household_transactions])
        self.assertIs(kwargs["context_schema"], TallyContext)
        self.assertEqual(kwargs["middleware"], [_system_prompt])
        self.assertEqual(kwargs["name"], "tally_ai")
        self.assertIs(agent, create_agent.return_value)


class TestSystemPrompt(unittest.TestCase):
    def test_prompt_has_the_persona_the_tools_rules_and_todays_date(self):
        with patch("agents.tally_ai.today", return_value=datetime.date(2026, 11, 10)):
            text = _system_prompt_text()

        self.assertIn(TALLY_AI_SYSTEM_PROMPT, text)
        self.assertIn("get_my_transactions", text)
        self.assertIn("get_household_transactions", text)
        self.assertIn("Today is 2026-11-10.", text)


def _system_prompt_text() -> str:
    """Runs the dynamic prompt function and returns the text it builds."""
    captured = {}

    class _Request:
        def override(self, **kwargs):
            captured.update(kwargs)
            return self

    handler = MagicMock()
    _system_prompt.wrap_model_call(_Request(), handler)  # type: ignore[arg-type]
    message = captured["system_message"]
    return message.content if hasattr(message, "content") else str(message)


class TestGetTallyAi(unittest.TestCase):
    def test_the_agent_is_built_only_once(self):
        get_tally_ai.cache_clear()
        self.addCleanup(get_tally_ai.cache_clear)

        with patch("agents.tally_ai.build_tally_ai") as build:
            first = get_tally_ai()
            second = get_tally_ai()

        build.assert_called_once()
        self.assertIs(first, second)
