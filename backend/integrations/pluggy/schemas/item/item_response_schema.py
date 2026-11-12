from datetime import datetime
from uuid import UUID

from integrations.pluggy.schemas.pluggy_model import PluggyModel


class ItemResponseSchema(PluggyModel):
    """Only the fields we use of 'GET /items/{id}'. The others are ignored"""

    id: UUID
    status: str
    execution_status: str
    consent_expires_at: datetime | None = None
    last_updated_at: datetime | None = None
