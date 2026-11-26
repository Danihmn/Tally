import datetime
import unittest
import uuid
from decimal import Decimal

from domain.read_models import TransactionWithOwner
from domain.recurrence_detection import (
    DetectionSettings,
    detect_recurrences,
    matches_recurrence,
    normalize_description,
)
from tests.factories import (
    ACCOUNT_ID,
    HOUSEHOLD_ID,
    USER_ID,
    make_recurrence,
    make_transaction,
    utc,
)

TODAY = datetime.date(2026, 11, 10)
PARTNER_ID = uuid.UUID("00000000-0000-0000-0000-00000000b002")
CARD_ID = uuid.UUID("00000000-0000-0000-0000-00000000a002")
PARTNER_ACCOUNT_ID = uuid.UUID("00000000-0000-0000-0000-00000000a003")


def item(user_id=USER_ID, **overrides):
    return TransactionWithOwner(
        transaction=make_transaction(**overrides), user_id=user_id
    )


def monthly(
    description="NETFLIX.COM",
    amounts=("39.90", "39.90", "39.90"),
    months=((2026, 8), (2026, 9), (2026, 10)),
    day=5,
    type="DEBIT",
    **overrides,
):
    """One transaction per month, on the same day, with the given amounts."""
    return [
        item(
            description=description,
            date=utc(year, month, day),
            amount=Decimal(amount) * (-1 if type == "DEBIT" else 1),
            type=type,
            **overrides,
        )
        for (year, month), amount in zip(months, amounts)
    ]


class NormalizeDescriptionTests(unittest.TestCase):
    def test_case_accents_digits_and_punctuation_are_removed(self):
        self.assertEqual(
            normalize_description("Pagamento ÁGUA-123 S.A."), "pagamento agua s a"
        )

    def test_dates_do_not_change_the_description(self):
        self.assertEqual(
            normalize_description("NETFLIX.COM 05/11"),
            normalize_description("Netflix.com 12/12/2026"),
        )
        self.assertEqual(normalize_description("Spotify 2026-11-05"), "spotify")

    def test_installment_markers_are_removed(self):
        self.assertEqual(normalize_description("LOJA X PARC 03/10"), "loja x")
        self.assertEqual(normalize_description("Loja X parcela 3 de 10"), "loja x")

    def test_spaces_are_collapsed_and_empty_values_give_an_empty_text(self):
        self.assertEqual(normalize_description("  Aluguel   casa  "), "aluguel casa")
        self.assertEqual(normalize_description(None), "")
        self.assertEqual(normalize_description("12/10 123"), "")


