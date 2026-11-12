from datetime import datetime
from uuid import UUID

from integrations.pluggy.schemas.pluggy_model import PluggyModel


class WebhookResponseSchema(PluggyModel):
    id: UUID
    url: str
    event: str
    headers: dict[str, str]  # Always present; empty when none are configured
    disabled_at: datetime | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None
