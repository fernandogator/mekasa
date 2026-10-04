# Mekasa API

Python FastAPI service for Cloud Run. Covers:

- Firebase Auth JWT verification (`Authorization: Bearer <idToken>`)
- Create / fetch household (`REQ-001`, `REQ-002`)
- Confirm home address (`REQ-003`)
- Nearby store list + selection (`REQ-003`; Google Places when `GOOGLE_PLACES_API_KEY` is set, else stub)
- Receipt OCR scan (`REQ-005`; Cloud Vision when available, stub/text fallback)
- Household photo upload (`REQ-002`)
- Household invites / members / roles (`REQ-019`)
- Trash consume-by-barcode with unknown-scan logging (`REQ-008`)
- Household **inventory CRUD + consume** (`REQ-004`–`REQ-009` persistence slice)
- Household **shopping list** CRUD + low-stock sync (`REQ-011`–`REQ-014`)
- **Purchase events + spending reports** (`REQ-015`, `REQ-017`, `REQ-018`)
- Durable **members/invites** (Firestore when prod) + member ACL on inventory/shopping
- **Barcode / UPC lookup** via the Open Food Facts family (`REQ-004`): UPC-E is expanded to UPC-A, UPC-A/EAN-13 shapes are unified, Open Products / Beauty / Pet Food Facts are consulted when OFF has no record, hits and misses are cached in-process, and an upstream outage answers `503` instead of `found: false`
- **Health grade + member avoidances** — Nutri-Score / NOVA / additives → A–E grade; per-member allergen list with scan-time warnings (`REQ-021`, `app/product_health.py`)
- **Device tokens + invite push hooks** (FCM best-effort; PRD §8 scaffold)

## Local run

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export ALLOW_TEST_AUTH=true
export ENVIRONMENT=local
uvicorn app.main:app --reload --port 8080
```

OpenAPI docs: http://localhost:8080/docs

### Test auth (local only)

```bash
curl -s http://localhost:8080/health
curl -s -H 'Authorization: Bearer test:demo' http://localhost:8080/v1/me
```

### Unit tests

```bash
cd backend
PYTHONPATH=. ALLOW_TEST_AUTH=true pytest ../tests/backend -q
```

The shared-catalog tests also run against a real Postgres when
`TEST_DATABASE_URL` points at a scratch database (CI does this with a
`postgres:16` service); they apply `backend/postgres` migrations first and
`TRUNCATE` between tests, so never point it at a real instance:

```bash
TEST_DATABASE_URL=postgresql://postgres@localhost:5432/mekasa_test \
  PYTHONPATH=. pytest ../tests/backend/test_catalog_repository.py -q
