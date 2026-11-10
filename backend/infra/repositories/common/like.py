from sqlalchemy import ColumnElement
from sqlalchemy.orm import QueryableAttribute


def escape_like(text: str) -> str:
    return text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def ilike_contains(
    column: QueryableAttribute[str | None], text: str
) -> ColumnElement[bool]:
    """Case-insensitive "contains" match with LIKE wildcards in `text` escaped."""
    return column.ilike(f"%{escape_like(text)}%", escape="\\")
