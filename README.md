# Tally

Personal finance app for a household (two people, two CPFs). It connects to our bank accounts, imports the transactions and uses AI to:

- create the entries (*lançamentos*) automatically;
- reconcile the bank transactions with the entries;
- answer questions like "who spent how much?" (per person and per household).

Private use for now. It is not a public product.

## Architecture

```
 Flutter app ──HTTPS──► Caddy ──► FastAPI (API) ──► PostgreSQL
 (Firebase App                       ▲   │
  Distribution)                      │   └──► AI agents (LangChain / LangGraph)
                                     │            ├─ dev:  Ollama (local)
 Pluggy (Meu Pluggy / Open Finance)  │            └─ prod: OpenAI model on AWS Bedrock
        └── webhooks (item/*) ───────┘
```

## Stack

| Layer | Choice |
|---|---|
| Backend | Python 3.14, FastAPI, gunicorn + uvicorn worker |
| Database | PostgreSQL 17, SQLAlchemy 2, Alembic (codebase first) |
| AI | LangChain, LangGraph (`PostgresSaver` keeps the chat history), Ollama (dev), AWS Bedrock (prod) |
| Bank data | Pluggy, free "Meu Pluggy" plan (Open Finance) |
| Security | JWT, Argon2 password hash, Fernet encryption for the Pluggy client secret |
| Mobile | Flutter (Dart 3.14), Dio, Provider, get_it, go_router |
| Infra | Docker, Docker Compose, Caddy (HTTPS), GitHub Actions, GitHub Container Registry |
| Hosting | **AWS** (backend), **Firebase App Distribution** (mobile) |

## Repository layout

| Folder | Content |
|---|---|
| `backend/` | FastAPI API, jobs, AI agents, migrations, unit tests. See [`backend/README.md`](backend/README.md) |
| `mobile/` | Flutter app. See [`mobile/README.md`](mobile/README.md) and [`mobile/docs/ARCHITECTURE.md`](mobile/docs/ARCHITECTURE.md) |
| `.github/workflows/deploy.yml` | CI/CD: deploys the backend and distributes the app |
| `CLAUDE.md` | Project rules and decisions (stack, schema, Pluggy, tests) |

## Setup

### Backend

