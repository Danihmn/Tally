"""Unit tests. No database, no Pluggy, no network.

`settings.Settings()` and the Fernet in `infra.security.encryption` are built at import time, so
fake values are set here, before any project module is imported. Env vars win over the `.env` file,
so a real `.env` is never used by the tests. The engine is lazy: the fake DATABASE_URL is never
reached (port 1), and a test that touches the database by mistake fails loudly.
"""

import logging
import os

from cryptography.fernet import Fernet

os.environ["DATABASE_URL"] = "postgresql+psycopg2://test:test@127.0.0.1:1/test"
os.environ["JWT_SECRET_KEY"] = "test-jwt-secret"
os.environ["JWT_ALGORITHM"] = "HS256"
os.environ["ACCESS_TOKEN_EXPIRE_MINUTES"] = "30"
os.environ["ENCRYPTION_KEY"] = Fernet.generate_key().decode()
# Unset: nothing in the tests registers webhooks
os.environ["PUBLIC_BASE_URL"] = ""

# The code logs expected failures (skipped items, rollbacks): keep the test output clean
logging.disable(logging.CRITICAL)
