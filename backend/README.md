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
- **Barcode / UPC lookup** via Open Food Facts (`REQ-004`)

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

## Endpoints

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/health` | no | Liveness |
| GET | `/v1/me` | yes | Caller profile from token |
| POST | `/v1/households` | yes | Create household |
| GET | `/v1/households/current` | yes | Current user's household |
| PUT | `/v1/households/{id}/address` | yes | Confirm address |
| GET | `/v1/households/{id}/stores/nearby` | yes | Stub/Places nearby stores |
| PUT | `/v1/households/{id}/stores` | yes | Persist selected store ids |
| GET | `/v1/households/{id}/inventory` | yes | List inventory items |
| POST | `/v1/households/{id}/inventory` | yes | Create or merge item |
| GET | `/v1/households/{id}/inventory/{item_id}` | yes | Get one item |
| PATCH | `/v1/households/{id}/inventory/{item_id}` | yes | Update item fields |
| POST | `/v1/households/{id}/inventory/{item_id}/refresh-image` | yes | Fill missing `image_url` via OFF / category placeholder |
| DELETE | `/v1/households/{id}/inventory/{item_id}` | yes | Delete item |
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
| POST | `/v1/households/{id}/receipts/scan` | yes | Receipt OCR |
| POST | `/v1/households/{id}/photo` | yes | Household photo (data-URL thin path) |
| GET/POST | `/v1/households/{id}/members` / invites | yes | Family members + invites (REQ-019) |
| POST | `/v1/invites/accept` | yes | Accept invite token |
| GET | `/v1/barcode/{code}` | yes | Open Food Facts UPC lookup (`found` false if unknown) |

## Environment

| Variable | Required | Notes |
|----------|----------|-------|
| `ALLOW_TEST_AUTH` | local | `true` enables `Bearer test:<uid>` |
| `ENVIRONMENT` | no | `local` / `test` / `prod` |
| `GCP_PROJECT_ID` | prod | GCP project id |
| `FIREBASE_PROJECT_ID` | prod | Usually same as GCP project |
| `GOOGLE_APPLICATION_CREDENTIALS` | local+Firebase | Path to service-account JSON (never commit) |
| `GOOGLE_PLACES_API_KEY` | later | When leaving stub store search |

Production secrets belong in **GCP Secret Manager**, not in git.

## GCP / Firebase console checklist

See [`docs/gcp-firebase-setup.md`](../docs/gcp-firebase-setup.md).

## Persistence

| Mode | When |
|------|------|
| `HOUSEHOLD_PERSISTENCE=memory` | Local/unit tests |
| `HOUSEHOLD_PERSISTENCE=firestore` | Cloud Run prod (writes to DB `mekasa-db`) |
| `HOUSEHOLD_PERSISTENCE=auto` | `prod` → firestore, otherwise memory |

Deploy script sets firestore mode and runs Cloud Run as `mekasa-api@…`.

Inventory documents live at `households/{id}/inventory_items/{item_id}`. Create merges by barcode or same name+category (qty adds). Consume never goes below 0. Creating an inventory item with `price_paid` also writes a purchase event.

Shopping list documents live at `households/{id}/shopping_list_items/{item_id}`. Open rows merge by name; `sync-from-inventory` auto-adds low-stock inventory (REQ-011).

Purchase events live at `households/{id}/purchase_events/{event_id}` (REQ-015–018). Members + invites live under `households/{id}/members|invites` with `invite_tokens/{token}` and `user_memberships/{uid}/households/{id}` for durable join (REQ-019). Active members can read/write inventory and shopping list; invite create/role changes stay owner-only.

## Deploy

Project: `hackathon2025-472017` · Region: `us-central1` · Auth: Google + email first

```bash
chmod +x scripts/deploy-cloud-run.sh
./scripts/deploy-cloud-run.sh
```

After deploy, `/health` should include `"persistence":"firestore","firestore_database":"mekasa-db"`.

Clients send Firebase ID tokens; the API verifies them. Keep `ALLOW_TEST_AUTH=false` in prod.
Full checklist: [`docs/gcp-firebase-setup.md`](../docs/gcp-firebase-setup.md).
