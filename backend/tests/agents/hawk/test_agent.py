import datetime
import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from agents.hawk.agent import (
    HAWK_SYSTEM_PROMPT,
    LANGUAGE_REMINDER,
    _system_prompt,
    build_hawk,
    get_hawk,
)
from agents.hawk.context import HawkContext
from agents.tools.calculator import calculate
from agents.tools.transactions import (
    get_household_spending_summary,
    get_household_transactions,
    get_my_spending_summary,
    get_my_transactions,
)
from tests.factories import make_user


@patch("agents.hawk.agent.create_agent")
@patch("agents.hawk.agent.build_chat_model")
class TestBuildHawk(unittest.TestCase):
    def test_agent_gets_the_transaction_tools_the_calculator_and_the_context_schema(
        self, build_chat_model, create_agent
    ):
        agent = build_hawk()

        kwargs = create_agent.call_args.kwargs
        self.assertIs(kwargs["model"], build_chat_model.return_value)
        self.assertEqual(
            kwargs["tools"],
            [
                get_my_transactions,
                get_household_transactions,
                get_my_spending_summary,
                get_household_spending_summary,
                calculate,
            ],
        )
        self.assertIs(kwargs["context_schema"], HawkContext)
        self.assertEqual(kwargs["middleware"], [_system_prompt])
        self.assertEqual(kwargs["name"], "hawk")
        self.assertIs(agent, create_agent.return_value)

    def test_agent_keeps_no_history_yet(self, build_chat_model, create_agent):
        build_hawk()

        self.assertNotIn("checkpointer", create_agent.call_args.kwargs)


class TestSystemPrompt(unittest.TestCase):
    def test_prompt_has_the_persona_the_tools_the_person_and_todays_date(self):
        with patch("agents.hawk.agent.today", return_value=datetime.date(2026, 11, 10)):
            text = _system_prompt_text()

        self.assertIn(HAWK_SYSTEM_PROMPT, text)
        for name in (
            "get_my_transactions",
            "get_household_transactions",
            "get_my_spending_summary",
            "get_household_spending_summary",
            "calculate",
        ):
            self.assertIn(name, text)
        self.assertIn("You are talking to Ana.", text)
        self.assertIn("The other person in the household is Bruno", text)
        self.assertIn("Today is 2026-11-10.", text)

    def test_prompt_has_a_sharp_eyed_personality(self):
        self.assertIn("You are Hawk", HAWK_SYSTEM_PROMPT)
        self.assertIn("sharp eye", HAWK_SYSTEM_PROMPT)

    def test_prompt_demands_brazilian_portuguese_and_ends_with_the_reminder(self):
        text = _system_prompt_text()

        self.assertIn("ALWAYS answer 100% in Brazilian Portuguese", text)
        self.assertTrue(text.endswith(LANGUAGE_REMINDER))


def _system_prompt_text() -> str:
    """Runs the dynamic prompt function and returns the text it builds."""
    captured = {}
    context = HawkContext(user=make_user(first_name="Ana"), partner_names=("Bruno",))

    class _Request:
        runtime = SimpleNamespace(context=context)

        def override(self, **kwargs):
            captured.update(kwargs)
            return self

    _system_prompt.wrap_model_call(_Request(), MagicMock())  # type: ignore[arg-type]
    message = captured["system_message"]
    return message.content if hasattr(message, "content") else str(message)


class TestGetHawk(unittest.TestCase):
    def test_the_agent_is_built_only_once(self):
        get_hawk.cache_clear()
        self.addCleanup(get_hawk.cache_clear)

        with patch("agents.hawk.agent.build_hawk") as build:
            first = get_hawk()
            second = get_hawk()

        build.assert_called_once()
        self.assertIs(first, second)
