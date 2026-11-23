import datetime
import unittest
import uuid
from decimal import Decimal
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from domain.read_models import AccountBalance, BankAccountWithOwner, CardBill
from services.common.exceptions import InvalidDataError, NotFoundError
from infra.database.session import get_db
from presentation.app import app
from presentation.dependencies.auth import get_current_user
from tests.factories import (
    HOUSEHOLD_ID,
    make_bank_account,
    make_credit_data,
    make_transaction,
    make_user,
    utc,
)

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
        self.assertFalse(item["outgoing_transfers_are_income"])
        self.assertIsNone(item["bank_code"])

    def test_the_holder_tax_number_is_never_in_the_answer(self):
        account = make_bank_account()
        self.search.return_value = [BankAccountWithOwner(account=account, user_id=OWNER_ID)]

        item = self.client.get("/bank-accounts").json()[0]

        self.assertNotIn("tax_number", item)
        self.assertNotIn("333.333.333-33", str(item))

    def test_without_a_token_it_is_unauthorized(self):
        app.dependency_overrides.pop(get_current_user)

        self.assertEqual(self.client.get("/bank-accounts").status_code, 401)


class _BalanceEndpointsTestCase(unittest.TestCase):
    TARGET = ""

    def setUp(self):
        self.session = MagicMock()
        self.current_user = make_user()

        def _get_db():
            yield self.session

        app.dependency_overrides[get_db] = _get_db
        app.dependency_overrides[get_current_user] = lambda: self.current_user
        self.addCleanup(app.dependency_overrides.clear)
        self.client = TestClient(app)

        patcher = patch(f"{MODULE}.{self.TARGET}")
        self.service = patcher.start()
        self.addCleanup(patcher.stop)


class TotalBalanceEndpointTests(_BalanceEndpointsTestCase):
    """GET /bank-accounts/total-balance: the total of the Contas screen."""

    TARGET = "get_total_balance"

    def setUp(self):
        super().setUp()
        self.service.return_value = Decimal("3500.75")

    def test_answers_with_the_type_and_the_total(self):
        response = self.client.get("/bank-accounts/total-balance", params={"type": "BANK"})

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"type": "BANK", "total": "3500.75"})

    def test_the_household_comes_from_the_logged_user(self):
        self.client.get("/bank-accounts/total-balance", params={"type": "CREDIT"})

        args = self.service.call_args.args
        self.assertEqual(args[1:], (HOUSEHOLD_ID, "CREDIT", None))

    def test_the_person_filter_is_passed_on(self):
        self.client.get(
            "/bank-accounts/total-balance",
            params={"type": "BANK", "user_id": str(OWNER_ID)},
        )

        self.assertEqual(self.service.call_args.args[3], OWNER_ID)

    def test_the_type_is_required(self):
        response = self.client.get("/bank-accounts/total-balance")

        self.assertEqual(response.status_code, 422)
        self.service.assert_not_called()

    def test_an_unknown_type_is_rejected(self):
        response = self.client.get("/bank-accounts/total-balance", params={"type": "LOAN"})

        self.assertEqual(response.status_code, 422)

    def test_a_household_sent_in_the_request_is_rejected(self):
        response = self.client.get(
            "/bank-accounts/total-balance",
            params={"type": "BANK", "household_id": str(OTHER_HOUSEHOLD_ID)},
        )

        self.assertEqual(response.status_code, 422)
        self.service.assert_not_called()

    def test_is_not_taken_as_an_account_id(self):
        response = self.client.get("/bank-accounts/total-balance", params={"type": "BANK"})

        self.assertNotEqual(response.status_code, 404)

    def test_without_a_token_it_is_unauthorized(self):
        app.dependency_overrides.pop(get_current_user)

        response = self.client.get("/bank-accounts/total-balance", params={"type": "BANK"})

        self.assertEqual(response.status_code, 401)


