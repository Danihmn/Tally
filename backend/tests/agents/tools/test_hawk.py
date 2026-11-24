import unittest
from types import SimpleNamespace
from unittest.mock import patch

from agents.hawk.context import HawkContext
from agents.tally.context import TallyContext
from agents.tools.hawk import ask_hawk
from tests.factories import make_user

MODULE = "agents.tools.hawk"


class TestAskHawk(unittest.TestCase):
    def setUp(self):
        self.user = make_user(first_name="Ana")
        self.runtime = SimpleNamespace(
            context=TallyContext(user=self.user, partner_names=("Bruno",))
        )
        get_hawk = patch(f"{MODULE}.get_hawk")
        self.get_hawk = get_hawk.start()
        self.addCleanup(get_hawk.stop)
        run = patch(f"{MODULE}.run_subagent", return_value="Análise do Hawk")
        self.run = run.start()
        self.addCleanup(run.stop)

    def test_returns_what_hawk_answered(self):
        result = ask_hawk.func(request="gastos da casa em novembro", runtime=self.runtime)

        self.assertEqual(result, "Análise do Hawk")

    def test_hawk_gets_the_request_and_the_user_from_tallys_context_not_from_the_model(self):
        ask_hawk.func(request="gastos da casa em novembro", runtime=self.runtime)

        agent, request, context = self.run.call_args.args
        self.assertIs(agent, self.get_hawk.return_value)
        self.assertEqual(request, "gastos da casa em novembro")
        self.assertEqual(context, HawkContext(user=self.user, partner_names=("Bruno",)))

    def test_the_model_only_sees_the_request_argument(self):
        self.assertEqual(list(ask_hawk.args), ["request"])
