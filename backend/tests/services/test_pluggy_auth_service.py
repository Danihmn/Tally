import unittest
from unittest.mock import patch

from services.pluggy_auth_service import authenticate_user
from tests.factories import make_user

MODULE = "services.pluggy_auth_service"


class TestAuthenticateUser(unittest.TestCase):
    def test_logs_in_with_the_users_client_id_and_decrypted_secret(self):
        user = make_user()

        with (
            patch(f"{MODULE}.decrypt", return_value="client-secret") as decrypt,
            patch(f"{MODULE}.authenticate", return_value="api-key") as authenticate,
        ):
            api_key = authenticate_user(user)

        decrypt.assert_called_once_with(user.pluggy_client_secret_crypto)
        authenticate.assert_called_once_with(
            client_id=user.pluggy_client_id, client_secret="client-secret"
        )
        self.assertEqual(api_key, "api-key")
