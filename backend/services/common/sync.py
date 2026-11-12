"""Helpers shared by the Pluggy sync services (accounts and transactions)."""

import logging
from typing import Any

Changes = dict[str, tuple[Any, Any]]


def diff_fields(stored: Any, incoming: Any, fields: tuple[str, ...]) -> Changes:
    """Fields that differ, as {field: (stored value, incoming value)}."""
    return {
        field: (getattr(stored, field), getattr(incoming, field))
        for field in fields
        if getattr(stored, field) != getattr(incoming, field)
    }


def log_critical_changes(
    logger: logging.Logger,
    kind: str,
    pluggy_id: Any,
    changes: Changes,
    critical_fields: tuple[str, ...],
) -> bool:
    """Logs a warning with the critical fields that changed on Pluggy. True when there was any.

    The caller's logger is used, so the log keeps the name of the sync module."""
    critical = {f: changes[f] for f in critical_fields if f in changes}
    if critical:
        logger.warning(
            "%s %s changed on Pluggy: %s",
            kind,
            pluggy_id,
            {f: f"{old} -> {new}" for f, (old, new) in critical.items()},
        )
    return bool(critical)
