import unittest
import uuid
from unittest.mock import MagicMock, patch

from jobs.transaction_internal_transfers_classification import (
    classificate_internal_transfers,
    launch_internal_transfers_classification,
)
from services.common.exceptions import ServiceError
from tests.factories import (
    HOUSEHOLD_ID,
    fake_get_session,
    make_bank_account,
    make_transaction,
    make_user,
)

MODULE = "jobs.transaction_internal_transfers_classification"


class ClassificateInternalTransfersTests(unittest.TestCase):
    def setUp(self):
        self.session = MagicMock()
        self.ana = make_user(id=uuid.uuid4(), first_name="Ana")
        self.bia = make_user(id=uuid.uuid4(), first_name="Bia")
        self.checking = make_bank_account(id=uuid.uuid4())
        self.savings = make_bank_account(id=uuid.uuid4(), subtype="SAVINGS_ACCOUNT")

        self.mocks = {}
        for name in (
            "list_users_by_household",
            "list_bank_accounts_by_user",
            "list_unclassified_transactions",
            "find_same_person_pairs",
            "mark_internal_transfer",
        ):
            patcher = patch(f"{MODULE}.{name}")
            self.mocks[name] = patcher.start()
            self.addCleanup(patcher.stop)
        self.mocks["list_users_by_household"].return_value = [self.ana]
        self.mocks["list_bank_accounts_by_user"].return_value = [
            self.checking,
            self.savings,
        ]
        self.mocks["list_unclassified_transactions"].return_value = []
        self.mocks["find_same_person_pairs"].return_value = []
        self.mocks["mark_internal_transfer"].return_value = 0

    def test_marks_both_legs_of_each_pair_as_same_person_by_the_job(self):
        out, entry = make_transaction(), make_transaction(type="CREDIT")
        other_out, other_entry = make_transaction(), make_transaction(type="CREDIT")
        self.mocks["find_same_person_pairs"].return_value = [
            (out, entry),
            (other_out, other_entry),
        ]
        self.mocks["mark_internal_transfer"].return_value = 4

        marked = classificate_internal_transfers(self.session, HOUSEHOLD_ID)

        self.assertEqual(marked, 4)
        self.mocks["mark_internal_transfer"].assert_called_once_with(
            self.session,
            [out.id, entry.id, other_out.id, other_entry.id],
            "SAME_PERSON",
            "AUTO",
        )

    def test_looks_for_the_transactions_of_all_the_bank_accounts_of_the_person(self):
        classificate_internal_transfers(self.session, HOUSEHOLD_ID)

        self.mocks["list_bank_accounts_by_user"].assert_called_once_with(
            self.session, self.ana.id
        )
        self.mocks["list_unclassified_transactions"].assert_called_once_with(
            self.session, [self.checking.id, self.savings.id]
        )

    def test_a_person_with_one_account_has_nothing_to_pair(self):
        self.mocks["list_bank_accounts_by_user"].return_value = [self.checking]

        marked = classificate_internal_transfers(self.session, HOUSEHOLD_ID)

        self.assertEqual(marked, 0)
        self.mocks["list_unclassified_transactions"].assert_not_called()
        self.mocks["mark_internal_transfer"].assert_not_called()

    def test_each_person_is_paired_on_their_own_and_the_counts_add_up(self):
        self.mocks["list_users_by_household"].return_value = [self.ana, self.bia]
        self.mocks["mark_internal_transfer"].side_effect = [2, 4]
        out, entry = make_transaction(), make_transaction(type="CREDIT")
        self.mocks["find_same_person_pairs"].return_value = [(out, entry)]

        marked = classificate_internal_transfers(self.session, HOUSEHOLD_ID)

        self.assertEqual(marked, 6)
        self.assertEqual(
            [c.args[1] for c in self.mocks["list_bank_accounts_by_user"].call_args_list],
            [self.ana.id, self.bia.id],
        )

    def test_a_household_without_people_marks_nothing(self):
        self.mocks["list_users_by_household"].return_value = []

        self.assertEqual(classificate_internal_transfers(self.session, HOUSEHOLD_ID), 0)

    def test_it_does_not_commit_the_caller_does(self):
        classificate_internal_transfers(self.session, HOUSEHOLD_ID)

        self.session.commit.assert_not_called()


class LaunchInternalTransfersClassificationTests(unittest.TestCase):
    def setUp(self):
        self.session = MagicMock()
        patcher = patch(f"{MODULE}.get_session", fake_get_session(self.session))
        patcher.start()
        self.addCleanup(patcher.stop)
        classify_patcher = patch(f"{MODULE}.classificate_internal_transfers")
        self.classify = classify_patcher.start()
        self.addCleanup(classify_patcher.stop)
        self.classify.return_value = 2

    def test_runs_in_its_own_session_and_commits(self):
        launch_internal_transfers_classification(HOUSEHOLD_ID)

        self.classify.assert_called_once_with(self.session, HOUSEHOLD_ID)
        self.session.commit.assert_called_once()
        self.session.rollback.assert_not_called()

    def test_known_errors_roll_back_and_are_not_raised(self):
        for error in (ServiceError("db"), ValueError("Transaction without id")):
            with self.subTest(error=type(error).__name__):
                self.session.reset_mock()
                self.classify.side_effect = error

                launch_internal_transfers_classification(HOUSEHOLD_ID)

                self.session.rollback.assert_called_once()
                self.session.commit.assert_not_called()

    def test_an_unexpected_error_is_raised(self):
        self.classify.side_effect = RuntimeError("bug")

        with self.assertRaises(RuntimeError):
            launch_internal_transfers_classification(HOUSEHOLD_ID)
