"""Alembic environment for the shared product catalog.

Satisfies: ADR-008 (Postgres catalog), NFR-004 (no secrets in code)
Spec version: 1.0

The only input is ``CATALOG_DATABASE_URL`` (a SQLAlchemy URL). It is never
stored in this repository:

* local / CI: ``postgresql+psycopg://postgres:postgres@localhost:5432/mekasa_catalog``
  (throwaway credentials for a throwaway server — see catalog/README.md).
* Cloud SQL: run the Cloud SQL Auth Proxy with ``--auto-iam-authn`` and point
  the URL at it with the IAM database user and **no password**, e.g.
  ``postgresql+psycopg://mekasa-api@hackathon2025-472017.iam@127.0.0.1:5432/mekasa_catalog``.
  The proxy injects a short-lived IAM token; no database password exists.

The runtime API (phase 2) does not use this file; it connects through the
Cloud SQL Python Connector with IAM authentication (ADR-008).

Migrations are offline-safe: ``alembic upgrade head --sql`` emits the DDL
without a connection.
"""

from __future__ import annotations

import os
from logging.config import fileConfig

from alembic import context
from sqlalchemy import create_engine, pool

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# DDL is hand-written SQL (backend/catalog/migrations/*.sql); no ORM metadata
# to autogenerate from.
target_metadata = None


def _database_url() -> str | None:
    return os.environ.get("CATALOG_DATABASE_URL") or None


def run_migrations_offline() -> None:
    context.configure(
        url=_database_url() or "postgresql+psycopg://",
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        version_table=config.get_main_option("version_table"),
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    url = _database_url()
    if not url:
        raise SystemExit(
            "CATALOG_DATABASE_URL is not set. Local/CI: a postgresql+psycopg URL to a "
            "throwaway server. Cloud SQL: start `cloud-sql-proxy --auto-iam-authn` and "
            "use the IAM database user with no password (see backend/catalog/README.md)."
        )

    engine = create_engine(url, poolclass=pool.NullPool)
    with engine.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            version_table=config.get_main_option("version_table"),
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
