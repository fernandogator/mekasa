# Migration 0001 — receipt parser, shared products, scan events

Spec version: 1.0 · Satisfies: REQ-RCP-001 … REQ-RCP-018 · Design:
`docs/design/gemini-receipt-parser.md`

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
gcloud firestore fields ttls update expires_at --collection-group=enrichment_jobs --database=mekasa-db --enable-ttl

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

No secrets are introduced (Vertex AI + GCS use the runtime service account).

## Rollback

Indexes and TTL policies can be deleted; collections can be left in place
(unused) or purged with a scripted delete. No existing document is modified by
this migration, so rollback of code is sufficient to restore prior behaviour.

---

## New collections

### `store_chains/{chain_id}` (shared, read-only for clients)

| Field | Type | Notes |
|---|---|---|
| `chain_id` | string | slug, e.g. `publix`, `walmart`, `costco`, `kroger`, `unknown` |
| `name` | string | display name injected as `{{store_chain_name}}` |
| `aliases` | string[] | header spellings (`PUBLIX SUPER MARKETS`, `WAL-MART`) |
| `website_domain` | string? | for the store-site enrichment adapter |
| `receipt_code_kind` | `none`\|`upc`\|`item_number` | what code the chain prints per line |
| `created_at`, `updated_at` | timestamp | |

Seeded from the Places names already returned by `stub_nearby_stores` /
`places_lookup` (Walmart, Costco, Publix, Kroger) + `unknown`.

### `products/{product_id}` (shared UPC product database — ADR-008)

`product_id` = UPC/GTIN digits when known, otherwise
`llm:<sha1(store_chain_id + "|" + normalized_name)>`. When enrichment finds a
UPC for an `llm:` doc the doc is **re-keyed**: a new `products/{upc}` is
written (merging counts) and the old doc gets `superseded_by: "<upc>"`.

| Field | Type | Kickoff | Notes |
|---|---|---|---|
| `upc` | string? | ✔ | 8–14 digits; null until resolved |
| `store_chain_id` | string | ✔ | chain where first observed; `unknown` allowed |
| `name` | string | ✔ | canonical display name |
| `normalized_name` | string | | casefold, collapsed whitespace, no punctuation |
| `name_tokens` | string[] | | ≤ 10 tokens, for `array_contains_any` fuzzy lookups |
| `receipt_aliases` | string[] | | normalized raw receipt texts seen for this product (≤ 25) |
| `brand` | string? | ✔ | |
| `category` | string | ✔ | Mekasa category vocabulary (`Produce`, `Dairy`, …, `Other`) |
| `unit_size` | string? | ✔ | free text as printed/enriched, e.g. `12 oz` |
| `image_url` | string? | | ADR-006 waterfall result |
| `source` | enum | ✔ | `user_scan` \| `store_site` \| `gs1_registry` \| `llm_ocr` — best source so far |
| `sources_seen` | enum[] | | every source that contributed |
| `confidence_score` | number 0–1 | ✔ | recomputed on every transition (design §3.5) |
| `confirmation_count` | int ≥ 0 | ✔ | user confirmations (REQ-RCP-013) |
| `confirming_household_hashes` | string[] | | SHA-256(household_id + salt); no raw household ids (NFR-002) |
| `dispute_count` | int ≥ 0 | | confirmations that contradicted a verified doc (REQ-RCP-014) |
| `status` | enum | ✔ | `unverified` \| `pending` \| `verified` |
| `status_changed_at` | timestamp | | |
| `origin_parse_job_id` | string? | | provenance for `llm_ocr` docs |
| `origin_prompt_version` | string? | | e.g. `receipt_parse/v1` |
| `superseded_by` | string? | | see re-keying above |
| `first_seen_at`, `last_seen_at`, `created_at`, `updated_at` | timestamp | | |

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
| `matched_product_id` | string? | ✔ | nullable |
| `match_method` | enum? | | `exact_upc` \| `scan_correlation` \| `alias` \| `fuzzy` \| `enrichment` \| `user` |
| `match_confidence` | number 0–1? | | |
| `resolution_status` | enum | | `auto_matched` \| `needs_confirmation` \| `unmatched` \| `confirmed` \| `rejected` \| `skipped` |
| `candidate_product_ids` | string[] | | ≤ 5, ordered by confidence |
| `conflict_id` | string? | | `product_conflicts` doc when REQ-RCP-014 fired |
| `image_url` | string | | catalog image or category placeholder (REQ-005 AC4) |
| `barcode` | string? | | UPC exposed to legacy clients (= product `upc`) |
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
| `context` | enum | `add_items` \| `trash_station` \| `manual_entry` |
| `outcome` | enum | `found` \| `unknown` \| `consumed` |
| `lookup_source` | string? | `openfoodfacts` \| `products` \| `none` |
| `product_name_at_scan` | string? | for correlation similarity |
| `product_id` | string? | |
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

