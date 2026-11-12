import unittest
import uuid
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from agents.tally.context import TallyContext
from presentation.app import app
from infra.database.session import get_db
from presentation.dependencies.auth import get_current_user
from tests.factories import make_user

MODULE = "presentation.routers.tally_router"


def _agent_answering(content):
    agent = MagicMock()
    agent.invoke.return_value = {"messages": [SimpleNamespace(content="ignored"), SimpleNamespace(content=content)]}
    return agent


class ChatEndpointTests(unittest.TestCase):
    def setUp(self):
        self.user = make_user()
        app.dependency_overrides[get_current_user] = lambda: self.user
        app.dependency_overrides[get_db] = lambda: MagicMock()
        self.addCleanup(app.dependency_overrides.clear)
        # Not used as a context manager: the lifespan (webhook registration) does not run
        self.client = TestClient(app)

        patcher = patch(f"{MODULE}.get_tally_ai")
        self.get_agent = patcher.start()
        self.addCleanup(patcher.stop)
        self.agent = _agent_answering("Você gastou R$ 100,00.")
        self.get_agent.return_value = self.agent

        patcher = patch(f"{MODULE}.list_users_by_household")
        self.list_users = patcher.start()
        self.addCleanup(patcher.stop)
        self.list_users.return_value = [self.user, make_user(id=uuid.uuid4(), first_name="Partner")]

    def _chat(self, message="Quanto gastei?"):
        return self.client.post("/tally/chat", json={"message": message})

    def test_returns_the_text_of_the_last_message(self):
        response = self._chat()

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"answer": "Você gastou R$ 100,00."})

    def test_the_question_is_a_user_message_and_the_user_comes_in_the_context(self):
        self._chat("Quanto gastei?")

        args, kwargs = self.agent.invoke.call_args
        self.assertEqual(args[0], {"messages": [{"role": "user", "content": "Quanto gastei?"}]})
        self.assertEqual(kwargs["context"], TallyContext(user=self.user, partner_names=("Partner",)))

    def test_content_in_blocks_is_joined_as_text(self):
        self.get_agent.return_value = _agent_answering(
            [{"type": "text", "text": "Olá, "}, {"type": "tool_use", "id": "x"}, "mundo"]
        )

        self.assertEqual(self._chat().json()["answer"], "Olá, mundo")

    def test_requires_authentication(self):
        app.dependency_overrides.clear()

        response = self._chat()

        self.assertEqual(response.status_code, 401)
        self.agent.invoke.assert_not_called()

    def test_empty_message_is_rejected(self):
        self.assertEqual(self._chat("").status_code, 422)
        self.agent.invoke.assert_not_called()

    def test_failure_of_the_agent_is_a_503(self):
        self.agent.invoke.side_effect = ConnectionError("ollama is down")

        response = self._chat()

        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json()["detail"], "AI unavailable")

    def test_empty_answer_is_a_503(self):
        self.get_agent.return_value = _agent_answering("   ")

        self.assertEqual(self._chat().status_code, 503)
