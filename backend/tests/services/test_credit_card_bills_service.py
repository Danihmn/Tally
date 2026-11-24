import dataclasses
import datetime
import unittest
import uuid
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from domain.read_models import AccountBalance
from services.common.exceptions import NotFoundError
from services.credit_card_bills_service import (
    get_card_bill,
    get_next_bills,
    get_next_bills_total,
)
from tests.factories import (
    ACCOUNT_ID,
    HOUSEHOLD_ID,
    USER_ID,
    make_bank_account,
    make_credit_data,
    make_transaction,
    utc,
)

MODULE = "services.credit_card_bills_service"
DEC = datetime.date(2026, 12, 1)


def _as_model(entity) -> SimpleNamespace:
    """What the repository returns: an object with the same attributes as the entity."""
    return SimpleNamespace(
        **{f.name: getattr(entity, f.name) for f in dataclasses.fields(entity)}
    )


def _card(**overrides):
    return make_bank_account(type="CREDIT", subtype="CREDIT_CARD", **overrides)


class GetCardBillTests(unittest.TestCase):
    def setUp(self):
        self.session = MagicMock()
        patchers = {
            "accounts": patch(f"{MODULE}.bank_account_repository"),
            "credit": patch(f"{MODULE}.credit_datas_repository"),
            "transactions": patch(f"{MODULE}.transactions_repository"),
        }
        self.repo = {name: p.start() for name, p in patchers.items()}
        for p in patchers.values():
            self.addCleanup(p.stop)
        self.repo["accounts"].get_bank_account_with_owner.return_value = (
            _as_model(_card()),
            USER_ID,
        )
        # Closes on 3, due on 10
        self.repo["credit"].get_credit_data_by_bank_account_id.return_value = _as_model(
            make_credit_data(
                balance_close_date=utc(2026, 12, 3, 0),
                balance_due_date=utc(2026, 12, 10, 0),
            )
        )
        self.repo["transactions"].list_card_transactions_for_bill.return_value = []

    def _stored(self, *transactions):
        self.repo["transactions"].list_card_transactions_for_bill.return_value = [
            _as_model(t) for t in transactions
        ]

    def test_an_account_of_another_household_is_not_found(self):
        self.repo["accounts"].get_bank_account_with_owner.return_value = None

        with self.assertRaises(NotFoundError):
            get_card_bill(self.session, HOUSEHOLD_ID, ACCOUNT_ID, DEC)

    def test_a_bank_account_is_not_a_card(self):
        self.repo["accounts"].get_bank_account_with_owner.return_value = (
            _as_model(make_bank_account()),
            USER_ID,
        )

        with self.assertRaises(NotFoundError):
            get_card_bill(self.session, HOUSEHOLD_ID, ACCOUNT_ID, DEC)

    def test_asks_for_the_candidates_of_the_two_months_before_and_the_forecast_month(
        self,
    ):
        get_card_bill(
            self.session, HOUSEHOLD_ID, ACCOUNT_ID, datetime.date(2026, 12, 15)
        )

        self.repo[
            "transactions"
        ].list_card_transactions_for_bill.assert_called_once_with(
            self.session,
            HOUSEHOLD_ID,
            ACCOUNT_ID,
            utc(2026, 10, 1, 0),
            utc(2027, 1, 1, 0),
            "2026-12",
        )

    def test_only_the_transactions_of_that_bill_are_added(self):
        in_bill = make_transaction(date=utc(2026, 11, 20), amount=Decimal("30.00"))
        next_bill = make_transaction(date=utc(2026, 12, 5), amount=Decimal("500.00"))
        previous_bill = make_transaction(date=utc(2026, 11, 1), amount=Decimal("70.00"))
        self._stored(previous_bill, in_bill, next_bill)

        bill = get_card_bill(self.session, HOUSEHOLD_ID, ACCOUNT_ID, DEC)

        self.assertEqual(bill.month, DEC)
        self.assertEqual(bill.total, Decimal("30.00"))
        self.assertEqual([t.id for t in bill.transactions], [in_bill.id])
        self.assertTrue(bill.estimated)

    def test_a_dollar_purchase_counts_in_reais_and_one_without_conversion_is_warned(self):
        self._stored(
            make_transaction(
                date=utc(2026, 11, 20),
                currency_code="USD",
                amount=Decimal("20.00"),
                amount_in_account_currency=Decimal("120.00"),
            ),
            make_transaction(
                date=utc(2026, 11, 21), currency_code="USD", amount=Decimal("5.00")
            ),
            make_transaction(date=utc(2026, 11, 22), amount=Decimal("30.00")),
        )

        bill = get_card_bill(self.session, HOUSEHOLD_ID, ACCOUNT_ID, DEC)

        self.assertEqual(bill.total, Decimal("150.00"))
        self.assertEqual(bill.unconverted_count, 1)

    def test_a_bill_with_only_pluggy_forecasts_is_not_estimated(self):
        self._stored(
            make_transaction(
                date=utc(2026, 12, 25),
                amount=Decimal("30.00"),
                credit_card_metadata={"billForecastDate": "2026-12"},
            )
        )

        bill = get_card_bill(self.session, HOUSEHOLD_ID, ACCOUNT_ID, DEC)

        self.assertEqual(bill.total, Decimal("30.00"))
        self.assertFalse(bill.estimated)

    def test_a_card_without_credit_data_uses_the_month_of_the_date(self):
        self.repo["credit"].get_credit_data_by_bank_account_id.return_value = None
        self._stored(
            make_transaction(date=utc(2026, 12, 20), amount=Decimal("10.00")),
            make_transaction(date=utc(2026, 11, 20), amount=Decimal("99.00")),
        )

        bill = get_card_bill(self.session, HOUSEHOLD_ID, ACCOUNT_ID, DEC)

        self.assertEqual(bill.total, Decimal("10.00"))

    def test_an_empty_bill_is_zero_and_not_estimated(self):
        bill = get_card_bill(self.session, HOUSEHOLD_ID, ACCOUNT_ID, DEC)

        self.assertEqual(bill.total, Decimal("0.00"))
        self.assertFalse(bill.estimated)
        self.assertEqual(bill.transactions, [])


