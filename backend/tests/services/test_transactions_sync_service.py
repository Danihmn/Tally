import unittest
import uuid
from decimal import Decimal
from unittest.mock import MagicMock, patch

from services.transactions_sync_service import (
    diff_transaction,
    sync_account_transactions,
    to_transaction_entity,
)
from tests.factories import (
    ACCOUNT_ID,
    make_incoming,
    make_transaction,
    make_transaction_schema,
    utc,
)

MODULE = "services.transactions_sync_service"
DATE_FROM = utc(2026, 5, 9, hour=0)


class ToTransactionEntityTests(unittest.TestCase):
    def test_maps_the_pluggy_schema_to_the_entity(self):
        schema = make_transaction_schema(
            amount=Decimal("-10.005"),
            provider_id="prov-1",
            merchant={"name": "Shop"},
        )

        entity = to_transaction_entity(schema, ACCOUNT_ID)

        self.assertIsNone(entity.id)
        self.assertEqual(entity.bank_account_id, ACCOUNT_ID)
        self.assertEqual(entity.pluggy_transaction_id, schema.id)
        self.assertEqual(entity.amount, Decimal("-10.01"))  # rounded by the schema
        self.assertEqual(entity.status, "POSTED")
        self.assertEqual(entity.type, "DEBIT")
        self.assertIsInstance(entity.status, str)
        self.assertEqual(entity.provider_id, "prov-1")
        self.assertEqual(entity.merchant, {"name": "Shop"})


class DiffTransactionTests(unittest.TestCase):
    def test_no_difference(self):
        stored = make_transaction()

        self.assertEqual(diff_transaction(stored, make_incoming(stored)), {})

    def test_returns_old_and_new_values(self):
        stored = make_transaction(description="A", amount=Decimal("-1.00"))
        incoming = make_incoming(stored, description="B", amount=Decimal("-2.00"))

        self.assertEqual(
            diff_transaction(stored, incoming),
            {"description": ("A", "B"), "amount": (Decimal("-1.00"), Decimal("-2.00"))},
        )

    def test_ignores_our_own_columns(self):
        stored = make_transaction(deleted_at=utc(2026, 11, 1))
        incoming = make_incoming(stored, id=uuid.uuid4())

        self.assertEqual(diff_transaction(stored, incoming), {})


