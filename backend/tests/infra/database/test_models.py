import dataclasses
import unittest

from domain.entities import FinancialEntry, Recurrence
from infra.database.models import FinancialEntries, Recurrences


def _missing_columns(entity, model) -> set[str]:
    """Entity fields with no column in the generated model (the model is stale)."""
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


if __name__ == "__main__":
    unittest.main()
