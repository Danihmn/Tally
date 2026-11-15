import json
import unittest
import uuid
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient
from langchain_core.messages import AIMessage, AIMessageChunk, HumanMessage, ToolMessage

from agents.tally.context import TallyContext
from infra.database.session import get_db
from presentation.app import app
from presentation.dependencies.auth import get_current_user
from services.common.exceptions import NotFoundError
from tests.factories import fake_get_session, make_conversation, make_user, utc

MODULE = "presentation.routers.tally_router"

USAGE = {"input_tokens": 1200, "output_tokens": 80, "total_tokens": 1280}


def _events(response):
    """The server-sent events of a response, as (event, data) pairs."""
    events = []
    for block in response.text.strip().split("\n\n"):
        lines = dict(line.split(": ", 1) for line in block.split("\n"))
        events.append((lines["event"], json.loads(lines["data"])))
    return events


def response_text(events):
    """Everything the app would receive, as one string."""
    return json.dumps(events)


def _chunks(*texts):
    return [(AIMessageChunk(content=t), {"langgraph_node": "model"}) for t in texts]


class _Agent:
    """A fake compiled agent: streams the given pieces, and its saved messages are empty before the
    stream and `saved` after it."""

    def __init__(self, pieces, saved, fail=False):
        self.pieces = pieces
        self.saved = saved
        self.fail = fail
        self.streamed = False
        self.stream_calls = []

    def stream(self, inputs, **kwargs):
        self.stream_calls.append((inputs, kwargs))
        for piece in self.pieces:
            yield piece
        if self.fail:
            raise ConnectionError("ollama is down")
        self.streamed = True

    def get_state(self, config):
        # Messages are saved as the stream runs: what is read before it is the old history
        messages = self.saved if (self.streamed or self.fail) else []
        return SimpleNamespace(values={"messages": messages} if messages else {})


class _RouterTestCase(unittest.TestCase):
    def setUp(self):
        self.user = make_user()
        self.session = MagicMock()
        app.dependency_overrides[get_current_user] = lambda: self.user
        app.dependency_overrides[get_db] = lambda: self.session
        self.addCleanup(app.dependency_overrides.clear)
        # Not used as a context manager: the lifespan (webhook registration) does not run
        self.client = TestClient(app)

        self.stream_session = MagicMock()
        self._patch(f"{MODULE}.get_session", fake_get_session(self.stream_session))
        self.get_agent = self._patch(f"{MODULE}.get_tally_ai")
        self.list_users = self._patch(f"{MODULE}.list_users_by_household")
        self.list_users.return_value = [self.user, make_user(id=uuid.uuid4(), first_name="Partner")]

    def _patch(self, target, *args):
        patcher = patch(target, *args)
        mock = patcher.start()
        self.addCleanup(patcher.stop)
        return mock

    def _service(self, name):
        return self._patch(f"{MODULE}.conversations_service.{name}")


