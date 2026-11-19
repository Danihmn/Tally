# Tally — Backend

FastAPI backend of the personal finance app (bank reconciliation + AI). The project goal, stack and rules are in the root [`CLAUDE.md`](../CLAUDE.md).

## Prerequisites

- Python 3.14 (see `.python-version`)
- [uv](https://docs.astral.sh/uv/)
- PostgreSQL (13+, because of `gen_random_uuid()`)
- [ngrok](https://ngrok.com/) with an account and a static domain (needed to receive Pluggy's webhooks)

## Installation

```bash
cd backend
uv sync
```

## PostgreSQL

The project is **codebase first**: the source of truth is the SQLAlchemy models in `infra/database/models.py`. Schema changes are **Alembic** migrations in `alembic/versions/`. `alembic/env.py` reads `DATABASE_URL` from the `.env` (through `settings.py`), so `alembic.ini` has no url.

Create the database and the schema:

```bash
createdb finance_app
uv run alembic upgrade head
```

### Existing database (built by the old `sql_scripts/`)

Until November 2026 the schema was built by the SQL scripts `001..019` (database first). The migration `0001_baseline` creates exactly that schema (checked against a database built by the scripts: same columns, types, defaults, constraints and indexes). A database that already ran the scripts must **not** run the baseline. Mark it once, without changing anything:

```bash
uv run alembic stamp 0001
```

Then `uv run alembic upgrade head` as usual for the next migrations.

### Changing the schema

1. Change the models in `infra/database/models.py`.
2. Generate the migration (against a database that is up to date):

    ```bash
    uv run alembic revision --autogenerate -m "short description"
    ```

3. **Read the generated file** and fix it. Autogenerate does not see everything:
    - It does **not** compare `CHECK` constraints: add or drop them by hand (`op.create_check_constraint` / `op.drop_constraint`).
    - It does not detect renames (it writes a drop + add, which loses data): use `op.alter_column(..., new_column_name=...)`.
    - Data backfills (`UPDATE ...`) go in the migration with `op.execute(...)`, between adding a column as nullable and setting it `NOT NULL`.
    - Give every constraint and index an explicit `name`, the same in the model and in the migration.
4. Apply it: `uv run alembic upgrade head`. Check that `uv run alembic check` answers "No new upgrade operations detected".

Rules:

- Never edit a migration that was already applied. A new change is a new migration.
- Money columns use `Numeric`, never `Float`. In Python, `Decimal`.

### Tables that are not ours (LangGraph)

The LangGraph `PostgresSaver` (the Tally conversation history) creates `checkpoints`, `checkpoint_blobs`, `checkpoint_writes` and `checkpoint_migrations` in the same schema (`public`) when the app calls `setup()`. They must **never** appear in `models.py` or in a migration. `include_object` (`infra/database/alembic_filters.py`, list `IGNORED_TABLES`) makes autogenerate skip them, so it never writes a `drop_table` for them. If LangGraph adds a new table, add it to that list.

## Configuration (`.env`)

```bash
cp .env.example.dev .env   # local development
```

`.env.example.prod` is the template of the production server (it also has `POSTGRES_USER` and `POSTGRES_PASSWORD`, used by `compose.yaml`). Never commit real secrets in these files.

| Variable | Description |
|---|---|
| `DATABASE_URL` | Postgres connection, e.g. `postgresql+psycopg2://user:pass@localhost:5432/finance_app` |
| `JWT_SECRET_KEY` | JWT secret. Generate a new one, do not use the example's |
| `JWT_ALGORITHM` | E.g. `HS256` |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | Access token lifetime |
| `ENCRYPTION_KEY` | Fernet key that encrypts the Pluggy client secret |
| `PUBLIC_BASE_URL` | Public HTTPS URL Pluggy reaches the backend at (the ngrok one) |
| `CONVERSATION_TOKEN_LIMIT` | Optional, default `50000`. Size of a Tally AI conversation (tokens the model reads) at which it is full: the app warns at 80% and `POST /tally/chat` answers 409 `conversation_limit_reached` at 100%. Copied to each conversation when it is created |
| `BEDROCK_API_KEY` | Optional. Empty or unset: the AI agents use local Ollama (dev). Filled: they use the OpenAI model on AWS Bedrock (production) |
| `BEDROCK_BASE_URL` | OpenAI-compatible Bedrock endpoint. Required when `BEDROCK_API_KEY` is set |
| `BEDROCK_MODEL` | Bedrock model id. Required when `BEDROCK_API_KEY` is set |
| `OLLAMA_BASE_URL` / `OLLAMA_MODEL` | Optional. Default `http://localhost:11434` / `llama3.2:latest` |

Generate the `ENCRYPTION_KEY`:

```bash
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

If `PUBLIC_BASE_URL` is not set, the automatic webhook registration is skipped (a warning is logged).

## Running the API

From `backend/`:

```bash
uv run fastapi dev presentation/app.py
```

The API starts at `http://127.0.0.1:8000` and the interactive docs are at `http://127.0.0.1:8000/docs`.

## Running the tests

From `backend/`:

```bash
uv run python -m unittest discover -s tests -t .
```

Unit tests only (standard library `unittest`): no database, no Pluggy and no `.env` needed. The rules are in `CLAUDE.md` (section 6).

## Pluggy webhooks with ngrok

Pluggy tells us when an item is created, updated or deleted by calling a webhook. Since the API runs on your machine, ngrok exposes it publicly.

1. In the `.env`, set ngrok's static domain:

   ```
   PUBLIC_BASE_URL=https://<your-static-domain>.ngrok-free.dev
   ```

2. Start the API (previous section). It must be running before the tunnel.

3. In another terminal, open the tunnel:

   ```bash
   ngrok http http://127.0.0.1:8000 --url https://<your-static-domain>.ngrok-free.dev
   ```

How it works:

- At startup (and when a user is created), the backend registers (or fixes) three webhooks of every user in Pluggy, pointing to `PUBLIC_BASE_URL` + the route of each event (`jobs/webhook_registration.py`):

  | Event | Route | What the backend does |
  |---|---|---|
  | `item/created` | `/webhooks/pluggy/items/created` | Saves the item in `pluggy_items` for the user that owns the webhook, then syncs. |
  | `item/updated` | `/webhooks/pluggy/items/updated` | Syncs the user. An unknown item is saved first (covers a lost `item/created`). |
  | `item/deleted` | `/webhooks/pluggy/items/deleted` | Sets `pluggy_items.deleted_at`. Accounts and transactions stay, but the item leaves the sync. |

- Pluggy sends the `X-Webhook-Token` header with a per-user secret, shared by the three webhooks. Only its hash is stored in the database.
- To add a bank you do not touch the database: connect it in Pluggy (Dashboard, application's Demo page, Connect Account, MeuPluggy). Each bank connected in Meu Pluggy is authorized separately, so a bank added later also needs this step.
- The ngrok domain is static, so the URL does not change between runs. If you change the domain, update `PUBLIC_BASE_URL` and restart the API to register the webhook again.
- The tunnel must be open when Pluggy updates the data. With it closed, ngrok answers `404 ERR_NGROK_3200` and Pluggy gives up after a few attempts.
- ngrok's inspector, with the received requests, is at `http://127.0.0.1:4040`.

## Deployment: AWS Lightsail

**Status:** in production.

**Why Lightsail:**

- Low management complexity: a fixed-plan virtual server, without the IAM / VPC / ECS setup of the larger AWS services.
- Low and predictable cost, which fits a private app used by two people.

**Current shape:**

- One Lightsail instance (Ubuntu), reached by SSH, running Docker Compose in `/home/ubuntu/app` (`compose.yaml`).
- Three services: `db` (PostgreSQL 17 on the same instance, volume `pgdata`), `api` (image `ghcr.io/danihmn/tally:latest`, gunicorn + uvicorn worker) and `caddy` (reverse proxy with automatic HTTPS, `Caddyfile`).
- The secrets are in a `.env` file on the server, next to `compose.yaml` (template: `.env.example.prod`). They are not in the repository.
- The AI uses a model on AWS Bedrock (`BEDROCK_*` variables).

**How a deploy works** (`.github/workflows/deploy.yml`, on every push to `main`):

1. Build the image from `backend/` and push it to GitHub Container Registry (`latest` and the commit sha).
2. Copy `compose.yaml` and `Caddyfile` to the server by SSH.
3. On the server: `docker compose pull api`, `docker compose run --rm api alembic upgrade head` (migrations), `docker compose up -d`, `docker image prune -f`.

GitHub secrets used: `SSH_HOST`, `SSH_USER`, `SSH_KEY`. The same workflow also builds and distributes the mobile app (see `mobile/README.md` and the root `README.md`).

**Single worker (required for now):**

- The API runs with **one worker, one process** (the Dockerfile's `gunicorn` has no `--workers`, so it uses the default of 1; no `--reload` in production). One instance only: no auto-scaling, no second instance behind a load balancer.
- Why: the webhook registration (`register_webhooks`, called in the app's `lifespan`) runs at the startup of every process. It reads the webhooks in Pluggy, and if the secret does not match the stored hash it rotates it: new secret in Pluggy first, then its hash in the database. Two processes starting together can do this at the same time. Pluggy then keeps one secret and the database the hash of the other, and every webhook gets a 401 until the next restart.
- **If more than one worker is ever needed, or AWS auto-scaling is turned on, first implement a lock in the webhook registration** (`jobs/webhook_registration.py`). Use a PostgreSQL advisory lock around the whole loop of users and `ensure_item_webhooks`, on the same session (connection), released in a `finally`:

```python
from sqlalchemy import text

_WEBHOOK_LOCK_ID = 7_301_001  # arbitrary number, the same in every process

with get_session() as session:
    session.execute(text("SELECT pg_advisory_lock(:id)"), {"id": _WEBHOOK_LOCK_ID})
    try:
        ...  # the loop of users and ensure_item_webhooks
    finally:
        session.execute(text("SELECT pg_advisory_unlock(:id)"), {"id": _WEBHOOK_LOCK_ID})
```

- Notes: the lock belongs to the database connection, so lock and unlock must use the same session. `pg_advisory_xact_lock` does not fit, because the job commits once per user and the lock would be released at the first commit. `pg_try_advisory_lock` (skip the registration when another process holds the lock) is an option, since the other process is already doing the work.

**Effect on the project:**

- The static public domain replaces ngrok in production: `PUBLIC_BASE_URL` becomes that domain, and the webhook registration (`jobs/webhook_registration.py`) uses it as it does today.
- ngrok stays only for local development.

**Domain and Cloudflare:**

- The API domain (`api.tally-api.com`, see `Caddyfile`) goes through **Cloudflare**, which points to the Lightsail instance. Caddy serves HTTPS on the server.
- Cloudflare is set up in its dashboard, not in this repository (no code or compose change is needed for it).
- `PUBLIC_BASE_URL` is this domain. Pluggy's webhooks and the mobile app both reach the API through it.
- To confirm (the current settings are not documented yet):
  - [ ] DNS record: proxied (orange cloud) or DNS only (grey cloud).
  - [ ] SSL/TLS mode. If the record is proxied, use **Full (strict)**: Caddy has its own certificate, and *Flexible* mode can cause redirect loops.
  - [ ] If proxied: no Cloudflare rule (WAF, bot protection, rate limit) may block `POST /webhooks/pluggy/*`. Pluggy needs a `2XX` in 10 seconds.
  - [ ] If proxied: the client IP arrives in the `CF-Connecting-IP` header. The API does not read it today, so logs show Cloudflare's IP.

**Decided:** PostgreSQL on the instance (Compose), HTTPS with Caddy, the API runs in Docker, secrets in the server's `.env`.

**Open points:**

- [ ] Backups / snapshots of the `pgdata` volume. The transaction history must not be lost (see `CLAUDE.md`, section 5.4).
- [ ] Run the unit tests in CI before the deploy (today the workflow does not run them).

Prices and plan sizes are not written here because they change. Check the AWS pricing.

## Testing flow

1. Postgres running, with the migrations applied (`uv run alembic upgrade head`).
2. `.env` configured.
3. API up.
4. ngrok up.
5. Create a user and log in (`/docs`).
6. Connect a bank in Pluggy. The `item/created` webhook registers the item (`POST /pluggy-items` is only needed for items created while the API was down).
7. Wait for the `item/updated` webhook. Meu Pluggy refreshes every 24 hours and does not allow a manual refresh.

## Structure

| Folder | Content |
|---|---|
| `domain/` | Entities, read models, pure rules (reconciliation matching, internal transfers) |
| `infra/` | Database (session, models, Alembic filters), repositories (`common/`: errors and query helpers), security (`security/`: password hash, encryption, webhook secret, JWT) |
| `integrations/pluggy/` | Pluggy's HTTP clients, schemas and config |
| `jobs/` | Background flows that call the services (item registration, transaction import, reconciliation, webhook registration) |
| `presentation/` | FastAPI app, routers, schemas, webhooks, dependencies (`get_current_user`) |
| `services/` | Business rules (`common/`: service errors and entity mappers) |
| `alembic/` | Alembic migrations (`versions/`) and `env.py` |
| `tests/` | Unit tests, same folder structure as the source |
