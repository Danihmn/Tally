import dataclasses
import datetime
import unittest
import uuid
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from domain.read_models import RecurrenceFilters
from services.common.exceptions import (
    AlreadyExistsError,
    InvalidDataError,
    NoRecurrencesError,
    NotFoundError,
)
from services.recurrences_service import (
    create_recurrence,
    delete_recurrence,
    get_recurrence,
    provision_next_month,
    search_recurrences,
    update_recurrence,
)
from tests.factories import HOUSEHOLD_ID, USER_ID, make_recurrence

MODULE = "services.recurrences_service"
TODAY = datetime.date(2026, 11, 15)
NEXT_MONTH = datetime.date(2026, 12, 1)


def _as_model(recurrence):
    """What the repository returns: an object with the columns of the recurrence."""
    return SimpleNamespace(
        **{f.name: getattr(recurrence, f.name) for f in dataclasses.fields(recurrence)}
    )


class SearchRecurrencesTests(unittest.TestCase):
    def test_returns_the_page_and_the_total_of_the_filters(self):
        rows = [_as_model(make_recurrence()), _as_model(make_recurrence())]
        filters = RecurrenceFilters(household_id=HOUSEHOLD_ID)
        with patch(f"{MODULE}.recurrences_repository") as repository:
            repository.search_recurrences.return_value = rows
            repository.count_recurrences.return_value = 7
            items, total = search_recurrences(MagicMock(), filters, limit=2, offset=4)

        self.assertEqual((len(items), total), (2, 7))
        self.assertEqual(repository.search_recurrences.call_args.args[1:], (filters, 2, 4))


class GetRecurrenceTests(unittest.TestCase):
    def test_returns_the_recurrence_of_the_household(self):
        recurrence = make_recurrence()
        with patch(f"{MODULE}.recurrences_repository") as repository:
            repository.get_recurrence.return_value = _as_model(recurrence)
            result = get_recurrence(MagicMock(), HOUSEHOLD_ID, recurrence.id)

        self.assertEqual(result, recurrence)
        self.assertEqual(
            repository.get_recurrence.call_args.args[1:], (recurrence.id, HOUSEHOLD_ID)
        )

    def test_a_recurrence_outside_the_household_is_not_found(self):
        with patch(f"{MODULE}.recurrences_repository") as repository:
            repository.get_recurrence.return_value = None
            with self.assertRaises(NotFoundError):
                get_recurrence(MagicMock(), HOUSEHOLD_ID, uuid.uuid4())


class CreateRecurrenceTests(unittest.TestCase):
    def test_stores_the_recurrence_without_an_id_and_returns_it(self):
        recurrence = make_recurrence(id=None)
        with (
            patch(f"{MODULE}.recurrences_repository") as repository,
            patch(f"{MODULE}.users_repository"),
        ):
            repository.create_recurrence.side_effect = lambda session, values: _as_model(
                make_recurrence(**{**values, "id": uuid.uuid4()})
            )
            result = create_recurrence(MagicMock(), recurrence)

        values = repository.create_recurrence.call_args.args[1]
        self.assertNotIn("id", values)
        self.assertEqual(values["description"], recurrence.description)
        self.assertIsNotNone(result.id)


    def test_a_new_recurrence_starts_active(self):
        self.assertEqual(make_recurrence().status, "ACTIVE")

    def test_the_owner_is_checked_in_the_household(self):
        recurrence = make_recurrence(id=None)
        with (
            patch(f"{MODULE}.recurrences_repository") as repository,
            patch(f"{MODULE}.users_repository") as users,
        ):
            repository.create_recurrence.return_value = _as_model(make_recurrence())
            create_recurrence(MagicMock(), recurrence)

        self.assertEqual(
            users.get_user_in_household.call_args.args[1:],
            (recurrence.user_id, HOUSEHOLD_ID),
        )

    def test_an_owner_outside_the_household_is_invalid_and_nothing_is_stored(self):
        with (
            patch(f"{MODULE}.recurrences_repository") as repository,
            patch(f"{MODULE}.users_repository") as users,
        ):
            users.get_user_in_household.return_value = None
            with self.assertRaises(InvalidDataError):
                create_recurrence(MagicMock(), make_recurrence(id=None))

        repository.create_recurrence.assert_not_called()


