import datetime
import decimal
import uuid
from dataclasses import dataclass


@dataclass(slots=True)
class Recurrence:
    description: str
    type: str  # REVENUES | EXPENSES
    amount: decimal.Decimal
    household_id: uuid.UUID
    currency_code: str = "BRL"
    source: str = "MANUAL"  # MANUAL | AI
    id: uuid.UUID | None = None
    created_at: datetime.datetime | None = None
    updated_at: datetime.datetime | None = None
    deleted_at: datetime.datetime | None = None
    user_id: uuid.UUID | None = None
    category: str | None = None
    payment_type: str | None = None  # DEBIT | CREDIT
    notes: str | None = None
    due_day: int | None = None  # 1..31
