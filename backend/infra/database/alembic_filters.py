"""Filters for Alembic autogenerate (used by alembic/env.py)."""

from typing import Any

# Tables that live in our database but are not ours: the LangGraph PostgresSaver
# (Tally conversation history) creates them by itself with setup(). They are never
# in models.py, so autogenerate must not touch them.
IGNORED_TABLES = frozenset(
    {
        "checkpoints",
        "checkpoint_blobs",
        "checkpoint_writes",
        "checkpoint_migrations",
    }
)


def include_object(
    obj: Any, name: str | None, type_: str, reflected: bool, compare_to: Any
) -> bool:
    """Tells Alembic autogenerate which objects it compares with the models.

    Without it, autogenerate would write a drop_table for each LangGraph table.
    Any other table missing from models.py still gets a drop_table, on purpose.
    """
    if type_ == "table":
        return name not in IGNORED_TABLES

    table = getattr(obj, "table", None)
    if table is not None and table.name in IGNORED_TABLES:
        return False

    return True
