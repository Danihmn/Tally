import uuid
from typing import Any


def require_id(entity: Any, label: str) -> uuid.UUID:
    """The entity's id. Raises ValueError("<label> without id") when it was never saved."""
    if entity.id is None:
        raise ValueError(f"{label} without id")
    return entity.id
