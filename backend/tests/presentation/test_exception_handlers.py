import unittest

from fastapi import FastAPI
from fastapi.testclient import TestClient

from presentation.exception_handlers import register_exception_handlers
from services.common.exceptions import (
    AlreadyExistsError,
    EmailAlreadyExistsError,
    InvalidDataError,
    NoRecurrencesError,
)


def _client_raising(error: Exception) -> TestClient:
    app = FastAPI()
    register_exception_handlers(app)

    @app.get("/boom")
    def boom():
        raise error

    return TestClient(app)


class ExceptionHandlersTests(unittest.TestCase):
    def test_a_generic_conflict_has_no_code(self):
        response = _client_raising(AlreadyExistsError("x")).get("/boom")

        self.assertEqual(response.status_code, 409)
        self.assertEqual(response.json(), {"detail": "Record already exists"})

    def test_an_email_that_is_taken_is_a_conflict_with_its_own_code(self):
        response = _client_raising(EmailAlreadyExistsError("x")).get("/boom")

        self.assertEqual(response.status_code, 409)
        self.assertEqual(
            response.json(),
            {"detail": "Record already exists", "code": "EMAIL_ALREADY_EXISTS"},
        )

    def test_the_server_text_of_the_error_is_never_sent(self):
        response = _client_raising(EmailAlreadyExistsError("ana@casa.com")).get("/boom")

        self.assertNotIn("ana@casa.com", response.text)

    def test_no_recurrences_keeps_its_code(self):
        response = _client_raising(NoRecurrencesError("x")).get("/boom")

        self.assertEqual(response.status_code, 422)
        self.assertEqual(response.json()["code"], "NO_RECURRENCES")

    def test_other_invalid_data_has_no_code(self):
        response = _client_raising(InvalidDataError("x")).get("/boom")

        self.assertEqual(response.status_code, 422)
        self.assertNotIn("code", response.json())