class ChatEndpointTests(_RouterTestCase):
    def setUp(self):
        super().setUp()
        self.conversation = make_conversation(
            user_id=self.user.id, title="Quanto gastei?", token_limit=50_000, created_at=utc(2026, 11, 1)
        )
        self.start = self._service("start_conversation")
        self.start.return_value = self.conversation
        self.get = self._service("get_conversation")
        self.get.return_value = self.conversation
        self.record = self._service("record_turn")
        self.record.return_value = make_conversation(
            id=self.conversation.id,
            context_tokens=1200,
            token_limit=50_000,
            total_input_tokens=1200,
            total_output_tokens=80,
            created_at=utc(2026, 11, 1),
        )
        self.agent = _Agent(
            _chunks("Você ", "gastou ", "**R$ 100,00**."),
            [HumanMessage(content="Quanto gastei?"), AIMessage(content="Você gastou **R$ 100,00**.", usage_metadata=USAGE)],
        )
        self.get_agent.return_value = self.agent

    def _chat(self, message="Quanto gastei?", conversation_id=None):
        return self.client.post("/tally/chat", json={"message": message, "conversation_id": conversation_id})

    def test_streams_meta_then_the_answer_pieces_then_done(self):
        response = self._chat()

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.headers["content-type"].startswith("text/event-stream"))
        events = _events(response)
        self.assertEqual([name for name, _ in events], ["meta", "token", "token", "token", "done"])
        self.assertEqual("".join(d["text"] for n, d in events if n == "token"), "Você gastou **R$ 100,00**.")

    def test_without_a_conversation_id_a_new_conversation_is_started(self):
        response = self._chat("Quanto gastei?")

        self.start.assert_called_once_with(self.session, self.user.id, "Quanto gastei?")
        self.get.assert_not_called()
        meta = _events(response)[0][1]
        self.assertEqual(meta, {"conversation_id": str(self.conversation.id), "title": "Quanto gastei?", "is_new": True})
        self.session.commit.assert_called()

    def test_with_a_conversation_id_that_conversation_continues_in_its_own_thread(self):
        response = self._chat(conversation_id=str(self.conversation.id))

        self.start.assert_not_called()
        self.get.assert_called_once_with(self.session, self.conversation.id, self.user.id)
        self.assertFalse(_events(response)[0][1]["is_new"])
        _, kwargs = self.agent.stream_calls[0]
        self.assertEqual(kwargs["config"], {"configurable": {"thread_id": str(self.conversation.id)}})

    def test_the_question_is_a_user_message_and_the_user_comes_in_the_context(self):
        self._chat("Quanto gastei?")

        inputs, kwargs = self.agent.stream_calls[0]
        self.assertEqual(inputs, {"messages": [{"role": "user", "content": "Quanto gastei?"}]})
        self.assertEqual(kwargs["context"], TallyContext(user=self.user, partner_names=("Partner",)))
        self.assertEqual(kwargs["stream_mode"], "messages")

    def test_only_the_final_answer_is_streamed_not_the_tool_calls_or_their_results(self):
        call_piece = AIMessageChunk(content="", tool_call_chunks=[{"name": "t", "args": "{}", "id": "c1", "index": 0}])
        self.agent.pieces = [
            (call_piece, {}),
            (ToolMessage(content="a | b", tool_call_id="c1"), {}),
            *_chunks("Resposta."),
        ]

        events = _events(self._chat())

        self.assertEqual([d["text"] for n, d in events if n == "token"], ["Resposta."])

    def test_the_model_reasoning_never_reaches_the_user_even_when_a_tag_is_cut(self):
        self.agent.pieces = _chunks("<reas", "oning>User asks the limit.</reas", "oning>", "Limite: ", "**R$ 5**")

        events = _events(self._chat())

        shown = "".join(d["text"] for n, d in events if n == "token")
        self.assertEqual(shown, "Limite: **R$ 5**")
        self.assertNotIn("reasoning", response_text(events))

    def test_an_answer_made_only_of_reasoning_is_an_error_event(self):
        self.agent.pieces = _chunks("<reasoning>thinking</reasoning>")

        self.assertEqual(_events(self._chat())[-1], ("error", {"code": "empty_answer"}))

    def test_a_reasoning_left_open_by_one_model_call_does_not_swallow_the_next(self):
        first = (AIMessageChunk(content="<reasoning>I will call the tool", id="run-1"), {})
        second = (AIMessageChunk(content="Resposta.", id="run-2"), {})
        self.agent.pieces = [first, second]

        events = _events(self._chat())

        self.assertEqual([d["text"] for n, d in events if n == "token"], ["Resposta."])

    def test_the_turn_usage_is_recorded_and_sent_in_done(self):
        events = _events(self._chat(conversation_id=str(self.conversation.id)))

        self.record.assert_called_once_with(
            self.stream_session, self.conversation.id, self.conversation.user_id, 1200, 80, 1200
        )
        self.stream_session.commit.assert_called_once()
        self.assertEqual(
            events[-1],
            ("done", {"context_tokens": 1200, "token_limit": 50_000, "total_input_tokens": 1200, "total_output_tokens": 80}),
        )

    def test_a_full_conversation_is_a_409_and_the_agent_is_not_called(self):
        self.get.return_value = make_conversation(user_id=self.user.id, token_limit=1000, context_tokens=1000)

        response = self._chat(conversation_id=str(uuid.uuid4()))

        self.assertEqual(response.status_code, 409)
        self.assertEqual(response.json()["detail"], "conversation_limit_reached")
        self.assertEqual(self.agent.stream_calls, [])

    def test_a_conversation_that_is_not_found_is_a_404(self):
        self.get.side_effect = NotFoundError("conversations")

        response = self._chat(conversation_id=str(uuid.uuid4()))

        self.assertEqual(response.status_code, 404)
        self.assertEqual(self.agent.stream_calls, [])

    def test_a_failure_of_the_agent_ends_with_an_error_event_and_still_counts_the_tokens(self):
        self.agent.fail = True

        events = _events(self._chat())

        self.assertEqual(events[-1], ("error", {"code": "ai_unavailable"}))
        self.assertNotIn("done", [name for name, _ in events])
        self.record.assert_called_once()

    def test_an_answer_with_no_text_is_an_error_event(self):
        self.agent.pieces = _chunks("  ")

        events = _events(self._chat())

        self.assertEqual(events[-1], ("error", {"code": "empty_answer"}))

    def test_requires_authentication(self):
        app.dependency_overrides.clear()

        self.assertEqual(self._chat().status_code, 401)
        self.start.assert_not_called()

    def test_empty_message_is_rejected(self):
        self.assertEqual(self._chat("").status_code, 422)
        self.start.assert_not_called()