class UpdateRecurrenceTests(unittest.TestCase):
    def test_writes_only_the_given_values(self):
        stored = make_recurrence()
        with patch(f"{MODULE}.recurrences_repository") as repository:
            repository.get_recurrence.return_value = _as_model(stored)
            repository.update_recurrence.side_effect = lambda session, model, vals: _as_model(
                make_recurrence(**{**vars(model), **vals})
            )
            result = update_recurrence(
                MagicMock(), HOUSEHOLD_ID, stored.id, {"amount": Decimal("1600.00")}
            )

        self.assertEqual(repository.update_recurrence.call_args.args[2], {"amount": Decimal("1600.00")})
        self.assertEqual(result.amount, Decimal("1600.00"))

    def test_a_recurrence_outside_the_household_is_not_found(self):
        with patch(f"{MODULE}.recurrences_repository") as repository:
            repository.get_recurrence.return_value = None
            with self.assertRaises(NotFoundError):
                update_recurrence(MagicMock(), HOUSEHOLD_ID, uuid.uuid4(), {"notes": "x"})

        repository.update_recurrence.assert_not_called()

    def test_a_new_owner_outside_the_household_is_invalid_and_nothing_changes(self):
        with (
            patch(f"{MODULE}.recurrences_repository") as repository,
            patch(f"{MODULE}.users_repository") as users,
        ):
            repository.get_recurrence.return_value = _as_model(make_recurrence())
            users.get_user_in_household.return_value = None
            with self.assertRaises(InvalidDataError):
                update_recurrence(
                    MagicMock(), HOUSEHOLD_ID, uuid.uuid4(), {"user_id": uuid.uuid4()}
                )

        repository.update_recurrence.assert_not_called()

    def test_the_owner_is_not_checked_when_it_does_not_change(self):
        stored = make_recurrence()
        with (
            patch(f"{MODULE}.recurrences_repository") as repository,
            patch(f"{MODULE}.users_repository") as users,
        ):
            repository.get_recurrence.return_value = _as_model(stored)
            repository.update_recurrence.return_value = _as_model(
                make_recurrence(status="CANCELLED")
            )
            result = update_recurrence(
                MagicMock(), HOUSEHOLD_ID, stored.id, {"status": "CANCELLED"}
            )

        users.get_user_in_household.assert_not_called()
        self.assertEqual(result.status, "CANCELLED")


class DeleteRecurrenceTests(unittest.TestCase):
    def test_soft_deletes_the_recurrence_of_the_household(self):
        model = _as_model(make_recurrence())
        with patch(f"{MODULE}.recurrences_repository") as repository:
            repository.get_recurrence.return_value = model
            delete_recurrence(MagicMock(), HOUSEHOLD_ID, model.id)

        self.assertIs(repository.soft_delete_recurrence.call_args.args[1], model)

    def test_a_recurrence_outside_the_household_is_not_found(self):
        with patch(f"{MODULE}.recurrences_repository") as repository:
            repository.get_recurrence.return_value = None
            with self.assertRaises(NotFoundError):
                delete_recurrence(MagicMock(), HOUSEHOLD_ID, uuid.uuid4())

        repository.soft_delete_recurrence.assert_not_called()