```

## Endpoints

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/health` | no | Liveness |
| GET | `/v1/me` | yes | Caller profile from token |
| POST | `/v1/households` | yes | Create household |
| GET | `/v1/households/current` | yes | Current user's household |
| PUT | `/v1/households/{id}/address` | yes | Confirm address |
| PUT | `/v1/households/{id}/name` | yes | Update household display name (REQ-002) |
| GET | `/v1/households/{id}/stores/nearby` | yes | Stub/Places nearby stores |
| PUT | `/v1/households/{id}/stores` | yes | Persist selected store ids |
| GET | `/v1/households/{id}/inventory` | yes | List inventory items |
| POST | `/v1/households/{id}/inventory` | yes | Create or merge item |
| GET | `/v1/households/{id}/inventory/{item_id}` | yes | Get one item |
| PATCH | `/v1/households/{id}/inventory/{item_id}` | yes | Update item fields |
| POST | `/v1/households/{id}/inventory/{item_id}/refresh-image` | yes | Fill missing `image_url` via OFF / category placeholder |
| POST | `…/inventory/{item_id}/restore` | yes | Undo soft-delete (REQ-INV-017) |
| POST | `…/inventory/{item_id}/purge` | yes | Hard-delete after undo window (REQ-INV-018) |
| DELETE | `/v1/households/{id}/inventory/{item_id}` | yes | Soft-delete item (REQ-INV-016) |
| POST | `/v1/households/{id}/inventory/{item_id}/consume` | yes | Decrement quantity |
| POST | `/v1/households/{id}/inventory/consume-by-barcode` | yes | Decrement by barcode (unknown → logged event) |
| GET | `/v1/households/{id}/trash-scans/unknown` | yes | Owner: unknown trash scans |
| GET | `/v1/households/{id}/shopping-list` | yes | List shopping list rows |
| POST | `/v1/households/{id}/shopping-list` | yes | Create or merge open row |
| GET/PATCH/DELETE | `/v1/households/{id}/shopping-list/{item_id}` | yes | Read / update / delete |
| POST | `…/shopping-list/{item_id}/approve` | yes | Approve pending request |
| POST | `…/shopping-list/{item_id}/reject` | yes | Reject pending request |
| POST | `…/shopping-list/sync-from-inventory` | yes | Auto-add low-stock items |
| POST | `/v1/households/{id}/purchases` | yes | Record purchase / price-paid event (REQ-015) |
| GET | `/v1/households/{id}/spending` | yes | Spending report `?period=week\|month\|year&category=` |
| PATCH | `/v1/households/{id}/purchases/{event_id}` | yes | Recategorize / edit purchase (REQ-017) |
| POST | `/v1/households/{id}/receipts/scan` | yes | Receipt OCR + catalog enrich (`image_url`, `identified`) |
| POST | `/v1/households/{id}/photo` | yes | Household photo (data-URL thin path) |
| POST | `/v1/households/{id}/item-photos` | yes | Upload a household-private item photo → `{photo_id, url}`; JPEG re-encode, metadata stripped, stored in `ITEM_PHOTO_BUCKET` (REQ-INV-019) |
| GET/DELETE | `/v1/households/{id}/item-photos/{photo_id}` | yes (member) | Fetch (`Cache-Control: private`) / delete a private photo (REQ-INV-019) |
| POST | `/v1/households/{id}/product-photos` | yes (member) | Upload a shared product photo for the capture flow (multipart `file` or JSON `image_base64`) → `{photo_id, image_url, width, height, bytes, created_at, expires_at}`; stored in `PRODUCT_PHOTO_BUCKET` at `product-photos/{photo_id}.jpg` (REQ-RCP-021) |
| DELETE | `/v1/households/{id}/product-photos/{photo_id}` | yes (uploading household) | Delete the photo; catalog products using it lose the image (REQ-RCP-021 AC5) |
| GET | `/v1/product-photos/{photo_id}` | yes (any user) | 302 to a 15-minute signed URL (Cloud Storage) or the bytes (local) (REQ-RCP-021 AC3) |
| POST | `/v1/households/{id}/inventory/{item_id}/capture` | yes (member) | Product capture from inventory: exactly one of `upc` / `plu_code` + optional `photo_id` (from `product-photos`), `name`, `category`; links or creates the shared product, sets the item's `barcode` (UPC only), `product_id`, `image_url`, writes a `scan_events` entry (REQ-RCP-020 AC6/AC7) |
| GET/POST | `/v1/households/{id}/members` / invites | yes | Family members + invites (REQ-019) |
| POST | `/v1/invites/accept` | yes | Accept invite token |
| GET | `/v1/barcode/{code}?household_id=` | yes | Open Food Facts family UPC lookup (`found` false if unknown; `503` when the databases are unreachable so the client can retry); `source` names the database that answered; includes `health` grade data and, when scoped to a household, member `warnings` (REQ-021) |
| POST | `/v1/households/{id}/inventory/{item_id}/refresh-health` | yes | Backfill `health` for a barcoded row that has none (REQ-021 AC4) |
| GET | `/v1/health/avoidances` | yes | Catalog of allergens / additives a member can avoid (REQ-021) |
| PUT | `/v1/households/{id}/members/{uid}/avoid` | yes | Replace a member's "I avoid" list — self or Owner (REQ-021) |
| GET | `/v1/products/search?q=&limit=` | yes | Name search → product variants (manual / voice pick list) |
| POST | `/v1/devices` | yes | Register FCM token (PRD §8) |
| DELETE | `/v1/devices?fcm_token=` | yes | Unregister FCM token |

## Environment

