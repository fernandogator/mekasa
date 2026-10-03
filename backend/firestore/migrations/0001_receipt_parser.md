# Migration 0001 — receipt parser: receipts, line items, scan events, parse jobs

Spec version: 1.0 · Satisfies: REQ-RCP-001 … REQ-RCP-008, REQ-RCP-012,
REQ-RCP-015 … REQ-RCP-018 · Design: `docs/design/gemini-receipt-parser.md`

This is the **household-scoped half** of the receipt-parser data model. The
shared product catalog (`store_chains`, `products`, `product_aliases`,
`product_confirmations`, `enrichment_jobs`, `product_conflicts`) lives in Cloud
SQL for PostgreSQL and is migrated separately — see `backend/postgres/`
(`migrations/0001_shared_products.sql`, ADR-008). Firestore documents reference catalog
rows only by opaque string ids (`matched_product_id`, `product_id`,
`conflict_id`).

Firestore has no `ALTER TABLE`; a "migration" here is (a) new collections and
optional fields documented below and enforced by the JSON Schemas in
`backend/firestore/schema/`, (b) composite indexes in
`backend/firestore/firestore.indexes.json`, (c) infrastructure the code
expects, and (d) backfill rules. Everything is additive; existing documents
stay valid.

Status: **draft — awaiting review (phase 1)**. Apply steps run in phase 2.

## Apply

```bash
# from repo root; project + database from docs/gcp-firebase-setup.md
gcloud config set project hackathon2025-472017
gcloud firestore indexes composite create --database=mekasa-db \
  --file=backend/firestore/firestore.indexes.json   # or: firebase deploy --only firestore:indexes

# TTL for audit docs (REQ-RCP-018 retention; value under review, §9.5 of design)
gcloud firestore fields ttls update expires_at --collection-group=llm_parse_jobs --database=mekasa-db --enable-ttl

# Receipt image bucket (no public access)
gsutil mb -l us-central1 -b on gs://mekasa-receipts-dev
gsutil lifecycle set backend/firestore/migrations/0001_receipts_bucket_lifecycle.json gs://mekasa-receipts-dev

# Cloud Tasks queues
gcloud tasks queues create receipt-parse --location=us-central1 --max-concurrent-dispatches=5
gcloud tasks queues create enrichment    --location=us-central1 --max-dispatches-per-second=0.05

# IAM for the Cloud Run runtime SA
gcloud projects add-iam-policy-binding hackathon2025-472017 \
  --member=serviceAccount:mekasa-api@hackathon2025-472017.iam.gserviceaccount.com \
  --role=roles/aiplatform.user
```

Catalog database (Cloud SQL instance `mekasa-pg`, database `mekasa`, user
`mekasa_api`, `psql -f 0001_shared_products.sql`, `store_chains` seed): follow
`backend/postgres/README.md`. Its one secret, the connection string, lives in
Secret Manager as `mekasa-database-url` and is injected as `DATABASE_URL`.

No secrets are introduced for Vertex AI or GCS (runtime service account).
The Kroger `store_api` adapter needs `KROGER_CLIENT_ID` / `KROGER_CLIENT_SECRET`
in Secret Manager (register at developer.kroger.com; names only in code):

```bash
printf '%s' "$KROGER_CLIENT_ID"     | gcloud secrets create KROGER_CLIENT_ID     --data-file=-
printf '%s' "$KROGER_CLIENT_SECRET" | gcloud secrets create KROGER_CLIENT_SECRET --data-file=-
```

## Rollback

Indexes and TTL policies can be deleted; collections can be left in place
(unused) or purged with a scripted delete. No existing document is modified by
this migration, so rollback of code is sufficient to restore prior behaviour.
Catalog rollback: `psql "$DATABASE_URL" -f backend/postgres/migrations/0001_shared_products.down.sql`.

---

## New collections

### Shared catalog → Cloud SQL (`backend/postgres/migrations/0001_shared_products.sql`)

`store_chains`, `products`, `product_aliases`, `product_confirmations`,
`enrichment_jobs`/`enrichment_steps`, and `product_conflicts` are Postgres
tables, not collections (ADR-008). Column-level notes are comments in the DDL;
the seed for `store_chains` (Walmart `api_provider: walmart`, Kroger `kroger`,
H-E-B / Publix / Costco / Target `none`, `unknown`) is
`backend/postgres/seed/store_chains.sql`.

`products.product_id` = UPC/GTIN digits when known, `plu:<IFPS code>` for bulk
produce (shared across chains), otherwise
`llm:<sha1(store_chain_id + "|" + normalized_name)>`. When enrichment or scan
correlation finds a UPC for an `llm:` row, a new UPC row is written and the old
row gets `superseded_by` (REQ-RCP-010 AC2). Firestore fields that hold these
keys use the `productId` definition in `schema/_common.schema.json`.

`purchased_at` on receipts is stored as a UTC timestamp; Gemini returns naive
store-local time, and the API localises it with the store's time zone (from
Places) or, failing that, the household's.

