from dataclasses import dataclass

from domain.entities import User


@dataclass(slots=True)
class TallyContext:
    """Per-call data the tools read. It comes from the token, never from the model, and it is not
    part of the tools' schemas, so the model can neither see nor change it."""

    user: User
