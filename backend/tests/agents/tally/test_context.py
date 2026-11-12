import unittest

from agents.common.context import AgentContext
from agents.tally.context import TallyContext
from tests.factories import make_user


class TestTallyContext(unittest.TestCase):
    def test_is_an_agent_context_so_the_shared_tools_accept_it(self):
        user = make_user()
        context = TallyContext(user=user, partner_names=("Bruno",))

        self.assertIsInstance(context, AgentContext)
        self.assertIs(context.user, user)
        self.assertEqual(context.partner_names, ("Bruno",))

    def test_partner_names_default_to_empty(self):
        self.assertEqual(TallyContext(user=make_user()).partner_names, ())