class MonthlyPatternTests(unittest.TestCase):
    def test_three_months_of_the_same_charge_give_one_candidate(self):
        candidates = detect_recurrences(monthly(), TODAY)

        self.assertEqual(len(candidates), 1)
        candidate = candidates[0]
        self.assertEqual(candidate.type, "EXPENSES")
        self.assertEqual(candidate.amount, Decimal("39.90"))
        self.assertEqual(candidate.due_day, 5)
        self.assertEqual(candidate.months, 3)
        self.assertEqual(candidate.user_id, USER_ID)
        self.assertEqual(candidate.household_id, HOUSEHOLD_ID)
        self.assertEqual(candidate.normalized_description, "netflix com")

    def test_evidence_has_the_dates_and_amounts_in_order(self):
        candidate = detect_recurrences(
            monthly(amounts=("39.90", "41.00", "40.00")), TODAY
        )[0]

        self.assertEqual(
            [(e.date, e.amount) for e in candidate.evidence],
            [
                (datetime.date(2026, 8, 5), Decimal("39.90")),
                (datetime.date(2026, 9, 5), Decimal("41.00")),
                (datetime.date(2026, 10, 5), Decimal("40.00")),
            ],
        )

    def test_descriptions_with_different_dates_are_the_same_pattern(self):
        items = [
            item(description="NETFLIX.COM 05/08", date=utc(2026, 8, 5)),
            item(description="Netflix.com 05/09", date=utc(2026, 9, 5)),
            item(description="NETFLIX.COM 05/10", date=utc(2026, 10, 5)),
        ]

        candidates = detect_recurrences(items, TODAY)

        self.assertEqual(len(candidates), 1)
        self.assertEqual(candidates[0].description, "NETFLIX.COM 05/10")

    def test_a_credit_is_a_revenue(self):
        items = monthly(
            description="SALARIO EMPRESA", amounts=("5000",) * 3, type="CREDIT"
        )

        candidate = detect_recurrences(items, TODAY)[0]

        self.assertEqual(candidate.type, "REVENUES")
        self.assertEqual(candidate.amount, Decimal("5000.00"))

    def test_a_charge_that_moves_a_few_days_is_still_monthly(self):
        items = [
            item(description="Aluguel", date=utc(2026, 7, 5)),
            item(description="Aluguel", date=utc(2026, 8, 8)),
            item(description="Aluguel", date=utc(2026, 9, 4)),
            item(description="Aluguel", date=utc(2026, 10, 6)),
        ]

        candidate = detect_recurrences(items, TODAY)[0]

        self.assertEqual(candidate.months, 4)
        self.assertEqual(candidate.due_day, 5)

    def test_candidates_come_with_the_best_confidence_first(self):
        weak = monthly(description="Academia", amounts=("100", "108", "100"))
        strong = monthly(
            description="Spotify",
            amounts=("21.90",) * 6,
            months=((2026, 5), (2026, 6), (2026, 7), (2026, 8), (2026, 9), (2026, 10)),
        )

        candidates = detect_recurrences(weak + strong, TODAY)

        self.assertEqual(
            [c.normalized_description for c in candidates], ["spotify", "academia"]
        )


class NotEnoughMonthsTests(unittest.TestCase):
    def test_two_months_are_not_a_pattern(self):
        items = monthly(amounts=("39.90",) * 2, months=((2026, 9), (2026, 10)))

        self.assertEqual(detect_recurrences(items, TODAY), [])

    def test_the_minimum_of_months_can_be_changed(self):
        items = monthly(amounts=("39.90",) * 2, months=((2026, 9), (2026, 10)))

        candidates = detect_recurrences(
            items, TODAY, settings=DetectionSettings(min_months=2)
        )

        self.assertEqual(len(candidates), 1)

    def test_many_charges_in_the_same_weeks_are_not_monthly(self):
        items = [
            item(description="Uber", date=utc(2026, 10, d), amount=Decimal("-20.00"))
            for d in (1, 3, 8, 15, 22)
        ]

        self.assertEqual(detect_recurrences(items, TODAY), [])


class IrregularGapsTests(unittest.TestCase):
    def test_gaps_far_from_one_month_are_not_a_pattern(self):
        items = [
            item(description="Farmacia", date=utc(2026, 5, 3)),
            item(description="Farmacia", date=utc(2026, 7, 20)),
            item(description="Farmacia", date=utc(2026, 8, 2)),
            item(description="Farmacia", date=utc(2026, 10, 15)),
        ]

        self.assertEqual(detect_recurrences(items, TODAY), [])

    def test_a_missed_month_breaks_the_chain(self):
        items = monthly(
            months=((2026, 6), (2026, 7), (2026, 9), (2026, 10)), amounts=("39.90",) * 4
        )

        self.assertEqual(detect_recurrences(items, TODAY), [])

    def test_the_longest_monthly_run_is_kept(self):
        items = monthly(
            months=((2026, 3), (2026, 7), (2026, 8), (2026, 9), (2026, 10)),
            amounts=("39.90",) * 5,
        )

        candidate = detect_recurrences(items, TODAY)[0]

        self.assertEqual(candidate.evidence[0].date, datetime.date(2026, 7, 5))
        self.assertEqual(candidate.months, 4)

    def test_the_gap_tolerance_can_be_changed(self):
        items = [
            item(description="Aluguel", date=utc(2026, 8, 1)),
            item(description="Aluguel", date=utc(2026, 9, 5)),
            item(description="Aluguel", date=utc(2026, 10, 1)),
        ]
        strict = DetectionSettings(interval_tolerance_days=2)

        self.assertEqual(len(detect_recurrences(items, TODAY)), 1)
        self.assertEqual(detect_recurrences(items, TODAY, settings=strict), [])


