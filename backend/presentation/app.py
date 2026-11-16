from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.concurrency import run_in_threadpool

from agents.common.checkpointer import get_checkpointer
from jobs.webhook_registration import register_webhooks
from presentation.exception_handlers import register_exception_handlers
from presentation.routers import (
    auth_router,
    bank_accounts_router,
    financial_entries_router,
    pluggy_items_router,
    reconciliations_router,
    recurrences_router,
    tally_router,
    transactions_router,
    users_router,
)
from presentation.webhooks.pluggy import item_webhooks


@asynccontextmanager
async def lifespan(app: FastAPI):
    await run_in_threadpool(register_webhooks)
    get_checkpointer().setup()  # Setups the LangGraph checkpointer with the database
    yield


app = FastAPI(title="Tally - Personal Financial Assistant", lifespan=lifespan)

register_exception_handlers(app)

app.include_router(auth_router.router)
app.include_router(users_router.router)
app.include_router(pluggy_items_router.router)
app.include_router(bank_accounts_router.router)
app.include_router(transactions_router.router)
app.include_router(financial_entries_router.router)
app.include_router(reconciliations_router.router)
app.include_router(recurrences_router.router)
app.include_router(tally_router.router)
app.include_router(item_webhooks.router)
