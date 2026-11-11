import datetime
import uuid
from dataclasses import dataclass


@dataclass(slots=True)
class Household:
    id: uuid.UUID | None = None
    created_at: datetime.datetime | None = None