class ListBalancesEndpointTests(_BalanceEndpointsTestCase):
    """GET /bank-accounts/balances: the accounts and cards of the Contas screen."""

    TARGET = "list_account_balances"

    def setUp(self):
        super().setUp()
        self.service.return_value = []

    def test_the_household_comes_from_the_logged_user(self):
        response = self.client.get("/bank-accounts/balances")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(self.service.call_args.args[1:], (HOUSEHOLD_ID, None, None))

    def test_the_type_and_the_person_are_passed_on(self):
        self.client.get(
            "/bank-accounts/balances",
            params={"type": "CREDIT", "user_id": str(OWNER_ID)},
        )

        self.assertEqual(self.service.call_args.args[1:], (HOUSEHOLD_ID, "CREDIT", OWNER_ID))

    def test_a_household_sent_in_the_request_is_rejected(self):
        response = self.client.get(
            "/bank-accounts/balances", params={"household_id": str(OTHER_HOUSEHOLD_ID)}
        )

        self.assertEqual(response.status_code, 422)
        self.service.assert_not_called()

    def test_an_unknown_type_is_rejected(self):
        self.assertEqual(
            self.client.get("/bank-accounts/balances", params={"type": "LOAN"}).status_code, 422
        )

    def test_a_bank_account_has_its_balance_and_no_credit_info(self):
        account = make_bank_account(marketing_name="Nubank", balance=Decimal("2301.45"))
        self.service.return_value = [AccountBalance(account=account, user_id=OWNER_ID)]

        item = self.client.get("/bank-accounts/balances").json()[0]

        self.assertEqual(item["id"], str(account.id))
        self.assertEqual(item["user_id"], str(OWNER_ID))
        self.assertEqual((item["type"], item["subtype"]), ("BANK", "CHECKING_ACCOUNT"))
        self.assertEqual(item["marketing_name"], "Nubank")
        self.assertEqual(item["number"], "0001/12345-0")
        self.assertEqual(item["balance"], "2301.45")
        self.assertIsNone(item["credit"])

    def test_the_salary_account_settings_are_in_the_answer(self):
        account = make_bank_account(outgoing_transfers_are_income=True, bank_code="001")
        self.service.return_value = [AccountBalance(account=account, user_id=OWNER_ID)]

        item = self.client.get("/bank-accounts/balances").json()[0]

        self.assertTrue(item["outgoing_transfers_are_income"])
        self.assertEqual(item["bank_code"], "001")

    def test_a_card_has_its_limits(self):
        account = make_bank_account(
            type="CREDIT", subtype="CREDIT_CARD", number="1234", balance=Decimal("142.41")
        )
        credit = make_credit_data(
            credit_limit=Decimal("51800.00"),
            available_credit_limit=Decimal("51300.00"),
            balance_due_date=utc(2026, 11, 17),
        )
        self.service.return_value = [
            AccountBalance(account=account, user_id=OWNER_ID, credit_data=credit)
        ]

        item = self.client.get("/bank-accounts/balances").json()[0]

        self.assertEqual(item["balance"], "142.41")
        self.assertEqual(item["credit"]["credit_limit"], "51800.00")
        self.assertEqual(item["credit"]["available_credit_limit"], "51300.00")
        self.assertTrue(item["credit"]["balance_due_date"].startswith("2026-11-17"))
        self.assertIsNone(item["credit"]["balance_close_date"])

    def test_the_holder_tax_number_is_never_in_the_answer(self):
        self.service.return_value = [
            AccountBalance(account=make_bank_account(), user_id=OWNER_ID)
        ]

        item = self.client.get("/bank-accounts/balances").json()[0]

        self.assertNotIn("tax_number", item)
        self.assertNotIn("333.333.333-33", str(item))

    def test_without_a_token_it_is_unauthorized(self):
        app.dependency_overrides.pop(get_current_user)

        self.assertEqual(self.client.get("/bank-accounts/balances").status_code, 401)


class UpdateBankAccountEndpointTests(unittest.TestCase):
    """PATCH /bank-accounts/{id}: the "Conta salário" setting of the Contas screen."""

    def setUp(self):
        self.session = MagicMock()
        self.current_user = make_user()

        def _get_db():
            yield self.session

        app.dependency_overrides[get_db] = _get_db
        app.dependency_overrides[get_current_user] = lambda: self.current_user
        self.addCleanup(app.dependency_overrides.clear)
        self.client = TestClient(app)

        self.account = make_bank_account(outgoing_transfers_are_income=True, bank_code="001")
        self.mocks = {}
        for name in ("update_bank_account_settings", "reclassify_internal_transfers"):
            patcher = patch(f"{MODULE}.{name}")
            self.mocks[name] = patcher.start()
            self.addCleanup(patcher.stop)
        self.mocks["update_bank_account_settings"].return_value = (
            BankAccountWithOwner(account=self.account, user_id=OWNER_ID),
            True,
        )
        self.url = f"/bank-accounts/{self.account.id}"

    def _patch(self, body):
        return self.client.patch(self.url, json=body)

    def test_only_the_sent_fields_go_to_the_service_in_the_users_household(self):
        response = self._patch({"outgoing_transfers_are_income": True, "bank_code": "001"})

        self.assertEqual(response.status_code, 200)
        self.mocks["update_bank_account_settings"].assert_called_once_with(
            self.session,
            HOUSEHOLD_ID,
            self.account.id,
            {"outgoing_transfers_are_income": True, "bank_code": "001"},
        )

    def test_a_change_reclassifies_the_household_and_commits(self):
        item = self._patch({"outgoing_transfers_are_income": True}).json()

        self.mocks["reclassify_internal_transfers"].assert_called_once_with(
            self.session, HOUSEHOLD_ID
        )
        self.session.commit.assert_called_once()
        self.assertTrue(item["outgoing_transfers_are_income"])
        self.assertEqual(item["bank_code"], "001")
        self.assertEqual(item["user_id"], str(OWNER_ID))

    def test_nothing_changed_means_no_reclassification(self):
        self.mocks["update_bank_account_settings"].return_value = (
            BankAccountWithOwner(account=self.account, user_id=OWNER_ID),
            False,
        )

        self.assertEqual(self._patch({"bank_code": "001"}).status_code, 200)

        self.mocks["reclassify_internal_transfers"].assert_not_called()

    def test_the_bank_code_can_be_removed_with_null(self):
        self._patch({"bank_code": None})

        self.assertEqual(
            self.mocks["update_bank_account_settings"].call_args.args[3],
            {"bank_code": None},
        )

    def test_a_bad_body_is_rejected_before_the_service(self):
        for body in (
            {},
            {"bank_code": "1"},
            {"bank_code": "abcd"},
            {"outgoing_transfers_are_income": None},
            {"name": "Outra"},
        ):
            with self.subTest(body=body):
                self.assertEqual(self._patch(body).status_code, 422)
        self.mocks["update_bank_account_settings"].assert_not_called()

    def test_an_account_outside_the_household_is_not_found(self):
        self.mocks["update_bank_account_settings"].side_effect = NotFoundError("x")

        self.assertEqual(self._patch({"bank_code": "001"}).status_code, 404)
        self.session.commit.assert_not_called()

    def test_a_card_or_the_flag_without_a_code_is_invalid(self):
        self.mocks["update_bank_account_settings"].side_effect = InvalidDataError("x")

        response = self._patch({"outgoing_transfers_are_income": True})

        self.assertEqual(response.status_code, 422)
        self.session.commit.assert_not_called()

    def test_without_a_token_it_is_unauthorized(self):
        app.dependency_overrides.pop(get_current_user)

        self.assertEqual(self._patch({"bank_code": "001"}).status_code, 401)


