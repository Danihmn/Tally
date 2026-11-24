import unittest

from agents.common.people import people_prompt
from agents.hawk.context import HawkContext
from agents.tally.context import TallyContext
from tests.factories import make_user


class TestPeoplePrompt(unittest.TestCase):
    def test_the_person_talking_is_named_by_the_nickname(self):
        context = TallyContext(user=make_user(first_name="Ana", surname="Aninha"))

        text = people_prompt(context)

        self.assertIn("You are talking to Aninha.", text)
        self.assertNotIn("You are talking to Ana.", text)

    def test_without_a_nickname_it_is_the_first_name(self):
        text = people_prompt(TallyContext(user=make_user(first_name="Ana")))

        self.assertIn("You are talking to Ana.", text)

    def test_the_partner_is_named_as_the_router_loaded_them(self):
        text = people_prompt(TallyContext(user=make_user(), partner_names=("Bibi",)))

        self.assertIn("The other person in the household is Bibi", text)

    def test_without_a_partner_it_says_nobody_else_is_in_the_household(self):
        text = people_prompt(TallyContext(user=make_user()))

        self.assertIn("No other person is in the household yet.", text)

    def test_works_for_the_context_of_any_agent(self):
        context = HawkContext(user=make_user(first_name="Ana"), partner_names=("Bruno",))

        self.assertIn("Bruno", people_prompt(context))