Needs: Python 3.14, [uv](https://docs.astral.sh/uv/), PostgreSQL 13+, and [ngrok](https://ngrok.com/) (to receive Pluggy webhooks on your machine).

```bash
cd backend
uv sync
createdb finance_app
cp .env.example.dev .env   # then fill the values
uv run alembic upgrade head
uv run fastapi dev presentation/app.py
```

The API runs at `http://127.0.0.1:8000`. Docs: `http://127.0.0.1:8000/docs`.

Main `.env` variables:

| Variable | Description |
|---|---|
| `DATABASE_URL` | Postgres connection |
| `JWT_SECRET_KEY`, `JWT_ALGORITHM`, `ACCESS_TOKEN_EXPIRE_MINUTES` | Login tokens |
| `ENCRYPTION_KEY` | Fernet key (encrypts the Pluggy client secret) |
| `PUBLIC_BASE_URL` | Public HTTPS URL that Pluggy calls (ngrok in dev, the domain in prod) |
| `BEDROCK_API_KEY`, `BEDROCK_BASE_URL`, `BEDROCK_MODEL` | Empty key = local Ollama. Filled = Bedrock |
| `OLLAMA_BASE_URL`, `OLLAMA_MODEL` | Optional, local model |
| `CONVERSATION_TOKEN_LIMIT` | Optional. Size limit of one AI conversation |

Generate the `ENCRYPTION_KEY`:

```bash
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

Open the tunnel for the webhooks (after the API is running):

```bash
ngrok http http://127.0.0.1:8000 --url <your-static-domain>
```

Tests (no database, no Pluggy, no network):

```bash
cd backend
uv run python -m unittest discover -s tests -t .
```

The database steps (existing database, schema changes) are in [`backend/README.md`](backend/README.md).

### Mobile

The API address comes from `--dart-define`. It is never hardcoded.

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000   # Android emulator
flutter analyze
flutter test
```

In production, `https` is required (`--dart-define=ENVIRONMENT=prod`).

### Connect a bank

1. Log in (`POST /auth/login`, or `/docs`). New users are created with `POST /users`, which needs a logged-in user. The new user joins the household of the creator.
2. Save the user's Pluggy credentials (`PUT /users/{id}/pluggy-credentials`).
3. In the Pluggy Dashboard, connect the bank with the **MeuPluggy** connector.
4. The `item/created` webhook saves the item and starts the first sync.

## Business rules

### Pluggy and Meu Pluggy

- Each person has their own Pluggy application. We authenticate **per user**.
- `GET /v2/items` is not available for Meu Pluggy, so we store each `itemId` ourselves.
- Meu Pluggy refreshes every 24 hours. Items cannot be refreshed manually.
- Re-authorizing can change the `itemId`. Our tables use our own UUIDs. Pluggy ids are separate unique columns.
- We keep the transactions in our database. After the consent expires, Pluggy returns nothing, and the AI needs the history.

### Webhooks

Pluggy calls the API when an item changes. The backend registers 3 webhooks per user at startup (`jobs/webhook_registration.py`), pointing to `PUBLIC_BASE_URL`.

| Event | Route | What the backend does |
|---|---|---|
| `item/created` | `/webhooks/pluggy/items/created` | Saves the item and its consent date, then runs the first sync |
| `item/updated` | `/webhooks/pluggy/items/updated` | Syncs the user. An unknown item is saved first (covers a lost `item/created`) |
| `item/deleted` | `/webhooks/pluggy/items/deleted` | Sets `deleted_at` on the item. Accounts and transactions stay, but the item leaves the sync |

- Pluggy sends the `X-Webhook-Token` header with a per-user secret. Only its hash is stored. A wrong or missing token returns `401`.
- An item that belongs to another user returns `404`.
- The answer is `202`. The real work runs in the background, because Pluggy needs a `2XX` in 10 seconds.
- At startup, if the secret in Pluggy does not match the stored hash, the backend rotates it (new secret in Pluggy first, then the hash in the database).

### Jobs

There is no scheduler. The jobs run after a webhook, and each one opens its own database session. One user failing never stops the others.

1. **Item registration** (`jobs/item_registration.py`): stores the item (if missing) with its `consentExpiresAt`, then starts the first sync.
2. **Transaction sync** (`jobs/transaction_launcher.py`): for each item and each account (BANK and CREDIT), imports the last 6 months (starting at D-1, as Pluggy recommends) and follows Pluggy's pagination. If a page cursor does not advance, the account is skipped. A partial list would mark transactions as deleted. After the commit, it runs the two jobs below.
3. **Reconciliation** (`jobs/reconciliation_registration.py`): looks at the last 2 months. It pairs a `PLANNED` entry with a `POSTED` transaction **only when the match is unambiguous**:
   - same amount and currency;
   - same direction (expense = debit, revenue = credit);
   - same bank account (when the entry has one);
   - date within 3 days of the due date (or the same month, if there is no due date);
   - exactly one candidate on each side.

   The pair is saved in `reconciliations` (source `AUTO`) and the entry becomes `RECONCILED`. Everything else stays `PLANNED`, for the AI agent.
4. **Internal transfers** (`jobs/transaction_internal_transfers_classification.py`): marks the transfers between the accounts of the household, so they do not count as spending. Two signals: the documents (CPF) in the transaction data, then the pairing by amount, date and accounts. A transfer the person sent to themself from a salary account (`outgoing_transfers_are_income`) is income, not a transfer. `AUTO` marks can be redone. `MANUAL` marks stay.

### Consent expiration

- The MeuPluggy authorization lasts **1 year** (`consentExpiresAt`). It applies to all items of that user.
- After it expires, accounts and transactions come back empty. An empty answer with a past date means "expired", not "no data".
- Renewing means doing the MeuPluggy login again. The app must warn before the date.

### Data rules

- Money uses `Numeric` in the database and `Decimal` in Python. Never `Float`.
- A schema change is a new Alembic migration. A migration that was applied is never edited.
- The LangGraph tables (`checkpoints`, ...) are not ours. They never go into the models or migrations.

## Deployment

### Backend on AWS

The backend runs on an **AWS** server with Docker Compose (`backend/compose.yaml`):

| Service | What it is |
|---|---|
| `db` | PostgreSQL 17 (volume `pgdata`) |
| `api` | Image `ghcr.io/danihmn/tally:latest` (gunicorn + uvicorn) |
| `caddy` | Reverse proxy with automatic HTTPS (`backend/Caddyfile`) |

On every push to `main`, GitHub Actions (`.github/workflows/deploy.yml`):

1. builds the Docker image and pushes it to GitHub Container Registry;
2. copies `compose.yaml` and `Caddyfile` to the server by SSH;
3. runs `alembic upgrade head`;
4. runs `docker compose up -d`.

The AI uses a model on **AWS Bedrock** in production.

**Single worker, single instance.** Do not use more than one worker or auto-scaling. Two processes starting together can rotate the webhook secret at the same time, and every webhook would return `401` until a restart. If this is ever needed, add a PostgreSQL advisory lock in `jobs/webhook_registration.py` first (details in [`backend/README.md`](backend/README.md)).

### Mobile on Firebase

After the backend deploy, the same workflow builds the release APK (`API_BASE_URL` and `ENVIRONMENT=prod`) and sends it with **Firebase App Distribution** to the `tally_users` group. Firebase is used only to distribute the app.

Secrets needed in GitHub: `SSH_HOST`, `SSH_USER`, `SSH_KEY`, `API_BASE_URL`, `FIREBASE_APP_ID`, `GOOGLE_APPLICATION_CREDENTIALS_JSON`.

## More docs

- [`CLAUDE.md`](CLAUDE.md): decisions and rules of the project
- [`backend/README.md`](backend/README.md): database, Alembic, ngrok, deployment notes
- [`mobile/README.md`](mobile/README.md) and [`mobile/docs/`](mobile/docs/): app architecture and backend gaps
