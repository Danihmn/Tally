# Tally (Bank Reconciliation + AI)

## 1. Project goal

A personal finance app. It connects to our bank accounts, imports transactions, and uses AI to:

- Create the entries (lançamentos) automatically.
- Reconcile the bank transactions with the entries.
- Answer questions like "who spent how much?" (per person and per household).

Use case: private use by two people (two different CPFs). Not a public product for now.

## 2. Tech stack (decided)

| Layer | Choice |
|---|---|
| Backend | Python + FastAPI |
| AI | LangChain (LangGraph if agents are needed) |
| Database | PostgreSQL |
| Mobile app | Flutter |
| Bank data | Pluggy, free "Meu Pluggy" plan (Open Finance) |
| Hosting (planned, not final) | AWS Lightsail |

Hosting is **not decided yet**. AWS Lightsail is the likely choice because of low management complexity and low cost. It may change. Details and open points are in `backend/README.md` ("Deployment (planned)"). In production, the static public domain replaces ngrok as `PUBLIC_BASE_URL`.

Deployment constraint: the API runs with **one worker and one instance** (no auto-scaling). The webhook registration (`register_webhooks`, in the app's `lifespan`) rotates the webhook secret in Pluggy and then stores its hash, and two processes starting together can leave them out of sync (all webhooks return 401 until a restart). If more than one worker is needed, or AWS auto-scaling is turned on, **first** add a PostgreSQL advisory lock (`pg_advisory_lock`, same session, released in a `finally`) around the registration in `jobs/webhook_registration.py`. The code and the notes are in `backend/README.md` ("Deployment (planned)").

Pluggy code lives in `backend/integrations/pluggy/` (`http_clients/`, `schemas/`, `exceptions/`, `config.py`).

## 3. Database schema

The project is **database first**. The source of truth is the versioned SQL scripts in `backend/sql_scripts/`, numbered in order (`001_init.sql`, `002_...sql`). The SQLAlchemy models are generated from the database (with `sqlacodegen`), never written by hand.

- `backend/sql_scripts/`: **source of truth.** Read the scripts, in order, before writing queries or code that touches tables, or answering questions about tables and columns. A change to the schema is a new script. Do not edit a script that was already applied.
- Generated models: `backend/infra/database/models.py`. Do not edit them by hand, they are overwritten on each generation. Extra logic goes in separate modules. The session is in `backend/infra/database/session.py` and the settings in `backend/settings.py`.
- The database also has tables that are **not ours**: the LangGraph `PostgresSaver` (Tally conversation history) creates `checkpoints`, `checkpoint_blobs`, `checkpoint_writes` and `checkpoint_migrations` by itself, with `setup()`. They are **not** in `sql_scripts/`, and they must **never** go into `models.py`. When regenerating the models, `sqlacodegen` has no "exclude" option, so always pass `--tables` with **only the domain tables** (the ones created by `CREATE TABLE` in `sql_scripts/`), never run it over the whole database. The command is in `backend/README.md` ("Regenerating the models"). Do not write queries or repositories against the LangGraph tables: read the history through the checkpointer.
- There is no diagram or Markdown export of the schema anymore (the DrawSQL files were deleted). Do not recreate them.

The schema (tables, columns, relations, constraints) is defined only by the SQL scripts and the generated models. This file does not keep a summary of it, so it cannot go out of date. For questions about tables and columns, read `backend/sql_scripts/` (in order) and `backend/infra/database/models.py`.

Rules:
1. If the code and the scripts disagree, the scripts win. Tell me about the difference, and do not silently pick one.
2. When you suggest schema changes, write them as a new SQL script in `backend/sql_scripts/`.
3. Money columns use `numeric`, never `float`/`double precision`. In Python, use `Decimal`.

## 4. Pluggy documentation access (MCP): use it first

This project uses the **Pluggy Docs MCP server**. It gives live access to the official Pluggy docs: guides, API reference (OpenAPI), changelog, recipes, and support Q&A. No API key is needed.

Rules for the agent:
1. Before answering any question about Pluggy, or writing any code that calls the Pluggy API, **search the MCP first**. Do not rely on memory. The API and the dashboard can change.
2. Useful tools: `search_docs`, `get_guide`, `list_guides`, `search_endpoints`, `get_api_endpoint`, `search_changelog`, `search_qa`, `search_recipes`.
3. Key guides: `guides/meu-pluggy-personal-use`, `guides/dashboard-connectors`, `connections/consents`.
4. If the MCP is not available, read the public docs at https://docs.pluggy.ai (a full index is at `/llms.txt`) and tell me that the MCP was not used.
5. If the official docs disagree with this file, **the docs win**. Tell me, and suggest an update to this file.
6. Always say which guide or endpoint the answer came from.
7. For response shapes, trust the OpenAPI spec (`get_api_endpoint`), not the JSON `example` on the docs pages. Examples are often outdated and much smaller than the real response.

## 5. Bank integration

### 5.1 Why Pluggy
- Using Open Finance directly requires being an institution authorized by the Central Bank. Not possible for a personal project.
- The banks' developer APIs (statement, Pix, billing) are for business (PJ) accounts, with contracts and certificates.
- Pluggy is an aggregator: one integration model for all banks, for personal accounts.

### 5.2 How Meu Pluggy works (confirmed in the docs)
- Each person has their own Meu Pluggy account and their own Pluggy application (Client ID + Client Secret). Authenticate **per user** (`POST /auth` returns an `apiKey`).
- Banks are connected in the Meu Pluggy site. Connecting through the **MeuPluggy** connector in the Dashboard is one authorization, and each connected bank becomes one **item** (`itemId`).
- `GET /v2/items` is not available for Meu Pluggy accounts, so we store each `itemId` ourselves. Accounts and transactions are read per item (`/accounts?itemId=`, `/transactions?accountId=`).
- Personal use only, up to 5 connections. Meu Pluggy refreshes every 24 hours, and items cannot be refreshed manually.

### 5.3 Consent expiration
- The MeuPluggy authorization lasts **1 year**. The date is `consentExpiresAt` on `GET /items/{id}`. It applies to all of that user's items.
- After it expires, accounts and transactions return **empty**, and the next refresh fails with `LOGIN_ERROR` / `USER_AUTHORIZATION_EXPIRED` (webhook `item/error`). The item may still show `UPDATED` until then, so an empty read with a past `consentExpiresAt` means "expired", not "no data".
- Renewing means doing the MeuPluggy login again in the Dashboard. A refresh by API cannot renew it.
- The app must warn before the date.

### 5.4 Data we keep
- Re-authorizing can change the `itemId`. Our tables use our own UUID primary keys, and Pluggy ids are separate unique columns. Transactions are reconciled by our own ids, not by assuming the item id is stable.
- We store transactions locally: after the consent expires, the API returns nothing, and the AI features need the history.

## 6. Tests

Unit tests live in `backend/tests/`. They test the logic only: **no database, no Pluggy, no network**.

Rules for the agent:
1. **Every new feature, fix or adjustment comes with tests.** Create the tests if they don't exist, or update the existing ones. Then run the whole suite and make sure it passes before committing. Say in the answer which tests were added or changed, and the result of the run.
2. Use only the standard library: `unittest` and `unittest.mock`. For routers, `fastapi.testclient.TestClient` (it uses `httpx`, already a dependency). **Do not add test dependencies** (no pytest, pytest-mock, freezegun, respx...).
3. One test file per source module, in the same folder structure as the source: `services/x.py` → `tests/services/test_x.py`, `jobs/y.py` → `tests/jobs/test_y.py`. Every test folder has an `__init__.py`. Keep each file about its own module only, and group the tests in one `TestCase` class per function or behavior.
4. Patch names **where they are used**, not where they are defined (`patch("jobs.transaction_launcher.get_all_transactions")`). The `Session` is a `MagicMock`. A `get_session()` is replaced with `tests.factories.fake_get_session(session)`.
5. Shared builders go in `tests/factories.py` (`make_transaction`, `make_entry`, `make_user`...). Money uses `Decimal`. Dates are frozen by patching `date` / `datetime` in the module under test (see `tests/jobs/`).
6. `tests/__init__.py` sets fake env vars before any import (the settings and the Fernet key are built at import time). Do not read the real `.env` in tests.
7. Repositories (`infra/repositories/`) are SQL: they are out of the unit tests scope (they need a real Postgres, in a future integration suite). Do not mock the SQLAlchemy session to "test" a query.
8. Test names describe the behavior (`test_empty_answer_from_pluggy_deletes_nothing`), not the implementation.

Run from `backend/`:

```bash
uv run python -m unittest discover -s tests -t .
```

`main_test.py` is not a test: it runs the real sync job. The `test*.py` pattern does not collect it.

## 7. Endpoints used by the app

Every endpoint is built for the mobile app. The app lists the ones it uses in `mobile/lib/core/network/api_endpoints.dart` (`ApiEndpoints`: method, path, which feature uses it, and the `all` list).

Rules for the agent:
1. When you create an endpoint for the app, **add it to `ApiEndpoints` in the same change** (and to `all`). Then say so in the answer.
2. The backend cleanup removes the routes that are not in that list. The list is **not complete yet**: endpoints created before it (login, users, bank accounts, the transaction and entry lists, the chat, ...) are still to be marked. Do not delete a route because it is missing from the list until the user says the list is complete.
3. Flutter may not be installed where you run. If you could not run `flutter analyze` and `flutter test`, say so.