class SyncAccountTransactionsTests(unittest.TestCase):
    def setUp(self):
        self.session = MagicMock()
        self.mocks = {}
        for name in (
            "list_transactions_since",
            "upsert_transactions",
            "update_transactions",
            "mark_transactions_deleted",
            "undo_reconciliations_of_transactions",
        ):
            patcher = patch(f"{MODULE}.{name}")
            self.mocks[name] = patcher.start()
            self.addCleanup(patcher.stop)
        self.mocks["undo_reconciliations_of_transactions"].return_value = 0

    def _sync(self, stored, incoming):
        self.mocks["list_transactions_since"].return_value = stored
        return sync_account_transactions(self.session, ACCOUNT_ID, incoming, DATE_FROM)

    def _undo_calls(self):
        return self.mocks["undo_reconciliations_of_transactions"].call_args_list

    def test_reads_the_stored_rows_with_the_deleted_ones(self):
        self._sync([], [])

        self.mocks["list_transactions_since"].assert_called_once_with(
            self.session, ACCOUNT_ID, DATE_FROM, include_deleted=True
        )

    def test_new_transaction_is_created(self):
        incoming = make_transaction(id=None)

        result = self._sync([], [incoming])

        self.assertEqual(result.created, 1)
        self.mocks["upsert_transactions"].assert_called_once_with(
            self.session, [incoming]
        )
        self.mocks["update_transactions"].assert_not_called()

    def test_same_transaction_twice_in_the_input_is_created_once(self):
        first = make_transaction(id=None)
        second = make_incoming(first, description="Updated")

        result = self._sync([], [first, second])

        self.assertEqual(result.created, 1)
        self.mocks["upsert_transactions"].assert_called_once_with(
            self.session, [second]
        )

    def test_unchanged_transaction_writes_nothing(self):
        stored = make_transaction()

        result = self._sync([stored], [make_incoming(stored)])

        self.assertEqual((result.created, result.updated, result.deleted), (0, 0, 0))
        self.mocks["upsert_transactions"].assert_not_called()
        self.mocks["update_transactions"].assert_not_called()
        self.mocks["mark_transactions_deleted"].assert_not_called()
        self.mocks["undo_reconciliations_of_transactions"].assert_not_called()

    def test_changed_transaction_is_updated(self):
        stored = make_transaction(description="Old")
        incoming = make_incoming(stored, description="New")

        result = self._sync([stored], [incoming])

        self.assertEqual(result.updated, 1)
        self.mocks["upsert_transactions"].assert_called_once_with(
            self.session, [incoming]
        )

    def test_non_critical_change_keeps_the_reconciliations(self):
        stored = make_transaction(category="Food")

        self._sync([stored], [make_incoming(stored, category="Market")])

        self.mocks["undo_reconciliations_of_transactions"].assert_not_called()

    def test_critical_change_undoes_only_the_auto_reconciliations(self):
        for field, value in (
            ("amount", Decimal("-120.00")),
            ("date", utc(2026, 11, 6)),
            ("type", "CREDIT"),
        ):
            with self.subTest(field=field):
                self.mocks["undo_reconciliations_of_transactions"].reset_mock()
                self.mocks["undo_reconciliations_of_transactions"].return_value = 1
                stored = make_transaction()

                result = self._sync([stored], [make_incoming(stored, **{field: value})])

                self.assertEqual(result.updated, 1)
                self.assertEqual(result.reconciliations_undone, 1)
                self.mocks[
                    "undo_reconciliations_of_transactions"
                ].assert_called_once_with(self.session, [stored.id], only_auto=True)

    def test_deleted_transaction_returned_again_is_restored(self):
        stored = make_transaction(deleted_at=utc(2026, 11, 1))
        incoming = make_incoming(stored)

        result = self._sync([stored], [incoming])

        self.assertEqual((result.restored, result.updated), (1, 0))
        self.mocks["upsert_transactions"].assert_called_once_with(
            self.session, [incoming]
        )

    def test_pluggy_id_changed_is_found_by_provider_id(self):
        stored = make_transaction(provider_id="prov-1", status="PENDING")
        incoming = make_incoming(
            stored, pluggy_transaction_id=uuid.uuid4(), status="POSTED"
        )

        result = self._sync([stored], [incoming])

        self.assertEqual((result.id_changed, result.created, result.deleted), (1, 0, 0))
        self.assertEqual(incoming.id, stored.id)  # keeps our id
        self.mocks["update_transactions"].assert_called_once_with(
            self.session, [incoming]
        )
        self.mocks["upsert_transactions"].assert_not_called()
        self.mocks["mark_transactions_deleted"].assert_not_called()

    def test_pluggy_id_changed_with_a_critical_change_undoes_the_auto_reconciliations(
        self,
    ):
        stored = make_transaction(provider_id="prov-1")
        incoming = make_incoming(
            stored, pluggy_transaction_id=uuid.uuid4(), amount=Decimal("-1.00")
        )

        self._sync([stored], [incoming])

        self.mocks["undo_reconciliations_of_transactions"].assert_called_once_with(
            self.session, [stored.id], only_auto=True
        )

    def test_second_incoming_with_the_same_provider_id_is_ignored(self):
        stored = make_transaction(provider_id="prov-1")
        first = make_incoming(stored, pluggy_transaction_id=uuid.uuid4())
        second = make_incoming(stored, pluggy_transaction_id=uuid.uuid4())

        result = self._sync([stored], [first, second])

        self.assertEqual((result.id_changed, result.created), (1, 0))
        self.mocks["update_transactions"].assert_called_once_with(self.session, [first])

    def test_ambiguous_provider_id_creates_a_new_transaction(self):
        stored = [
            make_transaction(provider_id="prov-1"),
            make_transaction(provider_id="prov-1"),
        ]
        incoming = make_transaction(id=None, provider_id="prov-1")

        result = self._sync(stored, [*map(make_incoming, stored), incoming])

        self.assertEqual((result.id_changed, result.created), (0, 1))
        self.mocks["update_transactions"].assert_not_called()

    def test_deleted_row_does_not_make_the_provider_id_ambiguous(self):
        alive = make_transaction(provider_id="prov-1")
        deleted = make_transaction(provider_id="prov-1", deleted_at=utc(2026, 11, 1))
        incoming = make_incoming(alive, pluggy_transaction_id=uuid.uuid4())

        result = self._sync([alive, deleted], [incoming])

        self.assertEqual(result.id_changed, 1)
        self.assertEqual(incoming.id, alive.id)

    def test_stored_transaction_missing_from_pluggy_is_deleted(self):
        kept = make_transaction()
        gone = make_transaction()
        self.mocks["undo_reconciliations_of_transactions"].return_value = 2

        result = self._sync([kept, gone], [make_incoming(kept)])

        self.assertEqual((result.deleted, result.reconciliations_undone), (1, 2))
        self.mocks["mark_transactions_deleted"].assert_called_once_with(
            self.session, [gone.id]
        )
        # Every source (AUTO and MANUAL): a deleted transaction backs nothing
        self.mocks["undo_reconciliations_of_transactions"].assert_called_once_with(
            self.session, [gone.id]
        )

    def test_already_deleted_transaction_is_not_deleted_again(self):
        kept = make_transaction()
        deleted = make_transaction(deleted_at=utc(2026, 11, 1))

        self._sync([kept, deleted], [make_incoming(kept)])

        self.mocks["mark_transactions_deleted"].assert_not_called()

    def test_transaction_near_the_window_start_is_not_deleted(self):
        kept = make_transaction()
        edge = make_transaction(
            date=utc(2026, 5, 10)
        )  # less than 2 days after DATE_FROM
        after_edge = make_transaction(date=utc(2026, 5, 11, hour=0))  # exactly 2 days

        self._sync([kept, edge, after_edge], [make_incoming(kept)])

        self.mocks["mark_transactions_deleted"].assert_called_once_with(
            self.session, [after_edge.id]
        )

    def test_empty_answer_from_pluggy_deletes_nothing(self):
        # Expired consent returns nothing (CLAUDE.md 5.3): the history must survive it
        result = self._sync([make_transaction(), make_transaction()], [])

        self.assertEqual(result.deleted, 0)
        self.mocks["mark_transactions_deleted"].assert_not_called()
        self.mocks["undo_reconciliations_of_transactions"].assert_not_called()


if __name__ == "__main__":
    unittest.main()