class _NextBillsTestCase(unittest.TestCase):
    def setUp(self):
        self.session = MagicMock()
        patchers = {
            "accounts": patch(f"{MODULE}.bank_account_repository"),
            "transactions": patch(f"{MODULE}.transactions_repository"),
        }
        self.repo = {name: p.start() for name, p in patchers.items()}
        for p in patchers.values():
            self.addCleanup(p.stop)
        self.card = _card(id=uuid.uuid4())
        # Closes on 3, due on 10
        self.credit = make_credit_data(
            bank_account_id=self.card.id,
            balance_close_date=utc(2026, 12, 3, 0),
            balance_due_date=utc(2026, 12, 10, 0),
        )

        def _candidates(session, household_id, account_id, *_):
            if account_id != self.card.id:
                return []
            return [
                _as_model(
                    make_transaction(
                        bank_account_id=account_id,
                        date=utc(2026, 11, 20),
                        amount=Decimal("30.00"),
                    )
                ),
                _as_model(
                    make_transaction(
                        bank_account_id=account_id,
                        date=utc(2026, 12, 20),
                        amount=Decimal("270.00"),
                    )
                ),
            ]

        self.repo[
            "transactions"
        ].list_card_transactions_for_bill.side_effect = _candidates


class GetNextBillsTests(_NextBillsTestCase):
    def test_each_card_gets_the_bill_of_the_month_with_its_own_credit_data(self):
        balances = [AccountBalance(self.card, USER_ID, self.credit)]

        bills = get_next_bills(self.session, HOUSEHOLD_ID, balances, DEC)

        self.assertEqual(list(bills), [self.card.id])
        self.assertEqual(bills[self.card.id].total, Decimal("30.00"))
        self.assertEqual(bills[self.card.id].month, DEC)

    def test_bank_accounts_are_skipped(self):
        bank = make_bank_account(id=uuid.uuid4())

        bills = get_next_bills(
            self.session, HOUSEHOLD_ID, [AccountBalance(bank, USER_ID)], DEC
        )

        self.assertEqual(bills, {})
        self.repo["transactions"].list_card_transactions_for_bill.assert_not_called()

    def test_no_accounts_no_bills(self):
        self.assertEqual(get_next_bills(self.session, HOUSEHOLD_ID, [], DEC), {})


class GetNextBillsTotalTests(_NextBillsTestCase):
    def test_sums_the_bills_of_the_cards_of_connected_items(self):
        other = _card(id=uuid.uuid4())
        self.repo["accounts"].list_account_balances.return_value = [
            (_as_model(self.card), USER_ID, _as_model(self.credit)),
            (_as_model(other), USER_ID, None),
        ]

        total = get_next_bills_total(self.session, HOUSEHOLD_ID, DEC, USER_ID)

        self.assertEqual(total, Decimal("30.00"))
        self.repo["accounts"].list_account_balances.assert_called_once_with(
            self.session, HOUSEHOLD_ID, "CREDIT", USER_ID
        )

    def test_without_cards_the_total_is_zero(self):
        self.repo["accounts"].list_account_balances.return_value = []

        total = get_next_bills_total(self.session, HOUSEHOLD_ID, DEC)

        self.assertEqual(total, Decimal("0.00"))


if __name__ == "__main__":
    unittest.main()
