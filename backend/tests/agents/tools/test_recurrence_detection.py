import datetime
import unittest
import uuid
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from langchain_core.messages import AIMessage, HumanMessage, ToolMessage

from agents.common.context import AgentContext
from agents.tools.recurrence_detection import (
    create_suggested_recurrence,
    suggest_household_recurrences,
    suggest_my_recurrences,
)
from domain.recurrence_detection import Evidence, RecurrenceCandidate
from services.common.exceptions import NotFoundError
from tests.factories import HOUSEHOLD_ID, fake_get_session, make_recurrence, make_user

MODULE = "agents.tools.recurrence_detection"
PARTNER_ID = uuid.UUID("00000000-0000-0000-0000-00000000b002")
TODAY = datetime.date(2026, 11, 10)


def make_candidate(**overrides):
    values = {
        "candidate_id": "ab12cd34",
        "household_id": HOUSEHOLD_ID,
        "user_id": uuid.UUID("00000000-0000-0000-0000-00000000b001"),
        "description": "NETFLIX.COM",
        "normalized_description": "netflix com",
        "type": "EXPENSES",
        "amount": Decimal("39.90"),
        "due_day": 5,
        "category": "Streaming",
        "payment_type": "CREDIT",
        "confidence": Decimal("0.82"),
        "evidence": [
            Evidence(
                uuid.uuid4(), datetime.date(2026, m, 5), Decimal("39.90"), "NETFLIX.COM"
            )
            for m in (8, 9, 10)
        ],
    }
    values.update(overrides)
    return RecurrenceCandidate(**values)


class DetectionToolTestCase(unittest.TestCase):
    """Patches the services of the tools' module (no database, no model)."""

    def setUp(self):
        self.user = make_user(first_name="Ana")
        self.session = MagicMock()
        self.runtime = SimpleNamespace(
            context=AgentContext(user=self.user), state={"messages": []}
        )

        self.find = self._patch("find_recurrence_candidates")
        self.find.return_value = []
        self.create = self._patch("create_recurrence_from_candidate")
        self._patch("owner_names").return_value = {
            self.user.id: "Ana",
            PARTNER_ID: "Bia",
        }
        self._patch("today").return_value = TODAY
        session_patcher = patch(f"{MODULE}.get_session", fake_get_session(self.session))
        session_patcher.start()
        self.addCleanup(session_patcher.stop)

    def _patch(self, name):
        patcher = patch(f"{MODULE}.{name}")
        mock = patcher.start()
        self.addCleanup(patcher.stop)
        return mock


class SuggestToolsTests(DetectionToolTestCase):
    def test_my_suggestions_ask_only_for_the_logged_users_candidates(self):
        suggest_my_recurrences.func(runtime=self.runtime)

        args, kwargs = self.find.call_args
        self.assertEqual(args[1], HOUSEHOLD_ID)
        self.assertEqual(args[2], TODAY)
        self.assertEqual(kwargs["user_id"], self.user.id)

    def test_household_suggestions_ask_for_everyone(self):
        suggest_household_recurrences.func(runtime=self.runtime)

        self.assertIsNone(self.find.call_args.kwargs["user_id"])

    def test_each_candidate_line_has_the_id_amount_due_day_owner_and_evidence(self):
        self.find.return_value = [
            make_candidate(),
            make_candidate(
                candidate_id="ffff0000", description="Academia", user_id=PARTNER_ID
            ),
        ]

        result = suggest_household_recurrences.func(runtime=self.runtime)

        self.assertIn(
            "candidate ab12cd34 | NETFLIX.COM | Streaming | EXPENSES | CREDIT | 39.90 | 5 | 3 | 0.82 | Ana",
            result,
        )
        self.assertIn("2026-08-05 39.90, 2026-09-05 39.90, 2026-10-05 39.90", result)
        self.assertIn("candidate ffff0000 | Academia", result)
        self.assertIn("| Bia |", result)
        self.assertIn("NOT recurrences yet", result)

    def test_the_limit_cuts_the_list(self):
        self.find.return_value = [
            make_candidate(candidate_id=f"{n:08x}") for n in range(5)
        ]

        result = suggest_household_recurrences.func(runtime=self.runtime, limit=2)

        self.assertIn("Showing 2 of 5 candidates.", result)

    def test_no_candidate_says_so(self):
        result = suggest_my_recurrences.func(runtime=self.runtime)

        self.assertIn("No new monthly pattern found", result)

    def test_suggesting_creates_nothing(self):
        self.find.return_value = [make_candidate()]

        suggest_household_recurrences.func(runtime=self.runtime)

        self.create.assert_not_called()
        self.session.commit.assert_not_called()

    def test_the_user_and_the_household_are_not_arguments_of_the_model(self):
        for tool in (
            suggest_my_recurrences,
            suggest_household_recurrences,
            create_suggested_recurrence,
        ):
            self.assertNotIn("runtime", tool.args)
            self.assertNotIn("household_id", tool.args)
            self.assertNotIn("user_id", tool.args)
        self.assertEqual(set(create_suggested_recurrence.args), {"candidate_id"})