### `households/{household_id}/receipts/{receipt_id}`

| Field | Type | Notes |
|---|---|---|
| `household_id` | string | denormalized for collection-group queries |
| `store_id` | string? | Places id from `households.store_ids` (client hint) |
| `store_chain_id` | string | resolved chain (hint → Gemini header detection → `unknown`) |
| `store_chain_detected` | string? | chain name Gemini read from the header |
| `image_gcs_uri` | string? | `gs://mekasa-receipts-<env>/households/{hid}/receipts/{rid}/original.jpg` |
| `image_sha256` | string? | duplicate detection (design §9.8) |
| `raw_text` | string? | OCR/pasted text when no image |
| `status` | enum | `uploaded` \| `parsing` \| `parsed` \| `needs_review` \| `confirmed` \| `failed` |
| `extraction_engine` | enum? | `gemini` \| `vision_regex` \| `text_regex` \| `stub` |
| `parse_job_id` | string? | latest `llm_parse_jobs` doc |
| `purchased_at` | timestamp? | from receipt; falls back to `created_at` |
| `currency` | string | ISO-4217, `USD` |
| `subtotal`, `tax`, `total` | number? | as printed |
| `line_item_count` | int | |
| `unresolved_count` | int | lines with `resolution_status ∈ {needs_confirmation, unmatched}` |
| `created_by_uid` | string | |
| `confirmed_by_uid`, `confirmed_at` | string?, timestamp? | |
| `created_at`, `updated_at` | timestamp | |

### `households/{household_id}/receipts/{receipt_id}/line_items/{line_item_id}`

| Field | Type | Kickoff | Notes |
|---|---|---|---|
| `line_no` | int | | order on receipt (1-based) |
| `raw_text` | string | ✔ | verbatim printed line(s), PII-scrubbed by prompt + validator |
| `description` | string | | cleaned product description from Gemini |
| `price` | number ≥ 0 | ✔ | extended price paid for the line, after discounts |
| `unit_price` | number? | | |
| `qty` | number > 0 | ✔ | decimal to allow weight; see design §9.6 |
| `unit` | string? | | `each`, `lb`, `kg`, `oz`… |
| `discount` | number? | | negative amounts folded from following coupon lines |
| `printed_code` | string? | | UPC / item number if printed |
| `category` | string | | Mekasa category (Gemini suggestion, user-editable) |
| `extraction_confidence` | number 0–1 | | Gemini per-line confidence |
| `matched_product_id` | string? | ✔ | nullable; key into catalog `products.product_id` (Cloud SQL) |
| `match_method` | enum? | | `exact_upc` \| `scan_correlation` \| `alias` \| `fuzzy` \| `enrichment` \| `user` |
| `match_confidence` | number 0–1? | | |
| `resolution_status` | enum | | `auto_matched` \| `needs_confirmation` \| `unmatched` \| `confirmed` \| `rejected` \| `skipped` |
| `candidate_product_ids` | string[] | | ≤ 5, ordered by confidence |
| `conflict_id` | string? | | catalog `product_conflicts.conflict_id` (UUID) when REQ-RCP-014 fired |
| `image_url` | string | | household photo (`/v1/product-photos/{photo_id}`) if attached, else catalog image, else category placeholder (REQ-005 AC4, REQ-RCP-019 AC4) |
| `image_source` | string? | | `user_photo` \| `store_api` \| `openfoodfacts` \| `gs1_registry` \| `placeholder` |
| `photo_id` | string? | | this household's photo for the line (`product_photos/{photo_id}`), REQ-RCP-019 AC4 |
| `user_edited_fields` | string[] | | fields overridden via `PATCH …/line-items/{lid}` (REQ-RCP-019 AC1); `confirm` writes the overrides |
| `barcode` | string? | | UPC exposed to legacy clients (= product `upc`); `null` → client offers "Scan product" (REQ-RCP-020 AC1) |
| `inventory_item_id`, `purchase_event_id` | string? | | stamped on confirm |
| `resolved_by_uid`, `resolved_at` | string?, timestamp? | | |
| `created_at`, `updated_at` | timestamp | | |

Legacy `ReceiptLineItem.identified` = `resolution_status ∈ {auto_matched, confirmed}`.

### `households/{household_id}/scan_events/{event_id}` (REQ-RCP-016)

Supersedes the in-memory `unknown_barcode_log`.

| Field | Type | Notes |
|---|---|---|
| `upc` | string | as scanned (raw), 6–14 digits |
| `scanned_by_uid` | string | |
| `scanned_at` | timestamp | |
| `context` | enum | `add_items` \| `trash_station` \| `manual_entry` \| `receipt_capture` \| `inventory_capture` (REQ-RCP-020 AC4) |
| `outcome` | enum | `found` \| `unknown` \| `consumed` \| `created` (capture created a new `user_scan` product) |
| `lookup_source` | string? | `openfoodfacts` \| `products` \| `none` |
| `product_name_at_scan` | string? | for correlation similarity |
| `product_id` | string? | catalog `products.product_id` |
| `correlated_receipt_id`, `correlated_line_item_id` | string? | set once by REQ-RCP-008 |
| `created_at` | timestamp | |

