import unittest
import uuid
from decimal import Decimal

from domain.internal_transfers import MAX_DAYS_APART, find_internal_pairs
from domain.transfer_documents import EXTERNAL, SAME_HOUSEHOLD, SAME_PERSON
from tests.factories import make_transaction, utc

CHECKING = uuid.UUID("00000000-0000-0000-0000-00000000a001")
SAVINGS = uuid.UUID("00000000-0000-0000-0000-00000000a002")
OTHER = uuid.UUID("00000000-0000-0000-0000-00000000a003")
PARTNER_ACCOUNT = uuid.UUID("00000000-0000-0000-0000-00000000a004")

ME = uuid.UUID("00000000-0000-0000-0000-00000000b001")
PARTNER = uuid.UUID("00000000-0000-0000-0000-00000000b002")
# Three accounts of mine and one of my partner's
OWNERS = {CHECKING: ME, SAVINGS: ME, OTHER: ME, PARTNER_ACCOUNT: PARTNER}


def pairs_of(transactions, verdicts=None):
    """The pairs without their kind: (debit, credit)."""
    found = find_internal_pairs(transactions, OWNERS, verdicts)
    return [(out, entry) for out, entry, _ in found]


def debit(amount="100.00", day=5, account=CHECKING, **overrides):
    values = {
        "type": "DEBIT",
        "amount": -Decimal(amount),
        "date": utc(2026, 11, day),
        "bank_account_id": account,
    }
    return make_transaction(**{**values, **overrides})


def credit(amount="100.00", day=5, account=SAVINGS, **overrides):
    values = {
        "type": "CREDIT",
        "amount": Decimal(amount),
        "date": utc(2026, 11, day),
        "bank_account_id": account,
    }
    return make_transaction(**{**values, **overrides})


class FindInternalPairsTests(unittest.TestCase):
    def test_a_debit_and_a_credit_of_the_same_amount_in_two_accounts_are_a_pair(self):
        out, entry = debit(), credit()

        self.assertEqual(pairs_of([out, entry]), [(out, entry)])

    def test_the_pair_is_always_debit_first_whatever_the_input_order(self):
        out, entry = debit(), credit()

        self.assertEqual(pairs_of([entry, out]), [(out, entry)])

    def test_the_direction_comes_from_the_type_not_from_the_sign(self):
        out = make_transaction(
            type="DEBIT", amount=Decimal("100.00"), bank_account_id=CHECKING
        )
        entry = make_transaction(
            type="CREDIT", amount=Decimal("-100.00"), bank_account_id=SAVINGS
        )

        self.assertEqual(pairs_of([out, entry]), [(out, entry)])

    def test_two_transactions_of_the_same_account_are_not_a_pair(self):
        self.assertEqual(
            pairs_of([debit(), credit(account=CHECKING)]), []
        )

    def test_two_debits_are_not_a_pair(self):
        self.assertEqual(
            pairs_of([debit(), debit(account=SAVINGS)]), []
        )

    def test_different_amounts_are_not_a_pair(self):
        self.assertEqual(
            pairs_of([debit("100.00"), credit("100.01")]), []
        )

    def test_different_currencies_are_not_a_pair(self):
        self.assertEqual(
            pairs_of([debit(), credit(currency_code="USD")]), []
        )

    def test_up_to_the_tolerance_in_days_is_a_pair(self):
        out, entry = debit(day=5), credit(day=5 + MAX_DAYS_APART)

        self.assertEqual(pairs_of([out, entry]), [(out, entry)])

    def test_beyond_the_tolerance_in_days_is_not_a_pair(self):
        out, entry = debit(day=5), credit(day=5 + MAX_DAYS_APART + 1)

        self.assertEqual(pairs_of([out, entry]), [])

    def test_the_days_are_the_local_ones_not_the_utc_ones(self):
        # Local day 5 (10:00) and local day 7 (22:30): 2 days apart, tolerated.
        # In UTC the credit is already day 8 (01:30): 3 days apart, which would not be.
        out = debit(day=5)
        entry = credit(date=utc(2026, 11, 8, 1))

        self.assertEqual(pairs_of([out, entry]), [(out, entry)])

    def test_the_closest_date_wins_and_the_farther_one_stays_alone(self):
        out = debit(day=5)
        near, far = credit(day=5), credit(day=7)

        self.assertEqual(pairs_of([out, near, far]), [(out, near)])

    def test_a_tie_between_two_partners_is_not_guessed(self):
        out = debit(day=5)
        first, second = credit(day=5), credit(day=5, account=OTHER)

        self.assertEqual(pairs_of([out, first, second]), [])

    def test_a_transaction_is_never_in_two_pairs(self):
        out_a, out_b = debit(day=5), debit(day=5, account=OTHER)
        entry = credit(day=5)

        pairs = pairs_of([out_a, out_b, entry])

        legs = [t for pair in pairs for t in pair]
        self.assertEqual(len(legs), len(set(t.id for t in legs)))
        self.assertEqual(pairs, [])  # Ambiguous: two debits for one credit

    def test_independent_transfers_of_different_amounts_are_all_paired(self):
        small_out, small_in = debit("50.00"), credit("50.00")
        big_out, big_in = debit("900.00", day=8), credit("900.00", day=8)

        pairs = pairs_of([small_out, big_out, small_in, big_in])

        self.assertCountEqual(pairs, [(small_out, small_in), (big_out, big_in)])

    def test_transactions_without_id_are_ignored(self):
        out, entry = debit(id=None), credit()

        self.assertEqual(pairs_of([out, entry]), [])

    def test_no_transactions_or_just_one_is_no_pair(self):
        self.assertEqual(pairs_of([]), [])
        self.assertEqual(pairs_of([debit()]), [])