class AmountDriftTests(unittest.TestCase):
    def test_small_changes_inside_the_tolerance_are_the_same_pattern(self):
        items = monthly(description="Energia", amounts=("180.00", "195.00", "188.00"))

        candidate = detect_recurrences(items, TODAY)[0]

        self.assertEqual(candidate.amount, Decimal("188.00"))

    def test_a_jump_bigger_than_the_tolerance_splits_the_pattern(self):
        items = monthly(
            description="Streaming",
            amounts=("39.90", "39.90", "55.90", "55.90"),
            months=((2026, 7), (2026, 8), (2026, 9), (2026, 10)),
        )

        self.assertEqual(detect_recurrences(items, TODAY), [])

    def test_two_prices_with_the_same_name_are_two_candidates(self):
        months = ((2026, 8), (2026, 9), (2026, 10))
        small = monthly(
            description="Seguro", amounts=("50",) * 3, months=months, day=10
        )
        big = monthly(description="Seguro", amounts=("300",) * 3, months=months, day=20)

        candidates = detect_recurrences(small + big, TODAY)

        self.assertEqual(
            sorted(c.amount for c in candidates), [Decimal("50.00"), Decimal("300.00")]
        )

    def test_the_amount_tolerance_can_be_changed(self):
        items = monthly(description="Energia", amounts=("180.00", "195.00", "188.00"))
        strict = DetectionSettings(amount_tolerance=Decimal("0.02"))

        self.assertEqual(detect_recurrences(items, TODAY, settings=strict), [])

    def test_the_amount_is_the_median_in_cents(self):
        items = monthly(
            description="Agua",
            amounts=("100.00", "101.01", "100.50", "100.20"),
            months=((2026, 7), (2026, 8), (2026, 9), (2026, 10)),
        )

        candidate = detect_recurrences(items, TODAY)[0]

        self.assertEqual(candidate.amount, Decimal("100.35"))


class StalePatternTests(unittest.TestCase):
    def test_a_pattern_that_stopped_is_not_suggested(self):
        items = monthly(months=((2026, 3), (2026, 4), (2026, 5)))

        self.assertEqual(detect_recurrences(items, TODAY), [])


class ExistingRecurrenceTests(unittest.TestCase):
    def test_a_pattern_that_is_already_an_active_recurrence_is_left_out(self):
        existing = make_recurrence(description="Netflix", amount=Decimal("39.90"))

        self.assertEqual(detect_recurrences(monthly(), TODAY, existing=[existing]), [])

    def test_a_cancelled_recurrence_does_not_hide_the_pattern(self):
        existing = make_recurrence(
            description="Netflix", amount=Decimal("39.90"), status="CANCELLED"
        )

        self.assertEqual(
            len(detect_recurrences(monthly(), TODAY, existing=[existing])), 1
        )

    def test_a_recurrence_with_another_amount_or_type_does_not_hide_the_pattern(self):
        other_amount = make_recurrence(description="Netflix", amount=Decimal("80.00"))
        other_type = make_recurrence(
            description="Netflix", amount=Decimal("39.90"), type="REVENUES"
        )

        candidates = detect_recurrences(
            monthly(), TODAY, existing=[other_amount, other_type]
        )

        self.assertEqual(len(candidates), 1)

    def test_the_partners_recurrence_also_covers_the_pattern(self):
        existing = make_recurrence(
            description="NETFLIX COM", amount=Decimal("39.90"), user_id=PARTNER_ID
        )

        self.assertEqual(detect_recurrences(monthly(), TODAY, existing=[existing]), [])

    def test_matches_recurrence_compares_type_description_and_amount(self):
        candidate = detect_recurrences(monthly(), TODAY)[0]
        tolerance = Decimal("0.10")

        self.assertTrue(
            matches_recurrence(
                candidate,
                make_recurrence(description="netflix", amount=Decimal(42)),
                tolerance,
            )
        )
        self.assertFalse(
            matches_recurrence(
                candidate,
                make_recurrence(description="Spotify", amount=Decimal("39.90")),
                tolerance,
            )
        )
        self.assertFalse(
            matches_recurrence(
                candidate,
                make_recurrence(description="123", amount=Decimal("39.90")),
                tolerance,
            )
        )


