import datetime
import unittest
from decimal import Decimal

from domain.credit_card_bills import (
    bill_month_of,
    bill_total,
    forecast_month,
    installment_of,
    is_bill_payment,
)
from tests.factories import make_transaction, utc

DEC = datetime.date(2026, 12, 1)
JAN = datetime.date(2027, 1, 1)


class ForecastMonthTests(unittest.TestCase):
    def test_the_pluggy_forecast_becomes_day_1_of_that_month(self):
        t = make_transaction(credit_card_metadata={"billForecastDate": "2026-12"})

        self.assertEqual(forecast_month(t), DEC)

    def test_no_metadata_or_a_bad_value_gives_none(self):
        for metadata in (
            None,
            {},
            {"billForecastDate": "2026-13"},
            {"billForecastDate": 5},
        ):
            with self.subTest(metadata=metadata):
                t = make_transaction(credit_card_metadata=metadata)
                self.assertIsNone(forecast_month(t))


class InstallmentOfTests(unittest.TestCase):
    def test_reads_the_installment_number_and_total(self):
        t = make_transaction(
            credit_card_metadata={"installmentNumber": 3, "totalInstallments": 10}
        )

        self.assertEqual(installment_of(t), (3, 10))

    def test_a_single_payment_purchase_has_no_installments(self):
        self.assertEqual(installment_of(make_transaction()), (None, None))


class BillMonthOfTests(unittest.TestCase):
    def test_the_pluggy_forecast_wins_over_the_closing_day(self):
        t = make_transaction(
            date=utc(2026, 11, 28), credit_card_metadata={"billForecastDate": "2026-12"}
        )

        self.assertEqual(bill_month_of(t, close_day=3, due_day=10), (DEC, False))

    def test_a_purchase_before_the_closing_day_is_due_in_the_same_month(self):
        # Closes on 3/12, due on 10/12
        t = make_transaction(date=utc(2026, 12, 2))

        self.assertEqual(bill_month_of(t, close_day=3, due_day=10), (DEC, True))

    def test_a_purchase_on_the_closing_day_goes_to_the_next_bill(self):
        t = make_transaction(date=utc(2026, 12, 3))

        self.assertEqual(bill_month_of(t, close_day=3, due_day=10), (JAN, True))

    def test_a_card_due_after_the_turn_of_the_month_is_due_the_month_after_closing(
        self,
    ):
        # Closes on 28/11, due on 5/12
        t = make_transaction(date=utc(2026, 11, 20))

        self.assertEqual(bill_month_of(t, close_day=28, due_day=5), (DEC, True))

    def test_december_purchases_after_closing_go_to_january(self):
        t = make_transaction(date=utc(2026, 12, 29))

        self.assertEqual(
            bill_month_of(t, close_day=28, due_day=5)[0], datetime.date(2027, 2, 1)
        )

    def test_a_closing_day_past_the_end_of_the_month_is_the_last_day(self):
        # Closes on day 31; in November that is the 30th
        t = make_transaction(date=utc(2026, 11, 30))

        self.assertEqual(bill_month_of(t, close_day=31, due_day=8)[0], JAN)

    def test_without_credit_data_the_month_of_the_date_is_used(self):
        t = make_transaction(date=utc(2026, 12, 20))

        self.assertEqual(bill_month_of(t, close_day=None, due_day=None), (DEC, True))

    def test_the_utc_day_is_used_since_pluggy_dates_are_days_at_utc_midnight(self):
        t = make_transaction(date=datetime.datetime(2026, 12, 3, tzinfo=datetime.UTC))

        self.assertEqual(bill_month_of(t, close_day=3, due_day=10)[0], JAN)


class IsBillPaymentTests(unittest.TestCase):
    def test_a_bill_payment_is_recognized_by_its_operation_type(self):
        self.assertTrue(
            is_bill_payment(make_transaction(operation_type="PAGAMENTO_FATURA"))
        )
        self.assertFalse(is_bill_payment(make_transaction(operation_type="PAGAMENTO")))


class BillTotalTests(unittest.TestCase):
    def test_an_installment_purchase_adds_only_the_installment_amount(self):
        installment = make_transaction(
            amount=Decimal("30.00"),
            type="DEBIT",
            credit_card_metadata={"installmentNumber": 1, "totalInstallments": 10},
        )

        self.assertEqual(bill_total([installment]), Decimal("30.00"))

    def test_purchases_add_and_refunds_subtract_whatever_the_sign(self):
        transactions = [
            make_transaction(amount=Decimal("100.00"), type="DEBIT"),
            make_transaction(amount=Decimal("-50.00"), type="DEBIT"),
            make_transaction(amount=Decimal("-20.00"), type="CREDIT"),
        ]

        self.assertEqual(bill_total(transactions), Decimal("130.00"))

    def test_the_payment_of_a_previous_bill_is_left_out(self):
        transactions = [
            make_transaction(amount=Decimal("100.00"), type="DEBIT"),
            make_transaction(
                amount=Decimal("-900.00"),
                type="CREDIT",
                operation_type="PAGAMENTO_FATURA",
            ),
        ]

        self.assertEqual(bill_total(transactions), Decimal("100.00"))

    def test_an_empty_bill_is_zero(self):
        self.assertEqual(bill_total([]), Decimal("0.00"))


if __name__ == "__main__":
    unittest.main()