class PairKindTests(unittest.TestCase):
    def test_two_accounts_of_the_same_person_are_a_same_person_pair(self):
        out, entry = debit(), credit()

        self.assertEqual(
            find_internal_pairs([out, entry], OWNERS), [(out, entry, SAME_PERSON)]
        )

    def test_accounts_of_two_people_of_the_household_are_a_same_household_pair(self):
        out, entry = debit(), credit(account=PARTNER_ACCOUNT)

        self.assertEqual(
            find_internal_pairs([out, entry], OWNERS), [(out, entry, SAME_HOUSEHOLD)]
        )

    def test_an_account_with_no_known_owner_is_not_paired(self):
        out, entry = debit(), credit()

        self.assertEqual(find_internal_pairs([out, entry], {CHECKING: ME}), [])


class DocumentVerdictsTests(unittest.TestCase):
    def test_an_external_transaction_is_never_paired(self):
        out, entry = debit(), credit()

        self.assertEqual(pairs_of([out, entry], {out.id: EXTERNAL}), [])
        self.assertEqual(pairs_of([out, entry], {entry.id: EXTERNAL}), [])

    def test_a_verdict_that_agrees_with_the_owners_keeps_the_pair(self):
        out, entry = debit(), credit()

        self.assertEqual(
            find_internal_pairs([out, entry], OWNERS, {out.id: SAME_PERSON}),
            [(out, entry, SAME_PERSON)],
        )

    def test_a_verdict_that_disagrees_with_the_owners_prevents_the_pair(self):
        out, entry = debit(), credit()  # Both accounts are mine

        self.assertEqual(pairs_of([out, entry], {out.id: SAME_HOUSEHOLD}), [])
        self.assertEqual(pairs_of([out, entry], {entry.id: SAME_HOUSEHOLD}), [])

    def test_the_documents_break_a_tie_between_my_other_account_and_my_partners(self):
        out = debit()
        mine, partners = credit(account=SAVINGS), credit(account=PARTNER_ACCOUNT)

        self.assertEqual(pairs_of([out, mine, partners]), [])  # Ambiguous alone
        self.assertEqual(
            find_internal_pairs([out, mine, partners], OWNERS, {out.id: SAME_PERSON}),
            [(out, mine, SAME_PERSON)],
        )
        self.assertEqual(
            find_internal_pairs([out, mine, partners], OWNERS, {out.id: SAME_HOUSEHOLD}),
            [(out, partners, SAME_HOUSEHOLD)],
        )

    def test_a_verdict_of_a_competing_credit_does_not_break_the_tie_for_the_debit(self):
        out = debit()
        mine, partners = credit(account=SAVINGS), credit(account=PARTNER_ACCOUNT)

        # The verdict only limits the pairs of the credit that has it: the debit still has two
        self.assertEqual(
            find_internal_pairs([out, mine, partners], OWNERS, {partners.id: SAME_HOUSEHOLD}),
            [],
        )

    def test_an_external_candidate_stops_being_a_tie(self):
        out = debit()
        mine, stranger_paid = credit(account=SAVINGS), credit(account=PARTNER_ACCOUNT)

        self.assertEqual(
            find_internal_pairs([out, mine, stranger_paid], OWNERS, {stranger_paid.id: EXTERNAL}),
            [(out, mine, SAME_PERSON)],
        )

    def test_transactions_without_a_verdict_are_not_limited(self):
        out, entry = debit(), credit(account=PARTNER_ACCOUNT)

        self.assertEqual(
            find_internal_pairs([out, entry], OWNERS, {out.id: None}),
            [(out, entry, SAME_HOUSEHOLD)],
        )
