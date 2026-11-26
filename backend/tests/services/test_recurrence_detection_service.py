import datetime
import unittest
import uuid
from decimal import Decimal
from unittest.mock import MagicMock, patch

from domain.read_models import BankAccountWithOwner, TransactionWithOwner
from services.common.exceptions import NotFoundError
from services.recurrence_detection_service import (
    PAGE_SIZE,
    create_recurrence_from_candidate,
    find_recurrence_candidates,
)
from tests.factories import (
    ACCOUNT_ID,
    HOUSEHOLD_ID,
    USER_ID,
    make_bank_account,
    make_recurrence,
    make_transaction,
    utc,
)

MODULE = "services.recurrence_detection_service"
TODAY = datetime.date(2026, 11, 10)
PARTNER_ID = uuid.UUID("00000000-0000-0000-0000-00000000b002")
CARD_ID = uuid.UUID("00000000-0000-0000-0000-00000000a002")


def monthly(description, user_id=USER_ID, bank_account_id=ACCOUNT_ID):
    return [
        TransactionWithOwner(
            transaction=make_transaction(
                description=description,
                date=utc(2026, month, 5),
                amount=Decimal("-39.90"),
                bank_account_id=bank_account_id,
            ),
            user_id=user_id,
        )
        for month in (8, 9, 10)
    ]


class DetectionServiceTestCase(unittest.TestCase):
    """Patches the services this module reads (no database)."""

    def setUp(self):
        self.session = MagicMock()
        self.search_transactions = self._patch("search_transactions")
        self.search_transactions.return_value = ([], 0)
        self.search_accounts = self._patch("search_bank_accounts")
        self.search_accounts.return_value = [
            BankAccountWithOwner(account=make_bank_account(), user_id=USER_ID),
            BankAccountWithOwner(
                account=make_bank_account(id=CARD_ID, type="CREDIT"), user_id=USER_ID
            ),
        ]
        self.search_recurrences = self._patch("search_recurrences")
        self.search_recurrences.return_value = ([], 0)

    def _patch(self, name):
        patcher = patch(f"{MODULE}.{name}")
        mock = patcher.start()
        self.addCleanup(patcher.stop)
        return mock

    def with_transactions(self, items):
        self.search_transactions.return_value = (items, len(items))


class FindRecurrenceCandidatesTests(DetectionServiceTestCase):
    def test_reads_the_posted_transactions_of_the_last_year_without_internal_transfers(
        self,
    ):
        find_recurrence_candidates(self.session, HOUSEHOLD_ID, TODAY)

        filters = self.search_transactions.call_args.args[1]
        self.assertEqual(filters.household_id, HOUSEHOLD_ID)
        self.assertIsNone(filters.user_id)
        self.assertEqual(filters.status, "POSTED")
        self.assertTrue(filters.exclude_internal_transfers)
        self.assertEqual(
            filters.date_from, datetime.datetime(2025, 11, 10, tzinfo=datetime.UTC)
        )
        self.assertEqual(
            filters.date_to, datetime.datetime(2026, 11, 11, tzinfo=datetime.UTC)
        )

    def test_compares_with_the_active_recurrences_of_the_household(self):
        self.with_transactions(monthly("NETFLIX.COM"))
        self.search_recurrences.return_value = (
            [make_recurrence(description="Netflix", amount=Decimal("39.90"))],
            1,
        )

        candidates = find_recurrence_candidates(self.session, HOUSEHOLD_ID, TODAY)

        self.assertEqual(candidates, [])
        filters = self.search_recurrences.call_args.args[1]
        self.assertEqual(filters.household_id, HOUSEHOLD_ID)
        self.assertEqual(filters.status, "ACTIVE")

    def test_reads_every_page_of_transactions(self):
        items = monthly("NETFLIX.COM")
        self.search_transactions.side_effect = [
            (items[:2], 3),
            (items[2:], 3),
        ]

        candidates = find_recurrence_candidates(self.session, HOUSEHOLD_ID, TODAY)

        self.assertEqual(len(candidates), 1)
        offsets = [c.kwargs["offset"] for c in self.search_transactions.call_args_list]
        self.assertEqual(offsets, [0, 2])
        self.assertEqual(self.search_transactions.call_args.kwargs["limit"], PAGE_SIZE)

    def test_a_card_account_gives_the_credit_payment_type(self):
        self.with_transactions(monthly("Spotify", bank_account_id=CARD_ID))

        candidate = find_recurrence_candidates(self.session, HOUSEHOLD_ID, TODAY)[0]

        self.assertEqual(candidate.payment_type, "CREDIT")
        self.assertEqual(
            self.search_accounts.call_args.kwargs["household_id"], HOUSEHOLD_ID
        )

    def test_the_user_filter_keeps_only_that_persons_candidates(self):
        self.with_transactions(
            monthly("Academia") + monthly("Curso", user_id=PARTNER_ID)
        )

        mine = find_recurrence_candidates(
            self.session, HOUSEHOLD_ID, TODAY, user_id=USER_ID
        )
        everyone = find_recurrence_candidates(self.session, HOUSEHOLD_ID, TODAY)

        self.assertEqual([c.normalized_description for c in mine], ["academia"])
        self.assertEqual(len(everyone), 2)


class CreateRecurrenceFromCandidateTests(DetectionServiceTestCase):
    def test_creates_the_recurrence_of_the_candidate_with_that_id(self):
        self.with_transactions(monthly("NETFLIX.COM"))
        candidate = find_recurrence_candidates(self.session, HOUSEHOLD_ID, TODAY)[0]

        with patch(f"{MODULE}.create_recurrence") as create:
            result = create_recurrence_from_candidate(
                self.session, HOUSEHOLD_ID, candidate.candidate_id, TODAY
            )

        recurrence = create.call_args.args[1]
        self.assertIs(create.call_args.args[0], self.session)
        self.assertEqual(recurrence.description, "NETFLIX.COM")
        self.assertEqual(recurrence.amount, Decimal("39.90"))
        self.assertEqual(recurrence.source, "AI")
        self.assertIs(result, create.return_value)

    def test_an_unknown_id_raises_not_found_and_creates_nothing(self):
        self.with_transactions(monthly("NETFLIX.COM"))

        with (
            patch(f"{MODULE}.create_recurrence") as create,
            self.assertRaises(NotFoundError),
        ):
            create_recurrence_from_candidate(
                self.session, HOUSEHOLD_ID, "deadbeef", TODAY
            )

        create.assert_not_called()
