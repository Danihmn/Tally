import unittest
import uuid
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from agents.common.context import AgentContext
from agents.tools.accounts import (
    get_household_bank_accounts,
    get_household_credit_cards,
    get_my_bank_accounts,
    get_my_credit_cards,
)
from domain.read_models import BankAccountWithOwner
from tests.factories import (
    HOUSEHOLD_ID,
    USER_ID,
    fake_get_session,
    make_bank_account,
    make_bank_data,
    make_credit_data,
    make_user,
    utc,
)

MODULE = "agents.tools.accounts"
PARTNER_ID = uuid.UUID("00000000-0000-0000-0000-00000000b002")
ALL_TOOLS = (
    get_my_bank_accounts,
    get_household_bank_accounts,
    get_my_credit_cards,
    get_household_credit_cards,
)


def make_card(**overrides):
    values = {
        "type": "CREDIT",
        "subtype": "CREDIT_CARD",
        "name": "Mastercard Platinum",
        "number": "1234",
        "balance": Decimal("142.41"),
    }
    values.update(overrides)
    return make_bank_account(**values)


class ToolTestCase(unittest.TestCase):
    """Patches the services of the tools' module (no database, no model)."""

    def setUp(self):
        self.user = make_user(first_name="Ana")
        self.partner = make_user(id=PARTNER_ID, first_name="Bia")
        self.runtime = SimpleNamespace(context=AgentContext(user=self.user))

        self.mocks = {}
        for name in (
            "search_bank_accounts",
            "get_bank_data_by_bank_account_id",
            "get_credit_data_by_bank_account_id",
            "owner_names",
        ):
            patcher = patch(f"{MODULE}.{name}")
            self.mocks[name] = patcher.start()
            self.addCleanup(patcher.stop)
        session_patcher = patch(f"{MODULE}.get_session", fake_get_session(MagicMock()))
        session_patcher.start()
        self.addCleanup(session_patcher.stop)

        self.mocks["search_bank_accounts"].return_value = []
        self.mocks["get_bank_data_by_bank_account_id"].return_value = None
        self.mocks["get_credit_data_by_bank_account_id"].return_value = None
        self.mocks["owner_names"].return_value = {
            self.user.id: "Ana",
            self.partner.id: "Bia",
        }

    def search_kwargs(self):
        return self.mocks["search_bank_accounts"].call_args.kwargs

    def accounts(self, *pairs):
        """pairs of (account, owner user id)."""
        self.mocks["search_bank_accounts"].return_value = [
            BankAccountWithOwner(account=a, user_id=owner) for a, owner in pairs
        ]


class ScopeTests(ToolTestCase):
    def test_my_tools_are_filtered_by_user_and_household(self):
        for tool in (get_my_bank_accounts, get_my_credit_cards):
            tool.func(runtime=self.runtime)

            kwargs = self.search_kwargs()
            self.assertEqual(kwargs["user_id"], USER_ID)
            self.assertEqual(kwargs["household_id"], HOUSEHOLD_ID)

    def test_household_tools_are_not_filtered_by_user(self):
        for tool in (get_household_bank_accounts, get_household_credit_cards):
            tool.func(runtime=self.runtime)

            kwargs = self.search_kwargs()
            self.assertIsNone(kwargs["user_id"])
            self.assertEqual(kwargs["household_id"], HOUSEHOLD_ID)

    def test_bank_tools_read_only_bank_accounts(self):
        for tool in (get_my_bank_accounts, get_household_bank_accounts):
            tool.func(runtime=self.runtime)
            self.assertEqual(self.search_kwargs()["account_type"], "BANK")

    def test_card_tools_read_only_credit_cards(self):
        for tool in (get_my_credit_cards, get_household_credit_cards):
            tool.func(runtime=self.runtime)
            self.assertEqual(self.search_kwargs()["account_type"], "CREDIT")

    def test_accounts_of_disconnected_banks_are_left_out(self):
        for tool in ALL_TOOLS:
            tool.func(runtime=self.runtime)
            self.assertTrue(self.search_kwargs()["only_active"])

    def test_the_user_and_the_household_are_not_arguments_of_the_model(self):
        for tool in ALL_TOOLS:
            self.assertNotIn("runtime", tool.args)
            self.assertNotIn("user_id", tool.args)
            self.assertNotIn("household_id", tool.args)

    def test_household_result_says_the_scope(self):
        result = get_household_bank_accounts.func(runtime=self.runtime)
        self.assertIn("Scope: the whole household", result)

        result = get_my_credit_cards.func(runtime=self.runtime)
        self.assertIn("Scope: only the logged user's accounts", result)


