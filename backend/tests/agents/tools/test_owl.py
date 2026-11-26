import unittest
from types import SimpleNamespace
from unittest.mock import patch

from langchain_core.messages import AIMessage, HumanMessage, ToolMessage

from agents.owl.context import OwlContext
from agents.tally.context import TallyContext
from agents.tools.owl import CANDIDATES_HEADER, ask_owl
from tests.factories import make_user

MODULE = "agents.tools.owl"
LINE_A = "candidate ab12cd34 | NETFLIX.COM | - | EXPENSES | DEBIT | 39.90 | 5 | 3 | 0.82 | Ana | ..."
LINE_B = "candidate ffff0000 | Academia | - | EXPENSES | DEBIT | 120.00 | 10 | 4 | 0.90 | Bruno | ..."


def suggestion(*lines, name="suggest_household_recurrences"):
    content = "\n".join(
        ["Recurrence candidates found ...", "candidate id | description", *lines]
    )
    return ToolMessage(content=content, name=name, tool_call_id="1")


class TestAskOwl(unittest.TestCase):
    def setUp(self):
        self.user = make_user(first_name="Ana")
        self.runtime = SimpleNamespace(
            context=TallyContext(user=self.user, partner_names=("Bruno",))
        )
        get_owl = patch(f"{MODULE}.get_owl")
        self.get_owl = get_owl.start()
        self.addCleanup(get_owl.stop)
        invoke = patch(f"{MODULE}.invoke_subagent")
        self.invoke = invoke.start()
        self.addCleanup(invoke.stop)
        self.invoke.return_value = [AIMessage(content="Nada novo.")]

    def test_owl_gets_the_request_and_the_user_from_tallys_context_not_from_the_model(
        self,
    ):
        ask_owl.func(request="recorrências da casa", runtime=self.runtime)

        agent, request, context = self.invoke.call_args.args
        self.assertIs(agent, self.get_owl.return_value)
        self.assertEqual(request, "recorrências da casa")
        self.assertEqual(context, OwlContext(user=self.user, partner_names=("Bruno",)))

    def test_without_candidates_it_returns_only_what_owl_answered(self):
        self.assertEqual(ask_owl.func(request="x", runtime=self.runtime), "Nada novo.")

    def test_the_candidate_lines_of_the_rules_come_after_owls_answer(self):
        self.invoke.return_value = [
            HumanMessage(content="x"),
            suggestion(LINE_A, LINE_B),
            AIMessage(content="Achei Netflix e Academia."),
        ]

        result = ask_owl.func(request="x", runtime=self.runtime)

        self.assertTrue(result.startswith("Achei Netflix e Academia."))
        self.assertIn(CANDIDATES_HEADER, result)
        self.assertIn(LINE_A, result)
        self.assertIn(LINE_B, result)
        # Only the header row of CANDIDATES_HEADER, not the one of the tool
        self.assertEqual(result.count("candidate id | description"), 1)

    def test_repeated_lines_and_other_tools_are_left_out(self):
        self.invoke.return_value = [
            suggestion(LINE_A, name="suggest_my_recurrences"),
            suggestion(LINE_A, LINE_B, name="suggest_household_recurrences"),
            suggestion("candidate 99999999 | Fake", name="other_tool"),
            AIMessage(content="ok"),
        ]

        result = ask_owl.func(request="x", runtime=self.runtime)

        self.assertEqual(result.count(LINE_A), 1)
        self.assertNotIn("99999999", result)

    def test_the_model_only_sees_the_request_argument(self):
        self.assertEqual(list(ask_owl.args), ["request"])