class ProvisionNextMonthTests(unittest.TestCase):
    def _provision(self, recurrences, already=(), create_side_effect=None):
        session = MagicMock()
        with (
            patch(f"{MODULE}.recurrences_repository") as recurrences_repo,
            patch(f"{MODULE}.list_provisioned_recurrence_ids") as list_provisioned,
            patch(f"{MODULE}.create_financial_entry") as create_entry,
        ):
            recurrences_repo.list_recurrences.return_value = [_as_model(r) for r in recurrences]
            list_provisioned.return_value = set(already)
            create_entry.side_effect = create_side_effect
            try:
                result = provision_next_month(session, HOUSEHOLD_ID, USER_ID, TODAY)
            finally:
                self.list_provisioned = list_provisioned
                self.create_entry = create_entry
                self.session = session
        return result

    def _created_values(self):
        """The entries sent to the financial entries service, as dicts."""
        return [dataclasses.asdict(call.args[1]) for call in self.create_entry.call_args_list]

    def test_without_recurrences_nothing_is_created(self):
        with self.assertRaises(NoRecurrencesError):
            self._provision([])

        self.create_entry.assert_not_called()

    def test_creates_a_planned_entry_in_next_month_for_each_recurrence(self):
        rent = make_recurrence(description="Rent", amount=Decimal("1500.00"), due_day=5)
        salary = make_recurrence(description="Salary", type="REVENUES", amount=Decimal("5000.00"), due_day=None)

        result = self._provision([rent, salary])

        self.assertEqual((result.reference_month, result.created, result.skipped), (NEXT_MONTH, 2, 0))
        first, second = self._created_values()
        self.assertEqual(first["description"], "Rent")
        self.assertEqual(first["reference_month"], NEXT_MONTH)
        self.assertEqual(first["due_date"], datetime.date(2026, 12, 5))
        self.assertEqual(first["status"], "PLANNED")
        self.assertEqual(first["recurrence_id"], rent.id)
        self.assertEqual(first["amount"], Decimal("1500.00"))
        self.assertEqual((second["type"], second["due_date"]), ("REVENUES", None))

    def test_a_recurrence_that_already_has_its_entry_is_not_duplicated(self):
        done, pending = make_recurrence(), make_recurrence()

        result = self._provision([done, pending], already=[done.id])

        self.assertEqual((result.created, result.skipped), (1, 1))
        self.assertEqual([v["recurrence_id"] for v in self._created_values()], [pending.id])

    def test_when_everything_is_provisioned_it_creates_nothing_and_is_not_an_error(self):
        recurrence = make_recurrence()

        result = self._provision([recurrence], already=[recurrence.id])

        self.assertEqual((result.created, result.skipped), (0, 1))
        self.create_entry.assert_not_called()

    def test_a_due_day_past_the_end_of_the_month_becomes_its_last_day(self):
        recurrence = make_recurrence(due_day=31)

        with patch(f"{MODULE}.next_month_start", return_value=datetime.date(2026, 11, 1)):
            self._provision([recurrence])

        self.assertEqual(self._created_values()[0]["due_date"], datetime.date(2026, 11, 30))

    def test_the_year_changes_when_provisioning_from_december(self):
        session = MagicMock()
        with (
            patch(f"{MODULE}.recurrences_repository") as recurrences_repo,
            patch(f"{MODULE}.list_provisioned_recurrence_ids", return_value=set()),
            patch(f"{MODULE}.create_financial_entry"),
        ):
            recurrences_repo.list_recurrences.return_value = [_as_model(make_recurrence())]
            result = provision_next_month(session, HOUSEHOLD_ID, USER_ID, datetime.date(2026, 12, 20))

        self.assertEqual(result.reference_month, datetime.date(2027, 1, 1))

    def test_the_owner_is_the_recurrence_user_or_the_logged_user_when_it_has_none(self):
        owned = make_recurrence(user_id=uuid.uuid4())
        orphan = make_recurrence(user_id=None)

        self._provision([owned, orphan])

        first, second = self._created_values()
        self.assertEqual(first["user_id"], owned.user_id)
        self.assertEqual(second["user_id"], USER_ID)

    def test_asks_the_entries_service_what_is_provisioned_in_next_month(self):
        self._provision([make_recurrence()])

        self.assertEqual(
            self.list_provisioned.call_args.args,
            (self.session, HOUSEHOLD_ID, NEXT_MONTH),
        )

    def test_each_entry_is_created_inside_a_savepoint(self):
        self._provision([make_recurrence(), make_recurrence()])

        self.assertEqual(self.session.begin_nested.call_count, 2)

    def test_an_entry_created_by_a_concurrent_call_is_skipped_not_an_error(self):
        first, second = make_recurrence(), make_recurrence()
        calls = iter([AlreadyExistsError("financial_entries"), None])

        def create(session, entry):
            outcome = next(calls)
            if outcome is not None:
                raise outcome

        result = self._provision([first, second], create_side_effect=create)

        self.assertEqual((result.created, result.skipped), (1, 1))
