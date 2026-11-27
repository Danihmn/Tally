import dataclasses
import unittest

from domain.entities import FinancialEntry, Recurrence
from sqlalchemy import CheckConstraint

from infra.database.models import (
    Conversations,
    FinancialEntries,
    RefreshTokens,
    Recurrences,
    Transactions,
)


def _missing_columns(entity, model) -> set[str]:
    """Entity fields with no column in the model (the model is stale)."""
    fields = {field.name for field in dataclasses.fields(entity)}
    return fields - set(model.__table__.columns.keys())


class TestModelsMatchEntities(unittest.TestCase):
    def test_every_recurrence_field_is_a_column(self):
        self.assertEqual(_missing_columns(Recurrence, Recurrences), set())

    def test_every_financial_entry_field_is_a_column(self):
        self.assertEqual(_missing_columns(FinancialEntry, FinancialEntries), set())


class TestRecurrenceStatusColumn(unittest.TestCase):
    def test_status_defaults_to_active_and_is_required(self):
        column = Recurrences.__table__.columns["status"]
        self.assertFalse(column.nullable)
        self.assertIn("ACTIVE", str(column.server_default.arg))

    def test_recurrence_month_index_ignores_cancelled_entries(self):
        index = next(
            i
            for i in FinancialEntries.__table__.indexes
            if i.name == "uq_financial_entries_recurrence_month"
        )
        self.assertTrue(index.unique)
        self.assertIn("CANCELLED", str(index.dialect_options["postgresql"]["where"]))


def _index(model, name: str):
    return next(i for i in model.__table__.indexes if i.name == name)


def _check_names(model) -> set[str]:
    return {c.name for c in model.__table__.constraints if isinstance(c, CheckConstraint)}


class TestRecentFirstIndexes(unittest.TestCase):
    """The database has these indexes in DESC order: the models must keep it."""

    def test_transactions_by_account_are_newest_first(self):
        index = _index(Transactions, "idx_transactions_account_date")
        self.assertIn("date DESC", [str(e) for e in index.expressions])

    def test_transactions_by_household_are_newest_first(self):
        index = _index(Transactions, "idx_transactions_household_date")
        self.assertIn("date DESC", [str(e) for e in index.expressions])

    def test_conversations_are_most_recent_first(self):
        index = _index(Conversations, "idx_conversations_user_recent")
        self.assertIn("last_message_at DESC", [str(e) for e in index.expressions])


class TestCheckConstraintNames(unittest.TestCase):
    """Names must match the database, or a future migration cannot drop them."""

    def test_installment_check_has_the_database_name(self):
        names = _check_names(FinancialEntries)
        self.assertIn("financial_entries_check", names)
        self.assertNotIn("financial_entries_installment_total_check", names)

    def test_internal_transfer_checks_exist(self):
        self.assertLessEqual(
            {
                "transactions_internal_transfer_check",
                "transactions_internal_transfer_source_check",
                "transactions_internal_transfer_consistency_check",
            },
            _check_names(Transactions),
        )


if __name__ == "__main__":
    unittest.main()


class TestRefreshTokensTable(unittest.TestCase):
    def test_token_hash_is_unique(self):
        names = {c.name for c in RefreshTokens.__table__.constraints}
        self.assertIn("refresh_tokens_token_hash_key", names)

    def test_every_entity_field_is_a_column(self):
        from domain.entities import RefreshToken

        self.assertEqual(_missing_columns(RefreshToken, RefreshTokens), set())

    def test_there_is_no_column_for_the_token_itself(self):
        self.assertNotIn("token", RefreshTokens.__table__.columns.keys())