class CardBillEndpointTests(_BalanceEndpointsTestCase):
    """GET /bank-accounts/{id}/bill: the bill of a card for one due month."""

    TARGET = "get_card_bill"
    CARD_ID = uuid.UUID("00000000-0000-0000-0000-00000000a009")

    def setUp(self):
        super().setUp()
        self.card = make_bank_account(id=self.CARD_ID, type="CREDIT", subtype="CREDIT_CARD")
        self.installment = make_transaction(
            date=utc(2026, 11, 20),
            amount=Decimal("30.00"),
            type="DEBIT",
            status="PENDING",
            description="Loja",
            credit_card_metadata={"installmentNumber": 1, "totalInstallments": 10},
        )
        self.service.return_value = CardBill(
            account=self.card,
            month=datetime.date(2026, 12, 1),
            total=Decimal("30.00"),
            estimated=True,
            transactions=[self.installment],
        )
        today = patch(f"{MODULE}.today_local", return_value=datetime.date(2026, 11, 23))
        today.start()
        self.addCleanup(today.stop)

    def _get(self, **params):
        return self.client.get(f"/bank-accounts/{self.CARD_ID}/bill", params=params)

    def test_without_a_month_it_is_the_bill_due_next_month(self):
        response = self._get()

        self.assertEqual(response.status_code, 200)
        self.service.assert_called_once_with(
            self.session, HOUSEHOLD_ID, self.CARD_ID, datetime.date(2026, 12, 1)
        )

    def test_december_rolls_over_to_january(self):
        with patch(f"{MODULE}.today_local", return_value=datetime.date(2026, 12, 31)):
            self._get()

        self.assertEqual(self.service.call_args.args[3], datetime.date(2027, 1, 1))

    def test_the_month_sent_is_used(self):
        self._get(month="2027-03")

        self.assertEqual(self.service.call_args.args[3], datetime.date(2027, 3, 1))

    def test_a_bad_month_is_rejected(self):
        for month in ("2027-13", "2027-3", "march", "2027-03-01"):
            with self.subTest(month=month):
                self.assertEqual(self._get(month=month).status_code, 422)
        self.service.assert_not_called()

    def test_the_response_has_the_total_and_the_installment_of_each_transaction(self):
        body = self._get().json()

        self.assertEqual(body["account_id"], str(self.CARD_ID))
        self.assertEqual(body["month"], "2026-12")
        self.assertEqual(Decimal(body["total"]), Decimal("30.00"))
        self.assertTrue(body["estimated"])
        [item] = body["transactions"]
        self.assertEqual(item["id"], str(self.installment.id))
        self.assertEqual((item["installment_number"], item["total_installments"]), (1, 10))
        self.assertEqual(item["description"], "Loja")

    def test_a_card_that_is_not_found_is_404(self):
        self.service.side_effect = NotFoundError("Credit card not found")

        self.assertEqual(self._get().status_code, 404)

    def test_needs_a_logged_user(self):
        app.dependency_overrides.pop(get_current_user)

        self.assertEqual(self._get().status_code, 401)


if __name__ == "__main__":
    unittest.main()