class BankAccountsOutputTests(ToolTestCase):
    def test_no_accounts_says_so(self):
        result = get_my_bank_accounts.func(runtime=self.runtime)
        self.assertIn("No bank accounts found.", result)

    def test_lines_have_owner_balances_and_the_total(self):
        mine = make_bank_account(
            id=uuid.uuid4(), marketing_name="GOLD Conta Corrente", balance=Decimal("1200.50")
        )
        partners = make_bank_account(
            id=uuid.uuid4(),
            subtype="SAVINGS_ACCOUNT",
            owner="BIA HOLDER",
            balance=Decimal("-50.25"),
        )
        self.accounts((mine, USER_ID), (partners, PARTNER_ID))
        self.mocks["get_bank_data_by_bank_account_id"].side_effect = [
            make_bank_data(
                closing_balance=Decimal("1300.50"),
                automatically_invested_balance=Decimal("10.00"),
                overdraft_contracted_limit=Decimal("500.00"),
                overdraft_used_limit=Decimal("0.00"),
            ),
            None,
        ]

        result = get_household_bank_accounts.func(runtime=self.runtime)

        self.assertIn(
            "Ana | TEST HOLDER | GOLD Conta Corrente | conta corrente | 0001/12345-0 | "
            "1200.50 | 1300.50 | 10.00 | 500.00 | 0.00 | BRL | 2026-11-10",
            result,
        )
        self.assertIn(
            "Bia | BIA HOLDER | Conta Corrente | poupança | 0001/12345-0 | "
            "-50.25 | - | - | - | - | BRL | 2026-11-10",
            result,
        )
        self.assertIn("2 bank accounts.", result)
        self.assertIn("Total available balance (BRL): 1150.25", result)

    def test_the_cpf_is_never_sent_to_the_model(self):
        self.accounts((make_bank_account(tax_number="333.333.333-33"), USER_ID))

        result = get_my_bank_accounts.func(runtime=self.runtime)

        self.assertNotIn("333.333.333-33", result)

    def test_account_without_balance_is_not_counted_in_the_total(self):
        self.accounts(
            (make_bank_account(id=uuid.uuid4(), balance=None), USER_ID),
            (make_bank_account(id=uuid.uuid4(), balance=Decimal("10.00")), USER_ID),
        )

        result = get_my_bank_accounts.func(runtime=self.runtime)

        self.assertIn("Total available balance (BRL): 10.00", result)

    def test_unknown_owner_shows_a_question_mark(self):
        self.accounts((make_bank_account(), uuid.uuid4()))

        result = get_household_bank_accounts.func(runtime=self.runtime)

        self.assertIn("? | TEST HOLDER", result)

    def test_a_salary_account_is_explained_to_the_model(self):
        self.accounts(
            (
                make_bank_account(
                    id=uuid.uuid4(),
                    name="Conta Salário",
                    outgoing_transfers_are_income=True,
                    bank_code="001",
                ),
                USER_ID,
            ),
            (make_bank_account(id=uuid.uuid4(), name="Conta Corrente"), USER_ID),
        )

        result = get_my_bank_accounts.func(runtime=self.runtime)

        self.assertIn("Conta Salário (Ana) is a salary account", result)
        self.assertNotIn("Conta Corrente (Ana) is a salary account", result)


class CreditCardsOutputTests(ToolTestCase):
    def test_no_cards_says_so(self):
        result = get_my_credit_cards.func(runtime=self.runtime)
        self.assertIn("No credit cards found.", result)

    def test_lines_have_invoice_limits_and_dates(self):
        self.accounts((make_card(), USER_ID))
        self.mocks["get_credit_data_by_bank_account_id"].return_value = make_credit_data(
            brand="MASTERCARD",
            level="PLATINUM",
            status="ACTIVE",
            credit_limit=Decimal("5000.00"),
            available_credit_limit=Decimal("4857.59"),
            minimum_payment=Decimal("50.00"),
            balance_close_date=utc(2026, 11, 3),
            balance_due_date=utc(2026, 11, 12),
        )

        result = get_my_credit_cards.func(runtime=self.runtime)

        self.assertIn(
            "Ana | TEST HOLDER | Mastercard Platinum | MASTERCARD | PLATINUM | 1234 | MAIN | "
            "ACTIVE | 142.41 | 5000.00 | 4857.59 | 50.00 | 2026-11-03 | 2026-11-12 | BRL | "
            "2026-11-10",
            result,
        )
        self.assertIn("Total open invoice (BRL): 142.41", result)
        self.assertIn(
            "Total credit limit (BRL): 5000.00; total available limit (BRL): 4857.59", result
        )

    def test_limit_totals_leave_out_additional_cards_but_invoices_count(self):
        main = make_card(id=uuid.uuid4(), balance=Decimal("100.00"))
        extra = make_card(id=uuid.uuid4(), balance=Decimal("30.00"))
        self.accounts((main, USER_ID), (extra, PARTNER_ID))
        self.mocks["get_credit_data_by_bank_account_id"].side_effect = [
            make_credit_data(
                credit_limit=Decimal("1000.00"), available_credit_limit=Decimal("870.00")
            ),
            make_credit_data(
                holder_type="ADDITIONAL",
                credit_limit=Decimal("1000.00"),
                available_credit_limit=Decimal("870.00"),
            ),
        ]

        result = get_household_credit_cards.func(runtime=self.runtime)

        self.assertIn("Total open invoice (BRL): 130.00", result)
        self.assertIn(
            "Total credit limit (BRL): 1000.00; total available limit (BRL): 870.00", result
        )

    def test_card_without_credit_data_shows_dashes(self):
        self.accounts((make_card(), USER_ID))

        result = get_my_credit_cards.func(runtime=self.runtime)

        self.assertIn(
            "Ana | TEST HOLDER | Mastercard Platinum | - | - | 1234 | - | - | 142.41 | - | - | "
            "- | - | - | BRL | 2026-11-10",
            result,
        )
        self.assertNotIn("Total credit limit", result)

    def test_card_data_is_read_for_each_card(self):
        card = make_card(id=uuid.uuid4())
        self.accounts((card, USER_ID))

        get_my_credit_cards.func(runtime=self.runtime)

        self.assertEqual(
            self.mocks["get_credit_data_by_bank_account_id"].call_args.args[1], card.id
        )
        self.mocks["get_bank_data_by_bank_account_id"].assert_not_called()


if __name__ == "__main__":
    unittest.main()
