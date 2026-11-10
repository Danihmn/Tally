import unittest

from infra.repositories.exceptions import (
    ConstraintViolationError,
    DatabaseConnectionError,
    DuplicateRecordError,
    ForeignKeyViolationError,
    RecordNotFoundError,
    RepositoryError,
)
from services.exceptions import (
    AlreadyExistsError,
    InvalidDataError,
    NotFoundError,
    ServiceError,
    ServiceUnavailableError,
    translate_repository_errors,
)


def _raising(error: Exception):
    @translate_repository_errors
    def service():
        raise error

    return service


class TranslateRepositoryErrorsTests(unittest.TestCase):
    def test_each_repository_error_becomes_its_service_error(self):
        cases = {
            RecordNotFoundError: NotFoundError,
            DuplicateRecordError: AlreadyExistsError,
            ForeignKeyViolationError: InvalidDataError,
            ConstraintViolationError: InvalidDataError,
            DatabaseConnectionError: ServiceUnavailableError,
            RepositoryError: ServiceError,
        }
        for repository_error, service_error in cases.items():
            with self.subTest(repository_error=repository_error.__name__):
                original = repository_error("users", "get_user_by_id")

                with self.assertRaises(service_error) as raised:
                    _raising(original)()

                self.assertIs(type(raised.exception), service_error)
                self.assertIs(raised.exception.__cause__, original)
                self.assertEqual(str(raised.exception), "users.get_user_by_id failed")

    def test_unknown_subclass_becomes_the_base_service_error(self):
        class OtherRepositoryError(RepositoryError):
            pass

        with self.assertRaises(ServiceError) as raised:
            _raising(OtherRepositoryError("users", "op"))()

        self.assertIs(type(raised.exception), ServiceError)

    def test_other_errors_pass_through(self):
        with self.assertRaises(ValueError):
            _raising(ValueError("boom"))()

    def test_return_value_and_arguments_are_kept(self):
        @translate_repository_errors
        def service(a, b=0):
            return a + b

        self.assertEqual(service(1, b=2), 3)
        self.assertEqual(service.__name__, "service")


if __name__ == "__main__":
    unittest.main()