| Variable | Required | Notes |
|----------|----------|-------|
| `ALLOW_TEST_AUTH` | local | `true` enables `Bearer test:<uid>` |
| `ENVIRONMENT` | no | `local` / `test` / `prod` |
| `GCP_PROJECT_ID` | prod | GCP project id |
| `FIREBASE_PROJECT_ID` | prod | Usually same as GCP project |
| `GOOGLE_APPLICATION_CREDENTIALS` | local+Firebase | Path to service-account JSON (never commit) |
| `GOOGLE_PLACES_API_KEY` | later | When leaving stub store search |
| `DATABASE_URL` | prod | Shared product catalog (Cloud SQL Postgres, ADR-008). Secret Manager `mekasa-database-url`; unset → in-memory catalog |
| `DATABASE_POOL_SIZE` | no | Catalog connection pool size (default 5) |
| `CATALOG_HOUSEHOLD_SALT` | prod | Salt for `household_hash` in the catalog (NFR-002 AC1); stable per environment, from Secret Manager |

Production secrets belong in **GCP Secret Manager**, not in git.

## GCP / Firebase console checklist

See [`docs/gcp-firebase-setup.md`](../docs/gcp-firebase-setup.md).

## Persistence

| Mode | When |
|------|------|
| `HOUSEHOLD_PERSISTENCE=memory` | Local/unit tests |
| `HOUSEHOLD_PERSISTENCE=firestore` | Cloud Run prod (writes to DB `mekasa-db`) |
| `HOUSEHOLD_PERSISTENCE=auto` | `prod` → firestore, otherwise memory |
| `DATABASE_URL` set | Shared product catalog on Cloud SQL Postgres (`app/catalog_repository.py`); unset → in-memory catalog |

Deploy script sets firestore mode and runs Cloud Run as `mekasa-api@…`.

Inventory documents live at `households/{id}/inventory_items/{item_id}`. Create merges by barcode or same name+category (qty adds). Consume never goes below 0. Creating an inventory item with `price_paid` also writes a purchase event.

Shopping list documents live at `households/{id}/shopping_list_items/{item_id}`. Open rows merge by name; `sync-from-inventory` auto-adds low-stock inventory (REQ-011).

Purchase events live at `households/{id}/purchase_events/{event_id}` (REQ-015–018). Members + invites live under `households/{id}/members|invites` with `invite_tokens/{token}` and `user_memberships/{uid}/households/{id}` for durable join (REQ-019). Active members can read/write inventory and shopping list; invite create/role changes stay owner-only.

### Receipt parser (Gemini) — phase 1, design only

Data model and contracts for REQ-RCP-001…018:

- Household data (receipts, line items, scan events, parse jobs) — Firestore:
  `firestore/` (`migrations/0001_receipt_parser.md`, `schema/*.schema.json`,
  `firestore.indexes.json`).
- Shared product catalog (all accounts) — Cloud SQL for PostgreSQL, ADR-008:
  `postgres/` (`migrations/0001_shared_products.sql` idempotent DDL + `.down.sql`,
  `seed/store_chains.sql`, `README.md` with local/Cloud SQL commands). Runtime reads
  `DATABASE_URL` (Secret Manager `mekasa-database-url`, `/cloudsql` socket); unset →
  in-memory repository.
- Gemini prompt/schema contract: `prompts/receipt_parse/v1/`.
- API contract: `docs/api/receipt-parser.openapi.yaml`; design:
  `docs/design/gemini-receipt-parser.md`.

No runtime code yet — see the design doc's review checklist. Local catalog check:
`psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f postgres/migrations/0001_shared_products.sql` (twice — idempotent).

## Deploy

Project: `hackathon2025-472017` · Region: `us-central1` · Auth: Google + email first

```bash
chmod +x scripts/deploy-cloud-run.sh
./scripts/deploy-cloud-run.sh
```

After deploy, `/health` should include `"persistence":"firestore","firestore_database":"mekasa-db"`.

Cold starts add ~6 s to the first request after idle (noticeable on barcode scans).
`CLOUD_RUN_MIN_INSTANCES=1 ./scripts/deploy-cloud-run.sh` keeps one instance warm
(billed while idle); the default stays 0.

Clients send Firebase ID tokens; the API verifies them. Keep `ALLOW_TEST_AUTH=false` in prod.
Full checklist: [`docs/gcp-firebase-setup.md`](../docs/gcp-firebase-setup.md).
