import unittest
import uuid
from decimal import Decimal
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from domain.read_models import BankAccountWithOwner
from infra.database.session import get_db
from presentation.app import app
from presentation.dependencies.auth import get_current_user
from tests.factories import HOUSEHOLD_ID, make_bank_account, make_user

MODULE = "presentation.routers.bank_accounts_router"
OTHER_HOUSEHOLD_ID = uuid.UUID("00000000-0000-0000-0000-00000000c002")
OWNER_ID = uuid.UUID("00000000-0000-0000-0000-00000000b002")


class ListBankAccountsEndpointTests(unittest.TestCase):
    """GET /bank-accounts: the accounts the Transactions screen names and filters by."""

    def setUp(self):
        self.session = MagicMock()
        self.current_user = make_user()

        def _get_db():
            yield self.session

        app.dependency_overrides[get_db] = _get_db
        app.dependency_overrides[get_current_user] = lambda: self.current_user
        self.addCleanup(app.dependency_overrides.clear)
        self.client = TestClient(app)

        patcher = patch(f"{MODULE}.search_bank_accounts")
        self.search = patcher.start()
        self.addCleanup(patcher.stop)
        self.search.return_value = []

    def test_the_household_comes_from_the_logged_user(self):
        response = self.client.get("/bank-accounts")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(self.search.call_args.kwargs["household_id"], HOUSEHOLD_ID)

    def test_a_household_sent_in_the_request_is_rejected(self):
        response = self.client.get(
            "/bank-accounts", params={"household_id": str(OTHER_HOUSEHOLD_ID)}
        )

        self.assertEqual(response.status_code, 422)
        self.search.assert_not_called()

    def test_accounts_of_removed_connections_are_not_left_out(self):
        self.client.get("/bank-accounts")

        # The AI agent asks for only_active=True. The app must not: the transactions of an
        # account of a removed connection are still stored and need its name.
        self.assertNotIn("only_active", self.search.call_args.kwargs)

    def test_the_other_filters_are_passed_on(self):
        self.client.get(
            "/bank-accounts",
            params={"user_id": str(OWNER_ID), "type": "CREDIT", "limit": 100, "offset": 100},
        )

        kwargs = self.search.call_args.kwargs
        self.assertEqual(kwargs["user_id"], OWNER_ID)
        self.assertEqual(kwargs["account_type"], "CREDIT")
        self.assertEqual((kwargs["limit"], kwargs["offset"]), (100, 100))

    def test_the_page_defaults_to_50(self):
        self.client.get("/bank-accounts")

        kwargs = self.search.call_args.kwargs
        self.assertEqual((kwargs["limit"], kwargs["offset"]), (50, 0))

    def test_a_limit_out_of_range_is_rejected(self):
        for limit in (0, 101):
            with self.subTest(limit=limit):
                self.assertEqual(
                    self.client.get("/bank-accounts", params={"limit": limit}).status_code, 422
                )

    def test_an_unknown_type_is_rejected(self):
        self.assertEqual(self.client.get("/bank-accounts", params={"type": "LOAN"}).status_code, 422)

    def test_answers_with_a_plain_list_and_the_owner_of_each_account(self):
        account = make_bank_account(marketing_name="Nubank", balance=Decimal("2301.45"))
        self.search.return_value = [BankAccountWithOwner(account=account, user_id=OWNER_ID)]

        response = self.client.get("/bank-accounts")

        body = response.json()
        self.assertEqual(len(body), 1)
        item = body[0]
        self.assertEqual(item["id"], str(account.id))
        self.assertEqual(item["user_id"], str(OWNER_ID))
        self.assertEqual(item["name"], "Conta Corrente")
        self.assertEqual(item["marketing_name"], "Nubank")
        self.assertEqual(item["number"], "0001/12345-0")
        self.assertEqual((item["type"], item["subtype"]), ("BANK", "CHECKING_ACCOUNT"))
        self.assertEqual(item["balance"], "2301.45")

    def test_the_holder_tax_number_is_never_in_the_answer(self):
        account = make_bank_account()
        self.search.return_value = [BankAccountWithOwner(account=account, user_id=OWNER_ID)]

        item = self.client.get("/bank-accounts").json()[0]

        self.assertNotIn("tax_number", item)
        self.assertNotIn("333.333.333-33", str(item))

    def test_without_a_token_it_is_unauthorized(self):
        app.dependency_overrides.pop(get_current_user)

        self.assertEqual(self.client.get("/bank-accounts").status_code, 401)


if __name__ == "__main__":
    unittest.main()