### `llm_parse_jobs/{job_id}` (top-level; REQ-RCP-002/004/005/017/018)

| Field | Type | Notes |
|---|---|---|
| `household_id`, `receipt_id` | string | |
| `provider` | const | `vertex_ai` |
| `model` | string | e.g. `gemini-2.5-pro` |
| `vertex_location` | string | e.g. `us-central1` |
| `prompt_version` | string | `receipt_parse/v1` |
| `prompt_sha256` | string | hash of rendered-template source `system.md` |
| `schema_version` | string | `receipt_parse/v1/response.schema.json@<sha256 prefix>` |
| `store_chain_name` | string | value injected into `{{store_chain_name}}` |
| `input_kind` | enum | `image` \| `text` |
| `status` | enum | `queued` \| `running` \| `validating` \| `retrying` \| `succeeded` \| `failed` |
| `attempt` | int 1–3 | current/last attempt |
| `max_attempts` | int | 3 (= 1 + 2 retries) |
| `attempts` | array | `{attempt, started_at, finished_at, latency_ms, validation_errors[], corrective_prompt_applied, raw_response?, raw_response_gcs_uri?, usage{input_tokens, output_tokens}, finish_reason}` |
| `error_code` | enum? | `schema_invalid` \| `model_error` \| `timeout` \| `safety_blocked` \| `pii_detected` |
| `result_summary` | map? | `{line_count, store_chain_detected, totals_mismatch}` |
| `requested_by_uid` | string | |
| `expires_at` | timestamp | TTL field (created_at + 180 d) |
| `created_at`, `updated_at` | timestamp | |

## Additions to existing documents (optional fields, no backfill)

| Collection | New field | Purpose |
|---|---|---|
| `households/{hid}/inventory_items` | `product_id: string?` | link to shared product |
| `households/{hid}/inventory_items` | `receipt_line_item_id: string?` | provenance |
| `households/{hid}/purchases` | `receipt_id`, `receipt_line_item_id`, `product_id` (string?) | REQ-RCP-015 / REQ-015 AC3 |
| `households/{hid}/inventory_items` | `photo_id: string?`, `image_source: string?` | user photo attached via `PATCH …/inventory/{item_id}` or `…/capture` (REQ-RCP-019 AC6, REQ-RCP-020 AC6) |

### `households/{household_id}/product_photos/{photo_id}` (REQ-RCP-021)

Ownership record for a user product photo. The bytes live in bucket
`mekasa-product-photos-<env>` at `product-photos/{photo_id}.jpg` — the object
name and the public URL `/v1/product-photos/{photo_id}` carry no household or
user id, so the photo can back a shared `products.image_url` (NFR-002 AC1).

| Field | Type | Notes |
|---|---|---|
| `uploaded_by_uid` | string | |
| `content_type_in` | enum | `image/jpeg` \| `image/png` \| `image/heic` as uploaded; stored object is always JPEG, EXIF/GPS stripped, long edge ≤ 1600 px |
| `width`, `height`, `bytes` | int | after re-encoding |
| `referenced_by` | string[] | `line:{rid}/{lid}`, `inventory:{item_id}`, `product:{product_id}`; maintained by the PATCH/capture/corrections handlers |
| `expires_at` | timestamp? | `created_at + 24 h` while `referenced_by` is empty; cleared on first reference (daily purge, REQ-RCP-021 AC4) |
| `created_at`, `deleted_at` | timestamp, timestamp? | `deleted_at` set by `DELETE …/product-photos/{photo_id}`; catalog fallback is queued as `enrichment_jobs(trigger=image_removed)` |

## Backfill

- None required. Readers must treat missing optional fields as `null`.
- Optional one-off: seed catalog `products` from existing
  `inventory_items.barcode` values as `source: user_scan`, `status: unverified`
  (script in phase 2, gated behind `--apply`; writes to Cloud SQL).

## Index rationale (see `firestore.indexes.json`)

Catalog lookups (alias, trigram fuzzy match, curation lists, enrichment
queue, conflict queue) are Postgres indexes in `0001_shared_products.sql`.

| Query | Index |
|---|---|
| scan correlation window | `scan_events` (collection group): `correlated_receipt_id ASC, scanned_at DESC` |
| unknown-barcode log | `scan_events`: `outcome ASC, created_at DESC` |
| receipts list | `receipts`: `status ASC, created_at DESC` |
| ops: failures by prompt | `llm_parse_jobs`: `status ASC, prompt_version ASC, created_at DESC` |
| ops: per receipt | `llm_parse_jobs`: `receipt_id ASC, created_at DESC` |
