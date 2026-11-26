import datetime
import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from agents.owl.agent import (
    LANGUAGE_REMINDER,
    OWL_SYSTEM_PROMPT,
    _system_prompt,
    build_owl,
    get_owl,
)
from agents.owl.context import OwlContext
from agents.tools.calculator import calculate
from agents.tools.entries import get_household_entries, get_my_entries
from agents.tools.recurrence_detection import (
    suggest_household_recurrences,
    suggest_my_recurrences,
)
from agents.tools.recurrences import get_household_recurrences, get_my_recurrences
from tests.factories import make_user


@patch("agents.owl.agent.create_agent")
@patch("agents.owl.agent.build_chat_model")
class TestBuildOwl(unittest.TestCase):
    def test_agent_gets_the_planning_tools_the_suggest_tools_and_the_calculator(
        self, build_chat_model, create_agent
    ):
        agent = build_owl()

        kwargs = create_agent.call_args.kwargs
        self.assertIs(kwargs["model"], build_chat_model.return_value)
        self.assertEqual(
            kwargs["tools"],
            [
                get_my_entries,
                get_household_entries,
                get_my_recurrences,
                get_household_recurrences,
                suggest_my_recurrences,
                suggest_household_recurrences,
                calculate,
            ],
        )
        self.assertIs(kwargs["context_schema"], OwlContext)
        self.assertEqual(kwargs["middleware"], [_system_prompt])
        self.assertEqual(kwargs["name"], "owl")
        self.assertIs(agent, create_agent.return_value)

    def test_agent_cannot_create_recurrences(self, build_chat_model, create_agent):
        build_owl()

        names = [t.name for t in create_agent.call_args.kwargs["tools"]]
        self.assertNotIn("create_suggested_recurrence", names)

    def test_agent_keeps_no_history(self, build_chat_model, create_agent):
        build_owl()

        self.assertNotIn("checkpointer", create_agent.call_args.kwargs)


class TestSystemPrompt(unittest.TestCase):
    def test_prompt_has_the_persona_the_tools_the_person_and_todays_date(self):
        with patch("agents.owl.agent.today", return_value=datetime.date(2026, 11, 10)):
            text = _system_prompt_text()

        self.assertIn(OWL_SYSTEM_PROMPT, text)
        for name in (
            "get_my_entries",
            "get_household_entries",
            "get_my_recurrences",
            "get_household_recurrences",
            "suggest_my_recurrences",
            "suggest_household_recurrences",
            "calculate",
        ):
            self.assertIn(name, text)
        self.assertIn("You are talking to Ana.", text)
        self.assertIn("The other person in the household is Bruno", text)
        self.assertIn("Today is 2026-11-10.", text)

    def test_prompt_says_owl_only_suggests_and_keeps_the_candidate_ids(self):
        text = _system_prompt_text()

        self.assertIn("You are Owl, the planning specialist", OWL_SYSTEM_PROMPT)
        self.assertIn("You only READ and SUGGEST: you cannot create or change anything", text)
        self.assertIn("keep its id exactly as the tool wrote it", text)

    def test_planning_requests_read_the_recurrences_and_the_entries(self):
        text = _system_prompt_text()

        self.assertIn(
            "the recurrences tools (what repeats every month) AND the entries tools", text
        )
        self.assertIn("never mix the two", text)

    def test_prompt_demands_brazilian_portuguese_and_ends_with_the_reminder(self):
        text = _system_prompt_text()

        self.assertIn("ALWAYS answer 100% in Brazilian Portuguese", text)
        self.assertTrue(text.endswith(LANGUAGE_REMINDER))


def _system_prompt_text() -> str:
    """Runs the dynamic prompt function and returns the text it builds."""
    captured = {}
    context = OwlContext(user=make_user(first_name="Ana"), partner_names=("Bruno",))

    class _Request:
        runtime = SimpleNamespace(context=context)

        def override(self, **kwargs):
            captured.update(kwargs)
            return self

    _system_prompt.wrap_model_call(_Request(), MagicMock())  # type: ignore[arg-type]
    message = captured["system_message"]
    return message.content if hasattr(message, "content") else str(message)


class TestGetOwl(unittest.TestCase):
    def test_the_agent_is_built_only_once(self):
        get_owl.cache_clear()
        self.addCleanup(get_owl.cache_clear)

        with patch("agents.owl.agent.build_owl") as build:
            first = get_owl()
            second = get_owl()

        build.assert_called_once()
        self.assertIs(first, second)