class InternalTransferTests(unittest.TestCase):
    def test_classified_internal_transfers_are_left_out(self):
        for kind in ("SAME_PERSON", "SAME_HOUSEHOLD"):
            with self.subTest(kind=kind):
                items = monthly(description="Pix Bia", internal_transfer=kind)

                self.assertEqual(detect_recurrences(items, TODAY), [])

    def test_a_transfer_classified_as_not_internal_is_kept(self):
        items = monthly(
            description="Pix Joao", internal_transfer="NOT_INTERNAL_TRANSFER"
        )

        self.assertEqual(len(detect_recurrences(items, TODAY)), 1)

    def test_unclassified_transfers_between_the_couple_are_left_out(self):
        months = ((2026, 8), (2026, 9), (2026, 10))
        debits = monthly(
            description="Pix enviado Bia", amounts=("500",) * 3, months=months
        )
        credits = monthly(
            description="Pix recebido Dudu",
            amounts=("500",) * 3,
            months=months,
            type="CREDIT",
            bank_account_id=PARTNER_ACCOUNT_ID,
            user_id=PARTNER_ID,
        )
        owners = {ACCOUNT_ID: USER_ID, PARTNER_ACCOUNT_ID: PARTNER_ID}

        self.assertEqual(
            detect_recurrences(debits + credits, TODAY, owner_by_account=owners), []
        )


class LeftOutTransactionsTests(unittest.TestCase):
    def test_card_bill_payments_are_left_out(self):
        items = monthly(
            description="Pagamento fatura", operation_type="PAGAMENTO_FATURA"
        )

        self.assertEqual(detect_recurrences(items, TODAY), [])

    def test_installments_of_a_purchase_are_left_out(self):
        by_metadata = monthly(
            description="Loja X",
            credit_card_metadata={"installmentNumber": 2, "totalInstallments": 10},
        )
        by_description = [
            item(description=f"Loja Y PARC {n}/10", date=utc(2026, m, 5))
            for n, m in ((1, 8), (2, 9), (3, 10))
        ]

        self.assertEqual(detect_recurrences(by_metadata + by_description, TODAY), [])

    def test_pending_and_foreign_transactions_without_a_converted_value_are_left_out(
        self,
    ):
        pending = monthly(description="Spotify", status="PENDING")
        foreign = monthly(description="Github", currency_code="USD")

        self.assertEqual(detect_recurrences(pending + foreign, TODAY), [])

    def test_a_foreign_purchase_uses_the_converted_value(self):
        items = monthly(
            description="Github",
            currency_code="USD",
            amount_in_account_currency=Decimal("-55.00"),
        )

        self.assertEqual(detect_recurrences(items, TODAY)[0].amount, Decimal("55.00"))

    def test_transactions_without_a_description_are_left_out(self):
        self.assertEqual(detect_recurrences(monthly(description=None), TODAY), [])