### `enrichment_jobs/{job_id}` (REQ-RCP-009/010)

| Field | Type | Notes |
|---|---|---|
| `product_id` | string | |
| `trigger` | enum | `unmatched_line` \| `manual` \| `reverify` |
| `chain` | string[] | `["store_site","gs1_registry","upcitemdb","openfoodfacts","crowdsourced_pending"]` |
| `steps` | array | `{adapter, status: skipped|hit|miss|error|not_implemented, started_at, finished_at, upc?, note?}` |
| `status` | enum | `queued` \| `running` \| `succeeded` \| `exhausted` \| `failed` |
| `result_source` | enum? | source that produced the hit |
| `expires_at`, `created_at`, `updated_at` | timestamp | |

### `product_conflicts/{conflict_id}` (REQ-RCP-014)

| Field | Type | Notes |
|---|---|---|
| `product_id` | string | the `verified` product |
| `household_hash` | string | hashed household id (no raw id) |
| `receipt_id`, `line_item_id` | string | |
| `field` | enum | `name` \| `brand` \| `unit_size` \| `category` \| `upc` |
| `verified_value`, `observed_value` | string | |
| `status` | enum | `open` \| `dismissed` \| `accepted` |
| `created_at`, `updated_at` | timestamp | |

## Additions to existing documents (optional fields, no backfill)

| Collection | New field | Purpose |
|---|---|---|
| `households/{hid}/inventory_items` | `product_id: string?` | link to shared product |
| `households/{hid}/inventory_items` | `receipt_line_item_id: string?` | provenance |
| `households/{hid}/purchases` | `receipt_id`, `receipt_line_item_id`, `product_id` (string?) | REQ-RCP-015 / REQ-015 AC3 |

## Backfill

- None required. Readers must treat missing optional fields as `null`.
- Optional one-off: seed `products` from existing `inventory_items.barcode`
  values as `source: user_scan`, `status: unverified` (script in phase 2,
  gated behind `--apply`).

## Index rationale (see `firestore.indexes.json`)

| Query | Index |
|---|---|
| alias match per chain | `products`: `store_chain_id ASC, receipt_aliases CONTAINS` |
| fuzzy token match per chain | `products`: `store_chain_id ASC, name_tokens CONTAINS` |
| curation lists | `products`: `status ASC, confidence_score DESC` |
| scan correlation window | `scan_events` (collection group): `correlated_receipt_id ASC, scanned_at DESC` |
| unknown-barcode log | `scan_events`: `outcome ASC, created_at DESC` |
| receipts list | `receipts`: `status ASC, created_at DESC` |
| ops: failures by prompt | `llm_parse_jobs`: `status ASC, prompt_version ASC, created_at DESC` |
| ops: per receipt | `llm_parse_jobs`: `receipt_id ASC, created_at DESC` |
| enrichment worker | `enrichment_jobs`: `status ASC, created_at ASC` |
| conflict queue | `product_conflicts`: `status ASC, created_at DESC` |
