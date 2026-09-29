"""Shared product catalog — store_chains, products, aliases, confirmations, enrichment, conflicts.

Revision ID: 0001_catalog
Revises: None
Create Date: 2026-09-29

Spec version: 1.0
Satisfies: REQ-RCP-007, REQ-RCP-009, REQ-RCP-010, REQ-RCP-011, REQ-RCP-013, REQ-RCP-014
Design: docs/design/gemini-receipt-parser.md §4 · ADR-008

The DDL lives in backend/catalog/migrations/0001_catalog.sql (and .down.sql) so
it can be reviewed, linted, and applied with plain psql as well as Alembic.
This revision executes those files verbatim inside Alembic's transaction.
"""

from __future__ import annotations

from pathlib import Path

from alembic import op

revision = "0001_catalog"
down_revision = None
branch_labels = None
depends_on = None

_MIGRATIONS_DIR = Path(__file__).resolve().parents[2] / "migrations"


def _sql(name: str) -> str:
    return (_MIGRATIONS_DIR / name).read_text(encoding="utf-8")


def upgrade() -> None:
    op.execute(_sql("0001_catalog.sql"))


def downgrade() -> None:
    op.execute(_sql("0001_catalog.down.sql"))
