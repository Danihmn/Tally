from logging.config import fileConfig

from sqlalchemy import create_engine, pool

from alembic import context
from infra.database.alembic_filters import include_object
from infra.database.models import Base
from settings import settings

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# models.py is the source of truth of the schema (codebase first)
target_metadata = Base.metadata

CONTEXT_OPTIONS = {
    "target_metadata": target_metadata,
    "compare_type": True,
    "compare_server_default": True,
    # Skips the tables that are not ours (LangGraph checkpointer)
    "include_object": include_object,
}


def run_migrations_offline() -> None:
    """Writes the SQL to the output instead of running it (alembic upgrade head --sql)"""
    context.configure(
        url=settings.database_url,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        **CONTEXT_OPTIONS,
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = create_engine(settings.database_url, poolclass=pool.NullPool)

    with connectable.connect() as connection:
        context.configure(connection=connection, **CONTEXT_OPTIONS)

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