class InferredFieldsTests(unittest.TestCase):
    def test_the_most_common_category_is_used(self):
        items = monthly(description="Mercado Bom")
        items[0].transaction.category = "Groceries"
        items[1].transaction.category = "Groceries"
        items[2].transaction.category = "Shopping"

        self.assertEqual(detect_recurrences(items, TODAY)[0].category, "Groceries")

    def test_no_category_stays_empty(self):
        self.assertIsNone(detect_recurrences(monthly(), TODAY)[0].category)

    def test_payment_type_is_credit_when_most_charges_are_on_a_card(self):
        on_card = monthly(bank_account_id=CARD_ID)

        self.assertEqual(
            detect_recurrences(on_card, TODAY, credit_card_accounts={CARD_ID})[
                0
            ].payment_type,
            "CREDIT",
        )
        self.assertEqual(
            detect_recurrences(monthly(), TODAY, credit_card_accounts={CARD_ID})[
                0
            ].payment_type,
            "DEBIT",
        )

    def test_the_due_day_is_the_local_day(self):
        # 01:00 UTC is still the day before in São Paulo
        items = [
            item(description="Aluguel", date=utc(2026, m, 11, hour=1))
            for m in (8, 9, 10)
        ]

        self.assertEqual(detect_recurrences(items, TODAY)[0].due_day, 10)

    def test_each_person_has_their_own_candidates(self):
        mine = monthly(description="Academia")
        partners = monthly(description="Academia", user_id=PARTNER_ID)

        candidates = detect_recurrences(mine + partners, TODAY)

        self.assertEqual({c.user_id for c in candidates}, {USER_ID, PARTNER_ID})


class ConfidenceTests(unittest.TestCase):
    def test_a_perfect_pattern_of_six_months_scores_one(self):
        items = monthly(
            amounts=("39.90",) * 6,
            months=((2026, 5), (2026, 6), (2026, 7), (2026, 8), (2026, 9), (2026, 10)),
            day=1,
        )
        # Every gap is 30 or 31 days: the timing error is small but not zero
        candidate = detect_recurrences(items, TODAY.replace(day=1))[0]

        self.assertGreaterEqual(candidate.confidence, Decimal("0.95"))
        self.assertLessEqual(candidate.confidence, Decimal("1.00"))

    def test_fewer_months_and_more_drift_give_a_lower_score(self):
        steady = detect_recurrences(
            monthly(description="A", amounts=("100",) * 3), TODAY
        )[0]
        drifting = detect_recurrences(
            monthly(description="B", amounts=("100", "109", "100")), TODAY
        )[0]

        self.assertLess(drifting.confidence, steady.confidence)
        self.assertLess(steady.confidence, Decimal("1.00"))


class CandidateIdTests(unittest.TestCase):
    def test_the_id_does_not_change_when_a_new_month_arrives(self):
        first = monthly()
        later = first + monthly(amounts=("39.90",), months=((2026, 11),))

        before = detect_recurrences(first, TODAY)[0]
        after = detect_recurrences(later, TODAY)[0]

        self.assertEqual(before.candidate_id, after.candidate_id)
        self.assertEqual(after.months, 4)

    def test_different_patterns_have_different_ids(self):
        candidates = detect_recurrences(
            monthly(description="A") + monthly(description="B"), TODAY
        )

        self.assertNotEqual(candidates[0].candidate_id, candidates[1].candidate_id)


class ToRecurrenceTests(unittest.TestCase):
    def test_the_recurrence_copies_the_candidate_and_comes_from_the_ai(self):
        items = monthly(category="Streaming")
        candidate = detect_recurrences(items, TODAY, credit_card_accounts=set())[0]

        recurrence = candidate.to_recurrence()

        self.assertEqual(recurrence.description, "NETFLIX.COM")
        self.assertEqual(recurrence.amount, Decimal("39.90"))
        self.assertEqual(recurrence.type, "EXPENSES")
        self.assertEqual(recurrence.due_day, 5)
        self.assertEqual(recurrence.category, "Streaming")
        self.assertEqual(recurrence.payment_type, "DEBIT")
        self.assertEqual(recurrence.user_id, USER_ID)
        self.assertEqual(recurrence.household_id, HOUSEHOLD_ID)
        self.assertEqual(recurrence.source, "AI")
        self.assertEqual(recurrence.status, "ACTIVE")
        self.assertIsNone(recurrence.id)
        self.assertIn(
            "3 transactions between 2026-08-05 and 2026-10-05", recurrence.notes
        )

    def test_a_long_description_is_cut_to_the_column_limit(self):
        items = monthly(description="A" * 250)

        self.assertEqual(
            len(detect_recurrences(items, TODAY)[0].to_recurrence().description), 200
        )