class ListConversationsEndpointTests(_RouterTestCase):
    def test_returns_the_page_with_the_effective_limit(self):
        listing = self._service("list_conversations")
        first = make_conversation(
            user_id=self.user.id, title="Mercado", token_limit=None, context_tokens=500,
            created_at=utc(2026, 11, 1), last_message_at=utc(2026, 11, 2),
        )
        listing.return_value = ([first], 3)

        response = self.client.get("/tally/conversations?limit=1&offset=2")

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual((body["total"], body["limit"], body["offset"]), (3, 1, 2))
        self.assertEqual(body["items"][0]["title"], "Mercado")
        self.assertEqual(body["items"][0]["context_tokens"], 500)
        self.assertGreater(body["items"][0]["token_limit"], 0)
        listing.assert_called_once_with(self.session, self.user.id, 1, 2)

    def test_the_limit_must_be_positive(self):
        self.assertEqual(self.client.get("/tally/conversations?limit=0").status_code, 422)

    def test_requires_authentication(self):
        app.dependency_overrides.clear()

        self.assertEqual(self.client.get("/tally/conversations").status_code, 401)


class GetConversationEndpointTests(_RouterTestCase):
    def setUp(self):
        super().setUp()
        self.get = self._service("get_conversation")
        self.conversation = make_conversation(user_id=self.user.id, title="Mercado", created_at=utc(2026, 11, 1))
        self.get.return_value = self.conversation

    def test_returns_the_conversation_and_only_what_the_user_saw(self):
        call = {"name": "t", "args": {}, "id": "c1"}
        saved = [
            HumanMessage(content="Quanto gastei?", id="1"),
            AIMessage(content="", tool_calls=[call], id="2"),
            ToolMessage(content="a | b", tool_call_id="c1", id="3"),
            AIMessage(content="R$ 100,00", id="4"),
        ]
        agent = MagicMock()
        agent.get_state.return_value = SimpleNamespace(values={"messages": saved})
        self.get_agent.return_value = agent

        response = self.client.get(f"/tally/conversations/{self.conversation.id}")

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["conversation"]["title"], "Mercado")
        self.assertEqual(
            body["messages"],
            [
                {"id": "1", "role": "user", "content": "Quanto gastei?"},
                {"id": "4", "role": "assistant", "content": "R$ 100,00"},
            ],
        )
        agent.get_state.assert_called_once_with({"configurable": {"thread_id": str(self.conversation.id)}})

    def test_a_conversation_without_messages_has_an_empty_list(self):
        agent = MagicMock()
        agent.get_state.return_value = SimpleNamespace(values={})
        self.get_agent.return_value = agent

        response = self.client.get(f"/tally/conversations/{self.conversation.id}")

        self.assertEqual(response.json()["messages"], [])

    def test_a_conversation_that_is_not_the_users_is_a_404(self):
        self.get.side_effect = NotFoundError("conversations")

        response = self.client.get(f"/tally/conversations/{uuid.uuid4()}")

        self.assertEqual(response.status_code, 404)
        self.get_agent.assert_not_called()
