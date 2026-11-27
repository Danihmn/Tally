import unittest

from infra.security.refresh_tokens import generate_refresh_token, hash_refresh_token


class GenerateRefreshTokenTests(unittest.TestCase):
    def test_each_token_is_different(self):
        self.assertNotEqual(generate_refresh_token(), generate_refresh_token())

    def test_token_is_long_enough_to_not_be_guessed(self):
        self.assertGreaterEqual(len(generate_refresh_token()), 64)


class HashRefreshTokenTests(unittest.TestCase):
    def test_same_token_gives_the_same_hash(self):
        self.assertEqual(hash_refresh_token("abc"), hash_refresh_token("abc"))

    def test_different_tokens_give_different_hashes(self):
        self.assertNotEqual(hash_refresh_token("abc"), hash_refresh_token("abd"))

    def test_hash_does_not_contain_the_token(self):
        self.assertNotIn("abc", hash_refresh_token("abc"))
        self.assertEqual(len(hash_refresh_token("abc")), 64)
