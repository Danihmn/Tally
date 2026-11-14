import unittest
import uuid
from decimal import Decimal
from unittest.mock import MagicMock, patch

from jobs.transaction_internal_transfers_classification import (
    classificate_internal_transfers,
    launch_internal_transfers_classification,
    reclassify_internal_transfers,
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


# Invented documents (never real ones)
ME_CPF = "111.444.777-35"
PARTNER_CPF = "529.982.247-25"
STRANGER_CPF = "390.533.447-05"


def _party(document=None):
    return {"documentNumber": document}


def _payment(payer=None, receiver=None):
    return {"payer": _party(payer), "receiver": _party(receiver)}


def _ted_from_bank(bank_code, payer=None, receiver=None, method="TED"):
    """What a received TED carries: the payer's bank, no branch or account number."""
    data = _payment(payer, receiver)
    data["payer"]["routingNumber"] = bank_code
    data["paymentMethod"] = method
    return data


def _cpf(value):
    return {"type": "CPF", "value": value}


_CNPJ = {"type": "CNPJ", "value": "11.222.333/0001-81"}


def _debit(account, amount="100.00", **overrides):
    return make_transaction(
        id=uuid.uuid4(),
        bank_account_id=account.id,
        type="DEBIT",
        amount=-Decimal(amount),
        **overrides,
    )


def _credit(account, amount="100.00", **overrides):
    return make_transaction(
        id=uuid.uuid4(),
        bank_account_id=account.id,
        type="CREDIT",
        amount=Decimal(amount),
        **overrides,
    )


class ClassificateInternalTransfersTests(unittest.TestCase):
    def setUp(self):
        self.session = MagicMock()
        self.ana = make_user(id=uuid.uuid4(), first_name="Ana")
        self.bia = make_user(id=uuid.uuid4(), first_name="Bia")
        # Two accounts of Ana and one of Bia
        self.checking = make_bank_account(id=uuid.uuid4(), tax_number=ME_CPF)
        self.savings = make_bank_account(
            id=uuid.uuid4(), subtype="SAVINGS_ACCOUNT", tax_number=ME_CPF
        )
        self.partners = make_bank_account(id=uuid.uuid4(), tax_number=PARTNER_CPF)
        self.accounts_of = {
            self.ana.id: [self.checking, self.savings],
            self.bia.id: [self.partners],
        }

        self.mocks = {}
        for name in (
            "list_users_by_household",
            "list_bank_accounts_by_user",
            "list_unclassified_transactions",
            "mark_internal_transfer",
        ):
            patcher = patch(f"{MODULE}.{name}")
            self.mocks[name] = patcher.start()
            self.addCleanup(patcher.stop)
        self.mocks["list_users_by_household"].return_value = [self.ana, self.bia]
        self.mocks["list_bank_accounts_by_user"].side_effect = (
            lambda session, user_id: self.accounts_of[user_id]
        )
        self.mocks["list_unclassified_transactions"].return_value = []
        # What the service returns: how many it changed
        self.mocks["mark_internal_transfer"].side_effect = (
            lambda session, ids, value, source: len(ids)
        )

    def _run(self, transactions):
        self.mocks["list_unclassified_transactions"].return_value = transactions
        return classificate_internal_transfers(self.session, HOUSEHOLD_ID)

    def _marked(self):
        """{kind: [ids]} of what was written, and the source used."""
        result, sources = {}, set()
        for call in self.mocks["mark_internal_transfer"].call_args_list:
            _, ids, kind, source = call.args
            result[kind] = ids
            sources.add(source)
        return result, sources

    def test_looks_in_every_bank_account_of_every_person_in_one_query(self):
        self._run([])

        self.mocks["list_unclassified_transactions"].assert_called_once_with(
            self.session, [self.checking.id, self.savings.id, self.partners.id]
        )

    # -- the documents -----------------------------------------------------------------

    def test_a_transfer_to_my_own_cpf_is_marked_without_waiting_for_its_other_leg(self):
        lonely = _debit(self.checking, payment_data=_payment(_cpf(ME_CPF), _cpf(ME_CPF)))

        marked = self._run([lonely])

        self.assertEqual(marked, 1)
        self.assertEqual(self._marked(), ({"SAME_PERSON": [lonely.id]}, {"AUTO"}))

    def test_a_transfer_to_my_partners_cpf_is_a_same_household_transfer(self):
        sent = _debit(self.checking, payment_data=_payment(_cpf(ME_CPF), _cpf(PARTNER_CPF)))

        self._run([sent])

        self.assertEqual(self._marked()[0], {"SAME_HOUSEHOLD": [sent.id]})

    def test_a_payment_to_a_company_or_a_stranger_is_not_marked(self):
        company = _debit(self.checking, payment_data=_payment(_cpf(ME_CPF), _CNPJ))
        stranger = _debit(
            self.checking, "50.00", payment_data=_payment(_cpf(ME_CPF), _cpf(STRANGER_CPF))
        )

        marked = self._run([company, stranger])

        self.assertEqual(marked, 0)
        self.mocks["mark_internal_transfer"].assert_not_called()

    def test_a_stranger_cpf_is_not_trusted_while_someones_cpf_is_unknown(self):
        # Bia has no bank account, so her CPF is unknown: the "stranger" may be her
        self.accounts_of[self.bia.id] = []
        out = _debit(
            self.checking, payment_data=_payment(_cpf(ME_CPF), _cpf(STRANGER_CPF))
        )
        entry = _credit(self.savings)

        self._run([out, entry])

        # Not ruled out as external, so the pairing by amount still happens
        self.assertEqual(self._marked()[0], {"SAME_PERSON": [out.id, entry.id]})

    # -- the pairing -------------------------------------------------------------------

    def test_two_of_my_accounts_with_the_same_amount_are_a_same_person_pair(self):
        out, entry = _debit(self.checking), _credit(self.savings)

        marked = self._run([out, entry])

        self.assertEqual(marked, 2)
        self.assertEqual(self._marked(), ({"SAME_PERSON": [out.id, entry.id]}, {"AUTO"}))

    def test_my_account_and_my_partners_account_are_a_same_household_pair(self):
        out, entry = _debit(self.checking), _credit(self.partners)

        self._run([out, entry])

        self.assertEqual(self._marked()[0], {"SAME_HOUSEHOLD": [out.id, entry.id]})

    def test_a_pair_where_one_leg_has_the_document_marks_both_legs(self):
        out = _debit(self.checking, payment_data=_payment(_cpf(ME_CPF), _cpf(ME_CPF)))
        entry = _credit(self.savings)  # No payment_data at all

        self._run([out, entry])

        self.assertEqual(self._marked()[0], {"SAME_PERSON": [out.id, entry.id]})

    def test_the_documents_rule_out_a_pair_made_only_of_coincidence(self):
        out = _debit(self.checking, payment_data=_payment(_cpf(ME_CPF), _CNPJ))
        entry = _credit(self.savings)

        marked = self._run([out, entry])

        self.assertEqual(marked, 0)
        self.mocks["mark_internal_transfer"].assert_not_called()

    def test_a_transaction_without_a_partner_or_documents_stays_unclassified(self):
        self.assertEqual(self._run([_debit(self.checking)]), 0)
        self.mocks["mark_internal_transfer"].assert_not_called()

    def test_an_ambiguous_pair_stays_unclassified(self):
        out = _debit(self.checking)
        mine, partners = _credit(self.savings), _credit(self.partners)

        self.assertEqual(self._run([out, mine, partners]), 0)

    # -- the rest ----------------------------------------------------------------------

    def test_nothing_to_classify_marks_nothing(self):
        self.assertEqual(self._run([]), 0)
        self.mocks["mark_internal_transfer"].assert_not_called()

    def test_a_household_without_accounts_marks_nothing(self):
        self.accounts_of = {self.ana.id: [], self.bia.id: []}

        self.assertEqual(self._run([]), 0)
        self.mocks["list_unclassified_transactions"].assert_called_once_with(
            self.session, []
        )

    def test_it_does_not_commit_the_caller_does(self):
        self._run([_debit(self.checking), _credit(self.savings)])

        self.session.commit.assert_not_called()

    # -- the salary account (outgoing TEDs are income) ---------------------------------

    def _with_salary_account(self, bank_code="001", owner=None):
        salary = make_bank_account(
            id=uuid.uuid4(),
            tax_number=ME_CPF if owner is None else PARTNER_CPF,
            outgoing_transfers_are_income=True,
            bank_code=bank_code,
        )
        self.accounts_of[owner or self.ana.id].append(salary)
        return salary

    def test_my_ted_from_the_bank_of_my_salary_account_is_income(self):
        self._with_salary_account("001")
        salary = _credit(
            self.checking,
            "5000.00",
            payment_data=_ted_from_bank("001", _cpf(ME_CPF), _cpf(ME_CPF)),
        )

        marked = self._run([salary])

        self.assertEqual(marked, 1)
        self.assertEqual(
            self._marked(), ({"NOT_INTERNAL_TRANSFER": [salary.id]}, {"AUTO"})
        )

    def test_the_income_ted_is_not_used_to_pair_another_transaction(self):
        self._with_salary_account("001")
        salary = _credit(
            self.checking, payment_data=_ted_from_bank("001", _cpf(ME_CPF), _cpf(ME_CPF))
        )
        spent = _debit(self.savings)  # Same amount, no documents

        self._run([salary, spent])

        self.assertEqual(self._marked()[0], {"NOT_INTERNAL_TRANSFER": [salary.id]})

    def test_a_pix_from_the_same_bank_stays_an_internal_transfer(self):
        self._with_salary_account("001")
        pix = _credit(
            self.checking,
            payment_data=_ted_from_bank("001", _cpf(ME_CPF), _cpf(ME_CPF), method="PIX"),
        )

        self._run([pix])

        self.assertEqual(self._marked()[0], {"SAME_PERSON": [pix.id]})

    def test_my_ted_from_another_bank_stays_an_internal_transfer(self):
        self._with_salary_account("001")
        ted = _credit(
            self.checking, payment_data=_ted_from_bank("341", _cpf(ME_CPF), _cpf(ME_CPF))
        )

        self._run([ted])

        self.assertEqual(self._marked()[0], {"SAME_PERSON": [ted.id]})

    def test_a_salary_account_without_a_bank_code_changes_nothing(self):
        self._with_salary_account(bank_code=None)
        ted = _credit(
            self.checking, payment_data=_ted_from_bank("001", _cpf(ME_CPF), _cpf(ME_CPF))
        )

        self._run([ted])

        self.assertEqual(self._marked()[0], {"SAME_PERSON": [ted.id]})

    def test_my_partners_ted_from_that_bank_stays_a_household_transfer(self):
        self._with_salary_account("001")
        from_partner = _credit(
            self.checking,
            payment_data=_ted_from_bank("001", _cpf(PARTNER_CPF), _cpf(ME_CPF)),
        )

        self._run([from_partner])

        self.assertEqual(self._marked()[0], {"SAME_HOUSEHOLD": [from_partner.id]})

    def test_only_the_owner_of_the_salary_account_gets_the_income(self):
        # The salary account is Bia's: Ana's own TED from that bank is still a transfer
        self._with_salary_account("001", owner=self.bia.id)
        ted = _credit(
            self.checking, payment_data=_ted_from_bank("001", _cpf(ME_CPF), _cpf(ME_CPF))
        )

        self._run([ted])

        self.assertEqual(self._marked()[0], {"SAME_PERSON": [ted.id]})

    def test_a_ted_that_lands_in_the_salary_account_itself_is_not_income(self):
        salary_account = self._with_salary_account("001")
        ted = _credit(
            salary_account,
            payment_data=_ted_from_bank("001", _cpf(ME_CPF), _cpf(ME_CPF)),
        )

        self._run([ted])

        self.assertEqual(self._marked()[0], {"SAME_PERSON": [ted.id]})


class ReclassifyInternalTransfersTests(unittest.TestCase):
    def test_clears_the_auto_classification_and_then_classifies_again(self):
        session = MagicMock()
        calls = MagicMock()
        with (
            patch(f"{MODULE}.clear_auto_internal_transfers", calls.clear),
            patch(f"{MODULE}.classificate_internal_transfers", calls.classify),
        ):
            calls.classify.return_value = 3

            marked = reclassify_internal_transfers(session, HOUSEHOLD_ID)

        self.assertEqual(marked, 3)
        self.assertEqual(
            [c[0] for c in calls.mock_calls], ["clear", "classify"]
        )
        calls.clear.assert_called_once_with(session, HOUSEHOLD_ID)
        calls.classify.assert_called_once_with(session, HOUSEHOLD_ID)
        session.commit.assert_not_called()


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
