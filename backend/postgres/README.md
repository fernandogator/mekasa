# Shared product catalog — Cloud SQL for PostgreSQL

Spec version: 1.0 · Satisfies: REQ-RCP-007, REQ-RCP-009 … REQ-RCP-011,
REQ-RCP-013, REQ-RCP-014, REQ-RCP-019 … REQ-RCP-021 · Decision: `docs/architecture.md` ADR-008 · Design:
`docs/design/gemini-receipt-parser.md` §4

Data **shared across all accounts** lives here: `store_chains`, `products`
(keyed by UPC), `product_aliases`, `product_confirmations`, `product_conflicts`,
`enrichment_jobs`/`enrichment_steps`. Household-scoped data (receipts, line
items, scan events, `llm_parse_jobs`, inventory, purchases, members) stays in
Firestore. The two stores reference each other only by plain string ids
(`line_items.matched_product_id`, `inventory_items.product_id` →
`products.product_id`); there is no foreign key across stores. No table holds a
raw household or user id (NFR-002 AC1) — households appear only as
`household_hash = SHA-256(household_id + server salt)`.

Status: **DDL + runtime repository (phase 2, in progress)**. `backend/app/catalog_repository.py` reads and writes these tables when `DATABASE_URL` is set (in-memory twin otherwise); `tests/backend/test_catalog_repository.py` runs the same assertions against both backends (Postgres via `TEST_DATABASE_URL`, CI `postgres:16` service).

## Layout

