import unittest
from types import SimpleNamespace

from sqlalchemy import Column, Index, Integer, MetaData, Table

from infra.database.alembic_filters import IGNORED_TABLES, include_object
from infra.database.models import Base


def _table(name: str) -> Table:
    return Table(name, MetaData(), Column("id", Integer, primary_key=True))


class TestIncludeObjectTables(unittest.TestCase):
    def test_langgraph_tables_in_the_database_are_ignored(self):
        for name in IGNORED_TABLES:
            with self.subTest(name=name):
                self.assertFalse(include_object(_table(name), name, "table", True, None))

    def test_domain_table_is_compared(self):
        table = Base.metadata.tables["transactions"]
        self.assertTrue(include_object(table, "transactions", "table", True, table))

    def test_new_model_table_not_in_the_database_is_created(self):
        table = Base.metadata.tables["users"]
        self.assertTrue(include_object(table, "users", "table", False, None))

    def test_table_removed_from_the_models_is_still_dropped(self):
        self.assertTrue(include_object(_table("old_table"), "old_table", "table", True, None))

    def test_no_model_uses_an_ignored_table_name(self):
        self.assertEqual(set(Base.metadata.tables) & IGNORED_TABLES, set())


class TestIncludeObjectChildren(unittest.TestCase):
    def test_index_of_a_langgraph_table_is_ignored(self):
        table = _table("checkpoints")
        index = Index("checkpoints_thread_id_idx", table.c.id)
        self.assertFalse(include_object(index, index.name, "index", True, None))

    def test_column_of_a_langgraph_table_is_ignored(self):
        column = _table("checkpoint_writes").c.id
        self.assertFalse(include_object(column, "id", "column", True, None))

    def test_index_of_a_domain_table_is_compared(self):
        index = next(iter(Base.metadata.tables["transactions"].indexes))
        self.assertTrue(include_object(index, index.name, "index", True, index))

    def test_object_without_table_is_compared(self):
        obj = SimpleNamespace()
        self.assertTrue(include_object(obj, "some_type", "type", False, None))


if __name__ == "__main__":
    unittest.main()
