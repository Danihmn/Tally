import unittest
import uuid
from unittest.mock import MagicMock, call, patch

import httpx

from integrations.pluggy.exceptions.pluggy_exception_error import PluggyExceptionError
from jobs._common import JOB_ERRORS, USERS_PAGE_SIZE, iter_all_users
from services.common.exceptions import ServiceError
from tests.factories import make_user

MODULE = "jobs._common"


class TestIterAllUsers(unittest.TestCase):
    def setUp(self):
        self.session = MagicMock()
        patcher = patch(f"{MODULE}.list_users")
        self.list_users = patcher.start()
        self.addCleanup(patcher.stop)

    def test_reads_every_page_until_an_empty_one(self):
        first_page = [make_user(id=uuid.uuid4()) for _ in range(2)]
        second_page = [make_user(id=uuid.uuid4())]
        self.list_users.side_effect = [first_page, second_page, []]

        users = list(iter_all_users(self.session, page_size=2))

        self.assertEqual(users, first_page + second_page)
        self.assertEqual(
            self.list_users.call_args_list,
            [
                call(session=self.session, limit=2, offset=0),
                call(session=self.session, limit=2, offset=2),
                call(session=self.session, limit=2, offset=4),
            ],
        )

    def test_the_next_page_is_read_only_when_needed(self):
        self.list_users.side_effect = [[make_user()], []]

        users = iter_all_users(self.session)
        next(users)

        self.list_users.assert_called_once_with(
            session=self.session, limit=USERS_PAGE_SIZE, offset=0
        )

    def test_no_users_yields_nothing(self):
        self.list_users.return_value = []

        self.assertEqual(list(iter_all_users(self.session)), [])


class TestJobErrors(unittest.TestCase):
    def test_has_the_errors_one_user_can_cause(self):
        for error in (ServiceError, PluggyExceptionError, httpx.HTTPError, ValueError):
            with self.subTest(error=error.__name__):
                self.assertIn(error, JOB_ERRORS)
