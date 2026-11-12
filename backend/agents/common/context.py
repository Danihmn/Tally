from dataclasses import dataclass

from domain.entities import User


@dataclass(slots=True)
class AgentContext:
    """Per-call data the shared tools read. It comes from the token, never from the model, and it
    is not part of the tools' schemas, so the model can neither see nor change it.

    Each agent has its own context that extends this one with what only that agent needs."""

    user: User
