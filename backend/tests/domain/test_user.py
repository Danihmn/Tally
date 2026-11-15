import unittest

from tests.factories import make_user


class DisplayNameTests(unittest.TestCase):
    def test_is_the_nickname_when_there_is_one(self):
        self.assertEqual(make_user(first_name="Ana", surname="Aninha").display_name, "Aninha")

    def test_is_the_first_name_without_a_nickname(self):
        self.assertEqual(make_user(first_name="Ana").display_name, "Ana")

    def test_a_blank_nickname_counts_as_none(self):
        self.assertEqual(make_user(first_name="Ana", surname="  ").display_name, "Ana")

    def test_the_last_name_is_never_used(self):
        self.assertEqual(make_user(first_name="Ana", last_name="Souza").display_name, "Ana")
