import logging

from infra.database.session import get_session
from jobs._common import JOB_ERRORS, iter_all_users
from services.pluggy_webhooks_service import ensure_item_webhooks
from settings import settings

logger = logging.getLogger(__name__)


def register_webhooks() -> None:
    """Registers (or fixes) the Pluggy webhooks of every user. Never raises: it runs at the app's startup"""
    if not settings.public_base_url:
        logger.warning(
            "PUBLIC_BASE_URL is not set, skipping the Pluggy webhook registration"
        )
        return

    with get_session() as session:
        for user in iter_all_users(session):
            try:
                ensure_item_webhooks(session, user, settings.public_base_url)
                session.commit()
            except JOB_ERRORS:
                # One user failing must not stop the others
                session.rollback()
                logger.exception("Webhook registration failed for user %s", user.id)