| Path | Purpose |
|---|---|
| `migrations/0001_shared_products.sql` | Idempotent DDL (`IF NOT EXISTS` / `OR REPLACE`): tables, `CHECK`s, foreign keys, partial unique index on `upc`, `pg_trgm` GIN indexes, `updated_at` triggers, `catalog_normalize_name()` |
| `migrations/0001_shared_products.down.sql` | Rollback (drops every catalog object) |
| `migrations/0002_product_corrections.sql` | User corrections / in-store capture / product photos (design §3.11): `products.image_source` + pairing `CHECK`, partial index on user-photo images, `product_conflicts.field` gains `image_url`, `enrichment_jobs.trigger` gains `user_capture` and `image_removed` |
| `migrations/0002_product_corrections.down.sql` | Rollback of 0002 (deletes rows only 0002 made legal, restores 0001 `CHECK`s) |
| `migrations/0003_retire_store_catalog_prototype.sql` | Drops the pre-ADR-008 prototype tables (`stores`, `store_items`, `store_item_codes`, `photos`, `household_latest_receipts`) that `backend/app/store_catalog.sql` used to create at API startup (PR #106). Run once against `mekasa-pg` |
| `migrations/0003_retire_store_catalog_prototype.down.sql` | Recreates the prototype tables empty (data is not restored) |
| `seed/store_chains.sql` | Idempotent seed for `store_chains` |

Migrations are plain SQL applied with `psql`; later changes are new numbered
`000N_*.sql` / `.down.sql` pairs. Enumerations are `TEXT` + named `CHECK`
constraints so a value can be added with `DROP CONSTRAINT` / `ADD CONSTRAINT`
in one transaction.

## Local

```bash
# any Postgres 16 with pg_trgm + unaccent (both ship in contrib / the official image)
docker run --rm -d --name mekasa-pg -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:16
export DATABASE_URL=postgresql://postgres:postgres@localhost:5432/postgres   # throwaway local creds

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/postgres/migrations/0001_shared_products.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/postgres/migrations/0001_shared_products.sql  # idempotent
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 --single-transaction -f backend/postgres/seed/store_chains.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/postgres/migrations/0001_shared_products.down.sql  # rollback
```

## Tests

- Unit tests never need Postgres: `products_repository` follows the existing
  Protocol pattern with an in-memory implementation, used whenever
  `DATABASE_URL` is unset.
- Postgres-backed tests (`tests/backend/test_products_repository_postgres.py`,
  phase 2) run only when `TEST_DATABASE_URL` points at a scratch database and
  are skipped otherwise. They apply `0001_shared_products.sql` + the seed, then
  exercise the constraints (unique UPC, alias PK, once-per-household
  confirmation, verified-requires-evidence, one live enrichment job per
  product), trigram search, and the re-key transaction.
- CI (phase 2) adds `services: postgres:16` to `test-backend` and sets
  `TEST_DATABASE_URL`.

## Cloud SQL

Instance `mekasa-pg` (Postgres 16, `us-central1`), database `mekasa`, user
`mekasa_api`. Cloud Run connects over the Cloud SQL **Unix socket**; the
connection string is the Secret Manager secret `mekasa-database-url`, injected
as `DATABASE_URL`. Only the secret's *name* appears in code and config.

```bash
gcloud config set project hackathon2025-472017

# 1. Instance + database + user (smallest shared-core tier, ZONAL, auto storage growth)
gcloud sql instances create mekasa-pg \
  --database-version=POSTGRES_16 --tier=db-f1-micro --region=us-central1 \
  --edition=ENTERPRISE --availability-type=ZONAL --storage-size=10GB --storage-auto-increase \
  --backup-start-time=07:00 --retained-backups-count=7
gcloud sql databases create mekasa --instance=mekasa-pg
gcloud sql users create mekasa_api --instance=mekasa-pg --password="$(openssl rand -base64 32)"  # value goes to step 2 only

# 2. Connection string → Secret Manager (never into files, env in CI, or chat)
printf 'postgresql://mekasa_api:%s@/mekasa?host=/cloudsql/hackathon2025-472017:us-central1:mekasa-pg' "$PASSWORD" \
  | gcloud secrets create mekasa-database-url --data-file=-

# 3. Runtime service account roles
SA=mekasa-api@hackathon2025-472017.iam.gserviceaccount.com
gcloud projects add-iam-policy-binding hackathon2025-472017 --member=serviceAccount:$SA --role=roles/cloudsql.client
gcloud secrets add-iam-policy-binding mekasa-database-url --member=serviceAccount:$SA --role=roles/secretmanager.secretAccessor

# 4. Cloud Run: mount the socket and the secret (added to scripts/deploy-cloud-run.sh in phase 2)
gcloud run services update mekasa-api --region=us-central1 \
  --add-cloudsql-instances=hackathon2025-472017:us-central1:mekasa-pg \
  --update-secrets=DATABASE_URL=mekasa-database-url:latest

# 5. Migrate (operator; Cloud SQL Auth Proxy gives the same socket path locally)
cloud-sql-proxy --unix-socket /cloudsql hackathon2025-472017:us-central1:mekasa-pg &
export DATABASE_URL="$(gcloud secrets versions access latest --secret=mekasa-database-url)"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/postgres/migrations/0001_shared_products.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 --single-transaction -f backend/postgres/seed/store_chains.sql
unset DATABASE_URL
```

The salt for `household_hash` is a second secret, `mekasa-catalog-salt` (random 32 bytes, hex), injected as `CATALOG_HOUSEHOLD_SALT` (REQ-RCP-009 AC5). `provision-cloud-sql.sh` creates it once; never rotate it, because every stored hash would stop matching its household.

`mekasa_api` owns the objects it creates, so no separate grant step is needed.
Optional hardening later: IAM database authentication
(`cloudsql.iam_authentication=on`, user type `CLOUD_IAM_SERVICE_ACCOUNT`)
removes the password from the secret entirely; the socket path and driver stay
the same.

## Runtime (phase 2)

Driver `psycopg` 3 with `psycopg_pool.ConnectionPool` (`min_size=1`,
`max_size=4`, `max_idle=300`), one pool per Cloud Run instance, created lazily
on first catalog access so instances that only serve household routes never
open a connection. `DATABASE_URL` unset → `InMemoryProductsRepository`.

| Env | Value |
|---|---|
| `DATABASE_URL` | from secret `mekasa-database-url`; `postgresql://mekasa_api:…@/mekasa?host=/cloudsql/hackathon2025-472017:us-central1:mekasa-pg` |
| `TEST_DATABASE_URL` | scratch database for Postgres tests; unset → skipped |

## Retention and rollback

- `enrichment_jobs.expires_at` (180 d): a Cloud Scheduler job runs
  `DELETE FROM enrichment_jobs WHERE expires_at < now()` daily (steps cascade).
  `product_conflicts` are kept until curated; `products` are never expired.
  (`llm_parse_jobs` retention stays a Firestore TTL — REQ-RCP-018.)
- `0001_shared_products.down.sql` drops every catalog object; Firestore
  documents keep their `matched_product_id` strings and simply stop resolving.
