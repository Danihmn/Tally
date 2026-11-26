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
from agents.common.subagents import CONSULTED_RULE
from agents.tools.hawk import ask_hawk
from agents.tools.recurrence_detection import (
    create_suggested_recurrence,
    suggest_household_recurrences,
    suggest_my_recurrences,
)
from tests.factories import make_user


@patch("agents.tally.agent.create_agent")
@patch("agents.tally.agent.build_chat_model")
class TestBuildTallyAi(unittest.TestCase):
    def test_agent_gets_hawk_instead_of_the_transaction_tools_and_the_other_query_tools(self, build_chat_model, create_agent):
        agent = build_tally_ai()

        kwargs = create_agent.call_args.kwargs
        self.assertIs(kwargs["model"], build_chat_model.return_value)
        self.assertEqual(
            kwargs["tools"],
            [
                ask_hawk,
                get_my_entries,
                get_household_entries,
                get_my_recurrences,
                get_household_recurrences,
                suggest_my_recurrences,
                suggest_household_recurrences,
                create_suggested_recurrence,
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
        for name in (
            "ask_hawk",
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

    def test_transactions_are_asked_to_hawk_and_the_old_tools_are_gone_from_the_prompt(self):
        text = _system_prompt_text()

        for name in (
            "get_my_transactions",
            "get_household_transactions",
            "get_my_spending_summary",
            "get_household_spending_summary",
        ):
            self.assertNotIn(name, text)
        self.assertIn("-> ask_hawk", text)
        self.assertIn("Hawk does not see the conversation", text)

    def test_prompt_makes_tally_say_it_consulted_the_specialist(self):
        text = _system_prompt_text()

        self.assertIn(CONSULTED_RULE, text)
        self.assertIn("Consultei o Hawk", text)

    def test_prompt_demands_brazilian_portuguese_and_ends_with_the_reminder(self):
        text = _system_prompt_text()

        self.assertIn("ALWAYS answer 100% in Brazilian Portuguese", text)
        self.assertTrue(text.endswith(LANGUAGE_REMINDER))

    def test_prompt_asks_for_a_friendly_tone(self):
        self.assertIn("friendly and warm", TALLY_AI_SYSTEM_PROMPT)

    def test_answers_do_not_always_open_with_a_greeting_but_it_is_not_forbidden(self):
        self.assertIn("do NOT open every answer with a greeting", TALLY_AI_SYSTEM_PROMPT)
        self.assertIn("fine only now and then", TALLY_AI_SYSTEM_PROMPT)
        self.assertNotIn("call the person by name", TALLY_AI_SYSTEM_PROMPT)
        self.assertNotIn("NEVER start an answer", TALLY_AI_SYSTEM_PROMPT)

    def test_planning_questions_use_recurrences_and_entries(self):
        text = _system_prompt_text()

        self.assertIn("planejamento", text)
        self.assertIn("the recurrences tools (what repeats every month) AND the entries tools", text)

    def test_suggested_recurrences_are_created_only_after_the_person_confirms(self):
        text = _system_prompt_text()

        self.assertIn("suggest_my_recurrences or suggest_household_recurrences (read only)", text)
        self.assertIn("create_suggested_recurrence ONLY after the person confirms a specific candidate", text)
        self.assertIn("Never create a recurrence on your own initiative", text)

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
    def test_the_prompt_says_who_is_talking_and_who_the_partner_is(self):
        text = _system_prompt_text(make_user(first_name="Ana", surname="Aninha"), ("Bibi",))

        self.assertIn("You are talking to Aninha.", text)
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
