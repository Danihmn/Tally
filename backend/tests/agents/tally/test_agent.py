import datetime
import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from agents.tally.agent import (
    LANGUAGE_REMINDER,
    TALLY_AI_SYSTEM_PROMPT,
    _system_prompt,
    build_tally_ai,
    get_tally_ai,
)
from agents.tally.context import TallyContext
from agents.tools.accounts import (
    get_household_bank_accounts,
    get_household_credit_cards,
    get_my_bank_accounts,
    get_my_credit_cards,
)
from agents.tools.calculator import calculate
from agents.tools.entries import get_household_entries, get_my_entries
from agents.tools.recurrences import get_household_recurrences, get_my_recurrences
from agents.tools.transactions import (
    get_household_spending_summary,
    get_household_transactions,
    get_my_spending_summary,
    get_my_transactions,
)
from tests.factories import make_user


@patch("agents.tally.agent.create_agent")
@patch("agents.tally.agent.build_chat_model")
class TestBuildTallyAi(unittest.TestCase):
    def test_agent_gets_every_query_tool_the_calculator_and_the_context_schema(self, build_chat_model, create_agent):
        agent = build_tally_ai()

        kwargs = create_agent.call_args.kwargs
        self.assertIs(kwargs["model"], build_chat_model.return_value)
        self.assertEqual(
            kwargs["tools"],
            [
                get_my_transactions,
                get_household_transactions,
                get_my_spending_summary,
                get_household_spending_summary,
                get_my_entries,
                get_household_entries,
                get_my_recurrences,
                get_household_recurrences,
                get_my_bank_accounts,
                get_household_bank_accounts,
                get_my_credit_cards,
                get_household_credit_cards,
                calculate,
            ],
        )
        self.assertIs(kwargs["context_schema"], TallyContext)
        self.assertEqual(kwargs["middleware"], [_system_prompt])
        self.assertEqual(kwargs["name"], "tally_ai")
        self.assertIs(agent, create_agent.return_value)


class TestSystemPrompt(unittest.TestCase):
    def test_prompt_has_the_persona_the_tools_rules_and_todays_date(self):
        with patch("agents.tally.agent.today", return_value=datetime.date(2026, 11, 10)):
            text = _system_prompt_text()

        self.assertIn(TALLY_AI_SYSTEM_PROMPT, text)
        self.assertIn("get_my_transactions", text)
        self.assertIn("get_household_transactions", text)
        for name in (
            "get_my_spending_summary",
            "get_household_spending_summary",
            "get_my_entries",
            "get_household_entries",
            "get_my_recurrences",
            "get_household_recurrences",
            "calculate",
            "get_my_bank_accounts",
            "get_household_bank_accounts",
            "get_my_credit_cards",
            "get_household_credit_cards",
        ):
            self.assertIn(name, text)
        self.assertIn("Today is 2026-11-10.", text)

    def test_prompt_demands_brazilian_portuguese_and_ends_with_the_reminder(self):
        text = _system_prompt_text()

        self.assertIn("ALWAYS answer 100% in Brazilian Portuguese", text)
        self.assertTrue(text.endswith(LANGUAGE_REMINDER))

    def test_prompt_asks_for_a_friendly_tone(self):
        self.assertIn("friendly and warm", TALLY_AI_SYSTEM_PROMPT)

    def test_answers_never_open_with_the_persons_name_or_a_greeting(self):
        self.assertIn("NEVER start an answer with the person's name or a greeting", TALLY_AI_SYSTEM_PROMPT)
        self.assertNotIn("call the person by name", TALLY_AI_SYSTEM_PROMPT)

    def test_planning_questions_use_recurrences_and_entries(self):
        text = _system_prompt_text()

        self.assertIn("planejamento", text)
        self.assertIn("the recurrences tools (what repeats every month) AND the entries tools", text)

    def test_ambiguous_questions_get_one_short_question_instead_of_i_dont_know(self):
        text = _system_prompt_text()

        self.assertIn("Before saying you do not know something", text)
        self.assertIn("ask ONE short question", text)


def _system_prompt_text(user=None, partner_names=("Bruno",)) -> str:
    """Runs the dynamic prompt function and returns the text it builds."""
    captured = {}
    context = TallyContext(user=user or make_user(first_name="Ana"), partner_names=partner_names)

    class _Request:
        runtime = SimpleNamespace(context=context)

        def override(self, **kwargs):
            captured.update(kwargs)
            return self

    handler = MagicMock()
    _system_prompt.wrap_model_call(_Request(), handler)  # type: ignore[arg-type]
    message = captured["system_message"]
    return message.content if hasattr(message, "content") else str(message)


class TestPeopleInThePrompt(unittest.TestCase):
    def test_the_person_talking_is_named_by_the_nickname(self):
        text = _system_prompt_text(make_user(first_name="Ana", surname="Aninha"))

        self.assertIn("You are talking to Aninha.", text)
        self.assertNotIn("You are talking to Ana.", text)

    def test_without_a_nickname_it_is_the_first_name(self):
        text = _system_prompt_text(make_user(first_name="Ana"))

        self.assertIn("You are talking to Ana.", text)

    def test_the_partner_comes_as_the_router_named_them(self):
        text = _system_prompt_text(partner_names=("Bibi",))

        self.assertIn("The other person in the household is Bibi", text)


class TestGetTallyAi(unittest.TestCase):
    def test_the_agent_is_built_only_once(self):
        get_tally_ai.cache_clear()
        self.addCleanup(get_tally_ai.cache_clear)

        with patch("agents.tally.agent.build_tally_ai") as build:
            first = get_tally_ai()
            second = get_tally_ai()

        build.assert_called_once()
        self.assertIs(first, second)
