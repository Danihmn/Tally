import unittest
import uuid
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from domain.entities import Conversation
from infra.repositories.common.exceptions import RecordNotFoundError
from services import conversations_service
from services.common.exceptions import NotFoundError
from tests.factories import USER_ID, make_conversation, utc

MODULE = "services.conversations_service"


def _row(**overrides):
    values = {
        "id": uuid.uuid4(),
        "user_id": USER_ID,
        "title": "Quanto gastei?",
        "total_input_tokens": 0,
        "total_output_tokens": 0,
        "context_tokens": 0,
        "token_limit": 50_000,
        "last_message_at": None,
        "created_at": utc(2026, 11, 1),
        "updated_at": None,
        "deleted_at": None,
    }
    values.update(overrides)
    return SimpleNamespace(**values)


class StartConversationTests(unittest.TestCase):
    def _start(self, message):
        with (
            patch(f"{MODULE}.conversations_repository") as repository,
            patch(f"{MODULE}.settings", MagicMock(conversation_token_limit=50_000)),
        ):
            repository.create_conversation.side_effect = lambda session, values: _row(**values)
            conversation = conversations_service.start_conversation(MagicMock(), USER_ID, message)
        return conversation, repository.create_conversation.call_args.args[1]

    def test_creates_an_entity_for_the_user_with_the_default_limit(self):
        conversation, values = self._start("Quanto gastei?")

        self.assertIsInstance(conversation, Conversation)
        self.assertEqual(values["user_id"], USER_ID)
        self.assertEqual(values["token_limit"], 50_000)

    def test_the_title_is_the_first_question_on_one_line(self):
        _, values = self._start("Quanto   gastei\nno mercado?")

        self.assertEqual(values["title"], "Quanto gastei no mercado?")

    def test_a_long_first_question_is_cut_with_an_ellipsis(self):
        _, values = self._start("palavra " * 30)

        self.assertLessEqual(len(values["title"]), conversations_service.TITLE_MAX_LENGTH)
        self.assertTrue(values["title"].endswith("…"))


class LimitTests(unittest.TestCase):
    def setUp(self):
        patcher = patch(f"{MODULE}.settings", MagicMock(conversation_token_limit=50_000))
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_the_conversation_limit_wins_over_the_default(self):
        self.assertEqual(conversations_service.token_limit_of(make_conversation(token_limit=1000)), 1000)

    def test_a_conversation_without_limit_uses_the_default(self):
        self.assertEqual(conversations_service.token_limit_of(make_conversation(token_limit=None)), 50_000)

    def test_below_the_limit_is_not_full(self):
        conversation = make_conversation(token_limit=1000, context_tokens=999)

        self.assertFalse(conversations_service.is_limit_reached(conversation))

    def test_at_the_limit_is_full(self):
        conversation = make_conversation(token_limit=1000, context_tokens=1000)

        self.assertTrue(conversations_service.is_limit_reached(conversation))


class GetConversationTests(unittest.TestCase):
    def test_looks_the_conversation_up_by_id_and_user(self):
        row = _row()
        conversation_id = uuid.uuid4()

        with patch(f"{MODULE}.conversations_repository") as repository:
            repository.get_conversation_for_user.return_value = row
            conversation = conversations_service.get_conversation(MagicMock(), conversation_id, USER_ID)

        self.assertEqual(conversation.id, row.id)
        self.assertEqual(repository.get_conversation_for_user.call_args.args[1:], (conversation_id, USER_ID))

    def test_a_conversation_that_is_not_the_users_is_a_not_found_error(self):
        with patch(f"{MODULE}.conversations_repository") as repository:
            repository.get_conversation_for_user.side_effect = RecordNotFoundError("conversations", "get")
            with self.assertRaises(NotFoundError):
                conversations_service.get_conversation(MagicMock(), uuid.uuid4(), USER_ID)


class ListConversationsTests(unittest.TestCase):
    def test_returns_the_page_and_the_total(self):
        rows = [_row(), _row()]

        with patch(f"{MODULE}.conversations_repository") as repository:
            repository.list_conversations_by_user.return_value = rows
            repository.count_conversations_by_user.return_value = 7
            items, total = conversations_service.list_conversations(MagicMock(), USER_ID, 2, 4)

        self.assertEqual([c.id for c in items], [r.id for r in rows])
        self.assertEqual(total, 7)
        self.assertEqual(repository.list_conversations_by_user.call_args.args[1:], (USER_ID, 2, 4))


class RecordTurnTests(unittest.TestCase):
    def _record(self, row, input_tokens, output_tokens, context_tokens):
        with patch(f"{MODULE}.conversations_repository") as repository:
            repository.get_conversation_for_user.return_value = row
            repository.update_conversation.side_effect = lambda session, model, values: SimpleNamespace(
                **{**vars(model), **values}
            )
            updated = conversations_service.record_turn(
                MagicMock(), row.id, USER_ID, input_tokens, output_tokens, context_tokens
            )
        return updated, repository.update_conversation.call_args.args[2]

    def test_totals_grow_and_the_context_is_replaced(self):
        row = _row(total_input_tokens=1000, total_output_tokens=100, context_tokens=900)

        updated, _ = self._record(row, input_tokens=2000, output_tokens=150, context_tokens=1800)

        self.assertEqual(updated.total_input_tokens, 3000)
        self.assertEqual(updated.total_output_tokens, 250)
        self.assertEqual(updated.context_tokens, 1800)

    def test_marks_the_time_of_the_last_message(self):
        _, values = self._record(_row(), 10, 5, 10)

        self.assertIsNotNone(values["last_message_at"])
        self.assertEqual(values["last_message_at"], values["updated_at"])
