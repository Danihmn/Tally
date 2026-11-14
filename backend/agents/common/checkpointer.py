from functools import cache

from langgraph.checkpoint.postgres import PostgresSaver
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

from settings import settings


@cache
def get_checkpointer() -> PostgresSaver:
    url = settings.database_url.replace("+psycopg2", "")
    pool = ConnectionPool(
        url,
        max_size=5,
        kwargs={"autocommit": True, "row_factory": dict_row},
    )
    return PostgresSaver(pool)  # type: ignore
