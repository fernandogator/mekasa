# Shared product catalog — Cloud SQL for PostgreSQL

Spec version: 1.0 · Satisfies: REQ-RCP-007, REQ-RCP-009 … REQ-RCP-011,
REQ-RCP-013, REQ-RCP-014 · Decision: `docs/architecture.md` ADR-008 · Design:
`docs/design/gemini-receipt-parser.md` §4

The catalog is the one store that is **shared by every account**: products
keyed by UPC, their receipt aliases, provenance, confirmation counts, enrichment
state, and conflicts with verified entries. Household data (receipts, line items,
scan events, parse jobs, inventory) stays in Firestore; the two stores reference
each other only by opaque string ids (`matched_product_id`, `receipt_id`).

Status: **design + DDL (phase 1)**. No runtime code reads this database yet.

## Layout

| Path | Purpose |
|---|---|
| `migrations/0001_catalog.sql` | Source-of-truth DDL (tables, constraints, `pg_trgm` indexes, triggers) |
| `migrations/0001_catalog.down.sql` | Rollback |
| `seed/store_chains.sql` | Idempotent seed for `store_chains` |
| `alembic.ini`, `alembic/` | Alembic wrapper; revision `0001_catalog` executes the SQL files verbatim |

Tables: `store_chains`, `products`, `product_aliases`, `product_confirmations`,
`enrichment_jobs`, `enrichment_steps`, `product_conflicts`. Field-level notes are
comments in the DDL; the resolver/enrichment semantics are in the design doc.

## Local / CI

```bash
# any Postgres 16 with pg_trgm + unaccent (both ship in contrib / the official image)
docker run --rm -d --name mekasa-pg -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:16
export CATALOG_DATABASE_URL=postgresql+psycopg://postgres:postgres@localhost:5432/postgres

cd backend
alembic -c catalog/alembic.ini upgrade head
psql "postgresql://postgres:postgres@localhost:5432/postgres" -v ON_ERROR_STOP=1 \
  --single-transaction -f catalog/seed/store_chains.sql
alembic -c catalog/alembic.ini downgrade base     # rollback check
alembic -c catalog/alembic.ini upgrade head --sql # print DDL without a connection
```

Unit tests never need Postgres: repositories follow the existing Protocol
pattern with an in-memory implementation, selected by
`CATALOG_PERSISTENCE=memory|postgres|auto` (mirrors `HOUSEHOLD_PERSISTENCE`).
Phase 2 adds a CI job with `services: postgres:16` that applies the migration,
runs the seed, and executes the Postgres-backed repository tests.

## Cloud SQL (dev)

No database password exists anywhere. The Cloud Run runtime service account is
the database user via **IAM database authentication**; humans and CI run
migrations through the Cloud SQL Auth Proxy, which injects short-lived IAM
tokens.

```bash
gcloud config set project hackathon2025-472017

# 1. Instance (smallest shared-core tier; ~US$10/month, ZONAL, auto storage growth)
gcloud sql instances create mekasa-catalog-dev \
  --database-version=POSTGRES_16 --tier=db-f1-micro --region=us-central1 \
  --edition=ENTERPRISE --availability-type=ZONAL --storage-size=10GB --storage-auto-increase \
  --database-flags=cloudsql.iam_authentication=on \
  --backup-start-time=07:00 --retained-backups-count=7

gcloud sql databases create mekasa_catalog --instance=mekasa-catalog-dev

# 2. IAM database users (service account for the API; humans for migrations)
gcloud sql users create mekasa-api@hackathon2025-472017.iam \
  --instance=mekasa-catalog-dev --type=CLOUD_IAM_SERVICE_ACCOUNT
gcloud sql users create "$(gcloud config get-value account)" \
  --instance=mekasa-catalog-dev --type=CLOUD_IAM_USER      # the operator running migrations
gcloud projects add-iam-policy-binding hackathon2025-472017 \
  --member=serviceAccount:mekasa-api@hackathon2025-472017.iam.gserviceaccount.com \
  --role=roles/cloudsql.client
gcloud projects add-iam-policy-binding hackathon2025-472017 \
  --member=serviceAccount:mekasa-api@hackathon2025-472017.iam.gserviceaccount.com \
  --role=roles/cloudsql.instanceUser

# 3. Migrate through the proxy (operator's own IAM identity, no password)
cloud-sql-proxy --auto-iam-authn hackathon2025-472017:us-central1:mekasa-catalog-dev &
export CATALOG_DATABASE_URL="postgresql+psycopg://$(gcloud config get-value account | sed 's/\.gserviceaccount\.com$//')@127.0.0.1:5432/mekasa_catalog"
alembic -c catalog/alembic.ini upgrade head
psql "postgresql://$(gcloud config get-value account)@127.0.0.1:5432/mekasa_catalog" \
  -v ON_ERROR_STOP=1 --single-transaction -f catalog/seed/store_chains.sql

# 4. Grants for the runtime user (run once as the migrating identity)
psql "postgresql://$(gcloud config get-value account)@127.0.0.1:5432/mekasa_catalog" -c \
  'GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "mekasa-api@hackathon2025-472017.iam";
   ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "mekasa-api@hackathon2025-472017.iam";'
```

Runtime (phase 2) env on Cloud Run — names only, no secrets:

| Variable | Value |
|---|---|
| `CATALOG_PERSISTENCE` | `postgres` (`memory` in tests, `auto` = postgres when the instance name is set) |
| `CATALOG_INSTANCE_CONNECTION_NAME` | `hackathon2025-472017:us-central1:mekasa-catalog-dev` |
| `CATALOG_DB_NAME` | `mekasa_catalog` |
| `CATALOG_DB_IAM_USER` | `mekasa-api@hackathon2025-472017.iam` |

The API connects with `cloud-sql-python-connector[pg8000]`
(`enable_iam_auth=True`, ADC) behind a small SQLAlchemy pool (`pool_size=2`,
`max_overflow=3`, `pool_recycle=1800`), sized for Cloud Run instances that
scale to zero.

## Retention and rollback

- `enrichment_jobs.expires_at` (180 d) replaces the Firestore TTL: a Cloud
  Scheduler job runs `DELETE FROM enrichment_jobs WHERE expires_at < now()`
  daily (steps cascade). `product_conflicts` are kept until curated.
- `alembic downgrade base` drops every catalog object; Firestore documents keep
  their `matched_product_id` strings and simply stop resolving.
- Later schema changes: new `migrations/000N_*.sql` + `.down.sql` pair and an
  Alembic revision that executes them. Enumerations are `TEXT` + named `CHECK`
  constraints so a value can be added with `DROP CONSTRAINT` / `ADD CONSTRAINT`
  in one transaction.