class CreateToolTests(DetectionToolTestCase):
    def shown(self, candidate_id="ab12cd34", tool_name="suggest_household_recurrences"):
        return ToolMessage(
            content=f"... candidate {candidate_id} | NETFLIX.COM | ...",
            name=tool_name,
            tool_call_id="call-1",
        )

    def with_messages(self, *messages):
        self.runtime.state = {"messages": list(messages)}

    def test_creates_and_commits_after_the_person_answered_the_suggestion(self):
        self.create.return_value = make_recurrence(
            description="NETFLIX.COM", amount=Decimal("39.90"), user_id=self.user.id
        )
        self.with_messages(
            HumanMessage("sugira recorrências"),
            self.shown(),
            AIMessage("Achei Netflix por 39,90. Quer criar?"),
            HumanMessage("sim, cria a do Netflix"),
        )

        result = create_suggested_recurrence.func(
            candidate_id=" AB12CD34 ", runtime=self.runtime
        )

        self.create.assert_called_once_with(
            self.session, HOUSEHOLD_ID, "ab12cd34", TODAY
        )
        self.session.commit.assert_called_once()
        self.assertIn("Recurrence created from candidate ab12cd34", result)
        self.assertIn("NETFLIX.COM", result)
        self.assertIn("| Ana", result)

    def test_refuses_when_the_candidate_was_never_shown(self):
        self.with_messages(HumanMessage("cria uma recorrência do Netflix"))

        result = create_suggested_recurrence.func(
            candidate_id="ab12cd34", runtime=self.runtime
        )

        self.assertTrue(result.startswith("Error:"))
        self.create.assert_not_called()

    def test_refuses_when_the_person_did_not_answer_after_the_suggestion(self):
        self.with_messages(HumanMessage("sugira recorrências"), self.shown())

        result = create_suggested_recurrence.func(
            candidate_id="ab12cd34", runtime=self.runtime
        )

        self.assertTrue(result.startswith("Error:"))
        self.create.assert_not_called()

    def test_refuses_an_id_shown_by_another_tool(self):
        self.with_messages(
            self.shown(tool_name="get_household_recurrences"), HumanMessage("sim")
        )

        result = create_suggested_recurrence.func(
            candidate_id="ab12cd34", runtime=self.runtime
        )

        self.assertTrue(result.startswith("Error:"))
        self.create.assert_not_called()

    def test_refuses_an_id_that_was_not_in_the_suggestion(self):
        self.with_messages(self.shown(), HumanMessage("sim"))

        result = create_suggested_recurrence.func(
            candidate_id="99999999", runtime=self.runtime
        )

        self.assertTrue(result.startswith("Error:"))
        self.create.assert_not_called()

    def test_a_candidate_that_is_gone_rolls_back_and_returns_an_error(self):
        self.create.side_effect = NotFoundError("Recurrence candidate not found")
        self.with_messages(self.shown(), HumanMessage("sim"))

        result = create_suggested_recurrence.func(
            candidate_id="ab12cd34", runtime=self.runtime
        )

        self.assertTrue(result.startswith("Error:"))
        self.assertIn("call a suggest tool again", result)
        self.session.rollback.assert_called_once()
        self.session.commit.assert_not_called()
