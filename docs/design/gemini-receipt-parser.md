# Design — Gemini-Based Receipt Scanner for the UPC Product Database

Spec version: 1.0 (adds REQ-RCP-001 … REQ-RCP-018)
Status: **Draft — awaiting review after data model + API contract (phase 1;
revised 2026-09-29: shared catalog moved to Cloud SQL Postgres)**
Owner: backend
Related: ADR-002a (Firestore for household data), ADR-003 (server-side OCR),
ADR-004 / ADR-006 (UPC + image waterfall), ADR-007 (this design), ADR-008
(shared product catalog on Cloud SQL)

---

## 0. Review checklist (what this phase asks you to decide)

Phase 1 deliverables are in this PR. Nothing under `backend/app/` changes yet.

| # | Deliverable | Where |
|---|-------------|-------|
| 1a | Household data model + migration `0001_receipt_parser` (Firestore) | `backend/firestore/migrations/0001_receipt_parser.md`, `backend/firestore/schema/*.schema.json`, `backend/firestore/firestore.indexes.json` |
| 1b | Shared catalog data model + migration `0001_shared_products` (Cloud SQL Postgres) | `backend/postgres/migrations/0001_shared_products.sql` (+ `.down.sql`), `backend/postgres/seed/store_chains.sql`, `backend/postgres/README.md` |
| 3 | API contract (OpenAPI 3.1) | `docs/api/receipt-parser.openapi.yaml` |
| — | Gemini prompt + response schema contract (v1) | `backend/prompts/receipt_parse/v1/` |
| — | Spec entries REQ-RCP-001 … 018, ADR-007, ADR-008, traceability rows | `docs/spec-v1.0.md`, `docs/architecture.md`, `traceability/matrix.*` |
| 6 | This design doc | `docs/design/gemini-receipt-parser.md` |

Deferred to phase 2 (after your sign-off): services (2), test stubs (4), CI/CD +
prompt/schema lint (5).

**Please verify §2 (requirement mapping).** The kickoff numbered its EARS
requirements REQ-1 … REQ-18. Those IDs collide with the permanent `REQ-001 …`
series already in `docs/spec-v1.0.md`, so they are re-keyed as
`REQ-RCP-001 … REQ-RCP-018` (same order). The EARS wording in the spec is a
paraphrase of the kickoff; confirm it before phase 2 so tests are annotated
against the intended requirement.

---

## 1. Goals and non-goals

Goals

- Replace heuristic regex parsing of Cloud Vision text (`receipt_ocr.parse_receipt_text`)
  with a Gemini Pro call on Vertex AI that returns structured line items for
  the whole receipt in a single request.
- Grow a **shared UPC product catalog** (`products` and friends in Cloud SQL
  for PostgreSQL, one catalog for all accounts) from receipts, barcode scans,
  and enrichment sources, with provenance (`source`), a `confidence_score`,
  `confirmation_count`, and a `status` lifecycle `unverified → pending →
  verified`.
- Keep every LLM interaction auditable: versioned prompt, recorded model id,
  raw response retained per attempt.
- Preserve the existing client contract (`ReceiptLineItem`, confirm-haul
  screen, `identified` flag) so iOS/Android keep working while they migrate.

Non-goals (v1 of this feature)

- On-device LLM or on-device OCR of receipts (ADR-003 stands).
- Price estimation (REQ-016) — untouched, but receipts now feed it better data.
- A public/admin curation UI for `verified` products (open question §9).
- Scraping retailer websites — never (ADR-008). Retailer data comes only from
  official APIs (`store_api`, Kroger first); chains without one fall back to
  scan correlation and Open Food Facts.

---

## 2. Requirement mapping (kickoff → Mekasa spec)

| Kickoff | Mekasa ID | Title (EARS pattern) |
|---------|-----------|----------------------|
| REQ-1  | REQ-RCP-001 | Receipt upload creates receipt + parse job (event-driven) |
| REQ-2  | REQ-RCP-002 | Parse job invokes Gemini via Vertex AI, whole receipt, one call (event-driven) |
| REQ-3  | REQ-RCP-003 | Gemini response validated against JSON schema before persistence (event-driven) |
| REQ-4  | REQ-RCP-004 | Invalid response → corrective retry, max 2 retries (unwanted behaviour) |
| REQ-5  | REQ-RCP-005 | Exhausted retries → job `failed`, receipt `needs_review`, OCR fallback (unwanted behaviour) |
| REQ-6  | REQ-RCP-006 | Validated lines persisted as `line_items` with raw text, price, qty, confidence (event-driven) |
| REQ-7  | REQ-RCP-007 | Each line matched against `products` scoped to store chain (ubiquitous) |
| REQ-8  | REQ-RCP-008 | Unmatched lines correlated with recent household scan events to recover UPC (state-driven) |
| REQ-9  | REQ-RCP-009 | No match → `llm_ocr` unverified product + enrichment job (event-driven) |
| REQ-10 | REQ-RCP-010 | Enrichment order: official store API → UPCitemdb / Open Food Facts → GS1 verification → crowdsourced pending (ubiquitous; GS1 repositioned as verification, see §3.6) |
| REQ-11 | REQ-RCP-011 | Every product carries source, confidence_score, confirmation_count, status (ubiquitous) |
| REQ-12 | REQ-RCP-012 | Below auto-accept confidence → user confirmation required before link (state-driven) |
| REQ-13 | REQ-RCP-013 | User confirmation increments confirmation_count and re-evaluates status (event-driven) |
| REQ-14 | REQ-RCP-014 | Conflict with a `verified` product never mutates it; conflict recorded, confirmation required (unwanted behaviour) |
| REQ-15 | REQ-RCP-015 | Receipt confirm writes inventory items + purchase events with price-paid and store (event-driven) |
| REQ-16 | REQ-RCP-016 | Scan events persisted (upc, household, time, context) (ubiquitous) |
| REQ-17 | REQ-RCP-017 | Parse job records prompt version, schema version, model id (ubiquitous) |
| REQ-18 | REQ-RCP-018 | Raw Gemini JSON retained per attempt for audit (ubiquitous) |

Full EARS text and acceptance criteria: `docs/spec-v1.0.md` → "Receipt
Intelligence (Gemini parser)".

---

## 3. Architecture

```mermaid
graph TD
  Client[iOS / Android\nReceiptScanView] -->|POST /receipts (image or text)| API[Cloud Run API\nFastAPI]
  API -->|1. store image| GCS[(Cloud Storage\nmekasa-receipts)]
  API -->|2. create receipt + llm_parse_job| FS[(Firestore mekasa-db\nhousehold data)]
  API -->|7. match / correlate / upsert products| PG[(Cloud SQL Postgres\nshared catalog)]
  API -->|3. run job (in-request, wait_seconds)\nor enqueue| Tasks[Cloud Tasks\nreceipt-parse queue]
  Tasks -->|POST /internal/parse-jobs/{id}/run| API
  API -->|4. generate_content\nsystem prompt v1 + image| Vertex[Vertex AI\nGemini Pro]
  API -->|5. validate → retry ≤2| API
  API -->|6. persist line_items,\nraw response| FS
  API -->|8. enrichment_jobs| Tasks
  API -->|store API (Kroger) → UPCitemdb/OFF → GS1 verify| Ext[Enrichment sources]
  Client -->|GET receipt / resolve / confirm| API
```

### 3.1 Components (all inside the existing Cloud Run service)

| Component | Module (phase 2) | Responsibility |
|-----------|------------------|----------------|
| Receipt ingestion | `app/receipts_router.py`, `app/receipts_repository.py` | Auth + household membership, store image, create `receipts/{id}` and `llm_parse_jobs/{id}`, sync-wait or enqueue |
| Gemini invocation | `app/gemini_receipt_parser.py` | Build request from versioned prompt, call Vertex AI, validate, corrective retry, persist attempts + raw JSON |
| Matching / resolution | `app/product_resolver.py` | UPC → scan correlation → alias → fuzzy (trigram); confidence thresholds; verified-conflict guard |
| Enrichment dispatcher | `app/enrichment_dispatcher.py` | Create `enrichment_jobs` rows, run adapter chain, upgrade product `source`/`status` |
| Products repository | `app/products_repository.py` | Targets **Postgres**: Protocol + `InMemoryProductsRepository` (when `DATABASE_URL` is unset) + `PostgresProductsRepository` (`psycopg` 3, `psycopg_pool`, `/cloudsql` socket); `products`, `product_aliases`, `product_confirmations`, `store_chains`, `enrichment_jobs`, `product_conflicts`; status transitions; once-per-household confirmation counting; the §4.1 transactions |
| Scan events | `app/scan_events_repository.py` | Replaces in-memory `unknown_barcode_log` with a persisted household subcollection |

One service, not separate Cloud Functions: keeps auth, Firestore clients, and
the memory/Firestore persistence switch (`HOUSEHOLD_PERSISTENCE`) that all
tests rely on. The catalog gets the same treatment: `DATABASE_URL` unset →
in-memory repository, so unit tests never open a database connection. Cloud Tasks targets an internal route on the same service
(OIDC-authenticated, `X-CloudTasks-QueueName` checked). Local/test mode runs
jobs inline.

### 3.2 Sync vs. async

Gemini Pro on a full receipt image is typically 5–20 s. The kickoff asks for
Cloud Run/Functions-style backend services; the current mobile screens expect
a synchronous answer. The contract supports both:

- `POST /v1/households/{hid}/receipts?wait_seconds=N` (0–45). With `N>0` the
  API runs the parse job inline and returns `200` with line items when it
  finishes in time, otherwise `202` with `status: parsing` and the client polls
  `GET /receipts/{rid}`.
- `wait_seconds=0` (default) always returns `202` and dispatches to Cloud Tasks
  (`RECEIPT_PARSE_MODE=tasks`) or a background task in-process
  (`RECEIPT_PARSE_MODE=inline`, used for tests and local).
- Existing `POST /receipts/scan` stays as a deprecated alias equivalent to
  `wait_seconds=45` and returns the legacy `ReceiptScanResponse` shape.

### 3.3 Gemini invocation (Vertex AI SDK, not the public Gemini API)

- SDK: `google-genai` with `vertexai=True`, `project=<GCP_PROJECT_ID>`,
  `location=<VERTEX_LOCATION>` (default `us-central1`). Uses the Cloud Run
  runtime service account (ADC) — **no API key** (GUARDRAILS rule 4,
  NFR-004). Required IAM: `roles/aiplatform.user` on `mekasa-api@…`.
- Model id from `GEMINI_MODEL` (default `gemini-2.5-pro`); recorded on every job
  (REQ-RCP-017).
- One `generate_content` call per receipt (REQ-RCP-002): parts = system prompt
  (rendered from `backend/prompts/receipt_parse/v1/system.md` with
  `{{store_chain_name}}`), the image (`image/jpeg` or `image/png` inline bytes)
  **or** the OCR text when only `raw_text` was supplied, and the user turn
  "Parse this receipt."
- `response_mime_type="application/json"` and `response_schema` set to the
  same JSON Schema we validate against, so the model is constrained and we
  still validate independently (REQ-RCP-003; belt and braces).
- Timeout 60 s per attempt (deviation from the 10 s external-call rule in
  `docs/code-standards.md`; recorded in ADR-007 — LLM calls are the one
  documented exception). No SDK-level retries; retries are explicit below.
- Validation: `jsonschema` Draft 2020-12 against
  `backend/prompts/receipt_parse/v1/response.schema.json`, plus semantic
  checks (line `price >= 0`, `qty >= 1`, `confidence` in [0,1], sum of lines
  vs. `totals.subtotal` within 5% or flagged `totals_mismatch`).
- Corrective retry (REQ-RCP-004): on failure, append a corrective user turn
  containing the validator error list and the offending snippet
  (`backend/prompts/receipt_parse/v1/corrective.md`), same system prompt, up
  to 2 retries (3 attempts total). Each attempt is stored in
  `llm_parse_jobs.attempts[]` with its raw response (REQ-RCP-018).
- Exhausted (REQ-RCP-005): job `failed` with `error_code`
  (`schema_invalid|model_error|timeout|safety_blocked`), receipt
  `needs_review`, and the existing Vision + regex path
  (`receipt_ocr.parse_receipt_image`) produces fallback lines with
  `extraction_engine: "vision_regex"` so the user still gets a haul to edit.

### 3.4 Matching / resolution pipeline (per line item)

Order stops at the first hit; every step records `match_method` and
`match_confidence`.

1. **exact_upc** — the receipt printed a UPC/item code and it matches
   `products.upc` (`UNIQUE`) for any chain (Walmart, Costco print item numbers;
   mapping table per chain is in `store_chains.receipt_code_kind`).
2. **scan_correlation** (REQ-RCP-008) — two passes over
   `households/{hid}/scan_events` with `correlated_receipt_id == null`:
   - *Backward pass (at parse time):* events with context `add_items` in
     `[purchased_at − 72 h, receipt.created_at + 1 h]`.
   - *Forward pass (at scan time):* whenever a new scan event arrives in any
     context (`add_items` while unpacking, `trash_station` weeks later), the
     resolver looks back at the household's `unmatched` / `needs_confirmation`
     line items from the last 30 days. The scanned UPC is named via
     `products` or Open Food Facts, then compared with the lines. Because every
     product eventually passes the trash-station scanner, this loop closes
     UPCs for chains that print none (H-E-B, Publix) without any retailer data.

   Both passes use greedy one-to-one assignment by name similarity ≥ 0.6
   (token overlap as in `receipt_ocr._is_strong_match`, extended with chain
   aliases). The event is stamped with `correlated_receipt_id/line_item_id`;
   the line inherits the scan's UPC with confidence `0.8 + 0.2·similarity`.
   A forward-pass hit on a line the user already confirmed to an `llm:`
   product re-keys that product to the UPC (see §3.6) rather than changing
   the line.
3. **alias** — `product_aliases` primary-key lookup
   `(store_chain_id, catalog_normalize_name(raw_text))`. One alias maps to
   exactly one product per chain, so a hit is confidence 0.95.
4. **fuzzy** — `pg_trgm` similarity on `products.normalized_name` and
   `product_aliases.alias` (GIN trigram indexes), chain-scoped, brand-gated when
   the line has a `brand`:
   `SET LOCAL pg_trgm.similarity_threshold = 0.3;` then
   `WHERE store_chain_id = $chain AND normalized_name % $q ORDER BY
   similarity(normalized_name, $q) DESC LIMIT 5`. Thresholds: the `%` operator
   at **0.3** bounds the candidate set (index-assisted); the best candidate is
   accepted as the match only at similarity **≥ 0.5**, and its
   `match_confidence` is the similarity value, so REQ-RCP-012's bands apply
   unchanged (≥ 0.85 auto, 0.5–0.85 needs confirmation). The remaining
   candidates become `candidate_product_ids`.
5. **none** → REQ-RCP-009: upsert `products` row
   `llm:{sha1(chain|normalized_name)}` with `source: llm_ocr`,
   `status: unverified`, `confidence_score` = Gemini line confidence × 0.6, and
   insert an `enrichment_jobs` row (a partial unique index guarantees one live
   job per product).

Thresholds (configurable, `RESOLVER_AUTO_ACCEPT=0.85`,
`RESOLVER_MIN_SUGGEST=0.5`):

| `match_confidence` | `resolution_status` | client behaviour |
|---|---|---|
| ≥ 0.85 | `auto_matched` | shown as identified; still editable |
| 0.5 – 0.85 | `needs_confirmation` (REQ-RCP-012) | highlighted, candidates offered |
| < 0.5 / none | `unmatched` | highlighted, search + manual entry |

**Verified-entry conflict (REQ-RCP-014).** If a step resolves to a product
with `status: verified` and the extracted `description`/`brand` similarity to
the verified `name` is < 0.5, or the extracted `unit_size` disagrees, the
verified row is **not** modified. A `product_conflicts` row is written
`{product_id, household_hash, receipt_id, line_item_id, field, verified_value,
observed_value, status: open}`, the line becomes `needs_confirmation` with the
verified product as the sole candidate, and a user confirmation only
increments `products.dispute_count` — never descriptive columns on a verified
row. Resolving
conflicts is a curation action (open question §9.4).

### 3.5 Product lifecycle (REQ-RCP-011 / 013)

```
unverified ──(confirmation_count ≥ 1 from a 2nd household,
              or an authoritative enrichment hit)──▶ pending
pending    ──(confirmation_count ≥ 3 distinct households,
              or authoritative hit + ≥ 1 confirmation)──▶ verified
verified   ── never auto-downgraded; dispute_count ≥ 3 opens a conflict
```

`confidence_score` (0–1) is recomputed on every transition:
`clamp(source_weight + 0.05·confirmation_count − 0.1·dispute_count)` with
weights `gs1_registry 0.9, store_api 0.8, user_scan 0.7, llm_ocr 0.4`
(`gs1_registry` means "UPC verified against GS1", see §3.6).
Distinct households are rows in `product_confirmations (product_id,
household_hash)` — `household_hash` = SHA-256 of household id + server salt,
shape-checked by a constraint — so the shared catalog holds no household
identifiers (NFR-002 AC1). `products.confirmation_count` is the denormalised
count, updated in the same transaction; the primary key makes "once per
household" (REQ-RCP-013 AC1) a constraint rather than application logic.

### 3.6 Enrichment dispatcher (REQ-RCP-009 / 010)

An `enrichment_jobs` row (with one `enrichment_steps` row per adapter run)
drives the adapter chain in order. Discovery adapters stop at the first one
that returns a UPC; the verification adapter then runs on whatever UPC was
found.

**Discovery (name → UPC)**

1. `store_api` — **official retailer APIs only.** Per-chain adapters keyed by
   `store_chains.api_provider`:
   - `kroger` (first adapter, phase 2): Kroger Developer *Products API*, free
     registration, OAuth2 client-credentials, search by term + location, returns
     `upc`. Covers Kroger, Ralphs, Fry's, King Soopers, Smith's, Fred Meyer,
     Harris Teeter, etc. Secrets `KROGER_CLIENT_ID` / `KROGER_CLIENT_SECRET`
     live in Secret Manager (names only in code).
   - `walmart` (follow-up): Walmart.io item search, returns `upc`; requires
     publisher approval, so it ships behind a feature flag.
   - Chains without an official API (H-E-B, Publix, Costco, Target) return
     `not_implemented`. Scraping is out of scope by rule, not by omission:
     heb.com's `robots.txt` disallows `/search`, `/graphql` and `*/ajax/*`, and
     the whole site (even the sitemap) sits behind Imperva bot management. The
     adapter contract forbids circumventing bot protection, ignoring
     `robots.txt`, or using undocumented mobile-app endpoints (ADR-008).
2. `openfoodfacts` → `upcitemdb` — **brand-gated** name search. Measured on
   the H-E-B prototype receipt (`gemini-receipt-prototype.md` → Run 2), an
   unconstrained name search with the current token-overlap matcher
   (`receipt_ocr._is_strong_match`) accepted the wrong brand for 10 of 31
   packaged lines (Lactaid for H-E-B milk, Trader Joe's for Lifeway, Nongshim
   for O'Food …). With the brand as a filter the wrong-brand rate dropped to
   zero. Rules for this step:
   - Query = description minus brand, filtered by `brands:"<brand>"` and
     `countries_tags:"en:united-states"` on the OFF search API
     (`search.openfoodfacts.org/search`, not the rate-limited
     `cgi/search.pl` the legacy path uses). Lines with `brand: null` skip
     name search entirely and go straight to `crowdsourced_pending`.
   - A hit may **auto-link** only if brand matches, the hit's `quantity` is
     compatible with the line's `unit_size` (or either is unknown), and name
     similarity ≥ 0.6. Otherwise the top 3 hits become
     `candidate_product_ids` and the line stays `needs_confirmation`.
   - UPCitemdb runs only when OFF has no brand-matching hit and the brand
     is a national brand (it has essentially no private-label coverage:
     every H-E-B/Central Market/Mi Tienda query returned 404). Its keyless
     trial allows 100 requests/day — enough for the prototype, not for
     production; budget a paid tier or leave it disabled.
   - Hits are `user_scan` grade, never authoritative.
   - **Produce:** bulk produce has no UPC. OFF returns IFPS PLU codes for it
     (`4026` Bosc pear, `4079` cauliflower, `94139` organic Granny Smith),
     so produce lines resolve to `products.product_id = 'plu:<code>'` with
     `code_kind: plu`; these are shared across every chain.

**Verification (UPC → confirmed product)**

3. `gs1_verify` — runs only when a UPC exists (from a discovery hit, scan
   correlation, or a printed code). GS1 lookups are GTIN → product (Verified
   by GS1 / GS1 US Data Hub); they cannot discover a UPC from a name, which
   is why this is a verification step and not first in the chain as the
   kickoff sketched. A confirmed GTIN sets `source: gs1_registry` (weight 0.9)
   and is authoritative for REQ-RCP-011 transitions, as are `store_api` hits.

4. `crowdsourced_pending` — no discovery hit: product stays `unverified` and is
   surfaced to the confirm-haul picker so household confirmations (and the
   forward scan-correlation pass in §3.4) can move it to `pending`.

Runs via Cloud Tasks (`enrichment` queue, rate-limited to respect the
UPCitemdb 100/day free tier and Kroger's 10 000/day quota) or inline in tests.

Why not scrape: beyond the ToS/robots issues, `store_api` carries provenance
weight 0.8 because it is supposed to be an authoritative, legitimately
obtained source. Data scraped through bot-protection evasion would undermine
the provenance story of the shared product DB (ADR-008).

### 3.7 Receipt confirm → inventory + spending (REQ-RCP-015)

`POST /receipts/{rid}/confirm` is the only write into household inventory. For
each line not `rejected`/`skipped`: upsert `inventory_items` (barcode match
first, then name) with `source: receipt`, `price_paid`, `image_url`; create a
`purchases` event `source: receipt`, `store_id`; stamp
`line_items.inventory_item_id/purchase_event_id`; receipt `status: confirmed`.
Confirming also counts as REQ-RCP-013 confirmation for `auto_matched` and
user-resolved lines. This reuses the existing inventory/spending
repositories — no new write paths to Firestore inventory.

### 3.8 Scan events (REQ-RCP-016)

`households/{hid}/scan_events/{id}` replaces the in-memory
`unknown_barcode_log`. Written by `POST /barcodes/{code}` lookups from Add
Items (`context: add_items`) and by trash-station consume (`context:
trash_station`, `outcome: consumed|unknown`). The existing
`GET /inventory/unknown-barcodes` reads `outcome == unknown` from here.

### 3.9 Storage and retention

- Receipt images: bucket `mekasa-receipts-<env>`, object
  `households/{hid}/receipts/{rid}/original.jpg`, uniform bucket-level access,
  no public URLs; API returns short-lived signed URLs only when asked
  (`?include_image_url=true`). Lifecycle rule: delete after 400 days (REQ-015
  AC2 asks for ≥ 12 months of price history; the image is not needed for that
  — see §9.5).
- Raw Gemini responses (REQ-RCP-018): inline in `llm_parse_jobs.attempts[].raw_response`
  when ≤ 200 KB, else `raw_response_gcs_uri` in the same bucket under
  `llm/{job_id}/attempt-{n}.json`. Firestore TTL on `llm_parse_jobs.expires_at`
  = 180 days (open question §9.5).
- Catalog `enrichment_jobs.expires_at` (180 days) is purged by a daily Cloud
  Scheduler `DELETE`; `product_conflicts` are kept until curated; `products`
  are never expired.

### 3.10 Security / privacy

- Every route: `verify_bearer_token` + `assert_household_member` (existing).
- Gemini receives the receipt image only; the system prompt instructs the
  model to **omit** card numbers, loyalty ids, cashier names and phone numbers
  from `raw_text` and to never return them in any field. The validator rejects
  `raw_text` matching a 13–19 digit PAN pattern (defence in depth) — a
  rejected line becomes a corrective retry, not a persisted PII leak.
- No PII in logs: log job ids, counts, error codes, never `raw_text`.
- The shared catalog (Cloud SQL) carries no household or user ids (§3.5);
  `household_hash` columns are constraint-checked to be SHA-256 hex.
  `verified_by_uid` is intentionally absent; curation actions are logged in
  `product_conflicts`/`enrichment_steps` by id only.
- Secrets: one introduced — the catalog connection string, Secret Manager
  `mekasa-database-url`, injected as `DATABASE_URL`; never in files, CI
  variables, or logs. Vertex AI and Cloud Storage use IAM/ADC. Optional
  `UPCITEMDB_API_KEY` and the Kroger client credentials stay in Secret Manager
  (ADR-006, §3.6).

---

## 4. Data model — summary (Firestore for household data, Cloud SQL for the shared catalog)

Two stores, one rule: anything owned by a household is a Firestore document
under `households/{hid}` (real-time sync, offline cache, existing security
model); anything shared by all accounts is a Postgres table in the catalog
database (`backend/postgres/`). They reference each other only by opaque string
ids, and the catalog never stores a household or user id.

Full field tables: `backend/firestore/migrations/0001_receipt_parser.md` +
`backend/firestore/schema/` (Firestore) and
`backend/postgres/migrations/0001_shared_products.sql` (Postgres; column comments are the
documentation).

| Kickoff table | Location | Notes |
|---|---|---|
| `stores` | existing `households.store_ids` (Places ids, Firestore) **+ new** table `store_chains` (Postgres) | Chain is what the prompt, matching, and `store_api` adapter selection need; Places store keeps the physical location for REQ-015 AC3. Seed: `backend/postgres/seed/store_chains.sql` |
| `products` | **new** table `products` (Postgres) | `product_id` = UPC when known, else `plu:<code>` / `llm:<sha1>` — enforced by a `CHECK`; `UNIQUE (upc)`; kickoff fields + `brand`, `unit_size`, `image_url`, `dispute_count`, provenance, `superseded_by` |
| — | **new** table `product_aliases` (Postgres) | `(store_chain_id, alias) → product_id`; alias must equal `catalog_normalize_name(alias)`; trigram index |
| — | **new** table `product_confirmations` (Postgres) | `(product_id, household_hash)` primary key = once per household |
| `receipts` | **new** `households/{hid}/receipts/{rid}` (Firestore) | household-scoped |
| `receipt_line_items` | **new** `households/{hid}/receipts/{rid}/line_items/{lid}` (Firestore) | `raw_text`, `price`, `qty`, `matched_product_id` (nullable key into `products`) + resolution fields |
| `scan_events` | **new** `households/{hid}/scan_events/{id}` (Firestore) | supersedes in-memory unknown-barcode log |
| `llm_parse_jobs` | **new** `llm_parse_jobs/{job_id}` (Firestore, top-level) | ops need cross-household queries by status/prompt_version; raw Gemini output lives here / in GCS |
| — | **new** tables `enrichment_jobs`, `enrichment_steps`, `product_conflicts` (Postgres) | dispatcher state and REQ-RCP-014 records; both hang off `products` with foreign keys |

Additions to existing Firestore documents (all optional, backwards compatible):

- `households/{hid}/inventory_items`: `product_id`, `receipt_line_item_id`
- `households/{hid}/purchases`: `receipt_id`, `receipt_line_item_id`, `product_id`

Catalog access (phase 2): `psycopg` 3 + `psycopg_pool` behind
`products_repository`; Cloud Run connects over the Cloud SQL Unix socket with
`DATABASE_URL` from Secret Manager `mekasa-database-url` (instance `mekasa-pg`,
database `mekasa`, user `mekasa_api`); `DATABASE_URL` unset → in-memory.
Migrations are idempotent SQL applied with `psql`. `backend/postgres/README.md`
has the commands.

### 4.1 Catalog transactions

Two write paths touch shared rows; both are single transactions in
`products_repository`, never a sequence of independent statements.

**Receipt save (after resolution, per receipt).** One transaction covers
every line of the receipt:

```sql
BEGIN;
SELECT pg_advisory_xact_lock(hashtext($store_chain_id));   -- serialises saves per chain
-- per line: upsert product (llm: rows) …
INSERT INTO products (...) VALUES (...)
  ON CONFLICT (product_id) DO UPDATE SET last_seen_at = now();
-- … and its alias
INSERT INTO product_aliases (store_chain_id, alias, product_id)
  VALUES ($chain, catalog_normalize_name($raw_text), $product_id)
  ON CONFLICT (store_chain_id, alias) DO UPDATE
    SET seen_count = product_aliases.seen_count + 1, last_seen_at = now()
    WHERE product_aliases.product_id = EXCLUDED.product_id;           -- never re-point (§9.11)
-- enrichment job for new llm: rows (partial unique index makes this idempotent)
INSERT INTO enrichment_jobs (product_id, trigger, chain) VALUES (...) ON CONFLICT DO NOTHING;
COMMIT;
```

The advisory lock is chain-scoped, not global: two households saving Kroger
and H-E-B receipts run in parallel; two saving H-E-B receipts run one after
the other, so neither can observe the other's half-written alias set. Receipt
saves are seconds apart per chain even at scale, so serialising them costs
nothing measurable; if it ever does, the lock narrows to
`hashtext(store_chain_id || alias)` per line. Firestore-side writes (line
items' `matched_product_id`) happen after this commit and only reference ids
that now exist.

**Re-key `llm:` → UPC (REQ-RCP-010 AC2; enrichment hit or forward scan
correlation).** Also one transaction:

```sql
BEGIN;
SELECT * FROM products WHERE product_id IN ($llm_id, $upc) FOR UPDATE;
INSERT INTO products (product_id, code_kind, upc, ...)                 -- create or merge into the UPC row
  SELECT $upc, 'upc', $upc, store_chain_id, name, normalized_name, brand, category, unit_size, image_url,
         $source, array_append(sources_seen, $source), $confidence, confirmation_count, dispute_count, ...
  FROM products WHERE product_id = $llm_id
  ON CONFLICT (product_id) DO UPDATE SET
    confirmation_count = products.confirmation_count + EXCLUDED.confirmation_count,
    dispute_count      = products.dispute_count + EXCLUDED.dispute_count,
    sources_seen       = (SELECT array_agg(DISTINCT s) FROM unnest(products.sources_seen || EXCLUDED.sources_seen) s),
    last_seen_at       = greatest(products.last_seen_at, EXCLUDED.last_seen_at);
UPDATE product_aliases SET product_id = $upc WHERE product_id = $llm_id;
  -- cannot collide: (store_chain_id, alias) is the PK, so no alias is on both rows
INSERT INTO product_confirmations (product_id, household_hash, confirmed_at)
  SELECT $upc, household_hash, confirmed_at FROM product_confirmations WHERE product_id = $llm_id
  ON CONFLICT DO NOTHING;                                              -- same household counted once
UPDATE products SET confirmation_count = (SELECT count(*) FROM product_confirmations WHERE product_id = $upc)
  WHERE product_id = $upc;                                             -- recount after the merge
UPDATE products SET superseded_by = $upc WHERE product_id = $llm_id;
COMMIT;
```

`FOR UPDATE` on both rows keeps a concurrent confirmation from landing on the
`llm:` row between the copy and the `superseded_by` stamp. The old row stays
(so existing `matched_product_id` strings in Firestore still resolve — readers
follow `superseded_by`); nothing is deleted, so a failure anywhere simply
rolls back to the pre-re-key state.

**Reviewing the catalog** needs no new indexes, just SQL — e.g. open
conflicts per chain:

```sql
SELECT p.store_chain_id, p.name, c.field, c.verified_value, c.observed_value, c.created_at
FROM product_conflicts c JOIN products p USING (product_id)
WHERE c.status = 'open' AND p.store_chain_id = 'heb' ORDER BY c.created_at DESC;
```

---

## 5. API contract — summary

Full contract: `docs/api/receipt-parser.openapi.yaml`. All routes under
`/v1/households/{household_id}` unless noted; bearer auth; 403 for non-members.

| Method | Path | Purpose |
|---|---|---|
| POST | `/receipts?wait_seconds=` | Upload (image_base64 or raw_text, optional store_id) → 200 parsed / 202 parsing |
| GET | `/receipts` | List receipts (status filter, cursor) |
| GET | `/receipts/{rid}` | Receipt + line items + parse job summary |
| GET | `/receipts/{rid}/parse-job` | Job status/attempts (raw responses omitted unless `?include_raw=true`, owner only) |
| POST | `/receipts/{rid}/reparse` | Owner re-runs the parse (new job) |
| GET | `/receipts/{rid}/line-items/{lid}/candidates` | Product candidates for the picker (`q` override) |
| POST | `/receipts/{rid}/line-items/{lid}/resolve` | Link to product / UPC / candidate / manual entry → `confirmed` |
| POST | `/receipts/{rid}/line-items/{lid}/reject` | Not a product / skip |
| PATCH | `/receipts/{rid}/line-items/{lid}` | Edit qty, price, category, description before confirm |
| POST | `/receipts/{rid}/confirm` | Write inventory + purchase events |
| GET | `/scan-events` | Recent scan events (debug/trash-station log) |
| GET | `/v1/products/{product_id}` | Shared product read (any signed-in user) |
| GET | `/v1/products/search?q=&store_chain_id=` | Shared product search for pickers |
| POST | `/v1/internal/parse-jobs/{job_id}/run` | Cloud Tasks target (OIDC, not for clients) |
| POST | `/receipts/scan` | **Deprecated** alias → `wait_seconds=45`, legacy response |

---

## 6. Prompt and schema contract (v1)

`backend/prompts/receipt_parse/v1/`

- `system.md` — system prompt; only placeholder allowed: `{{store_chain_name}}`.
- `corrective.md` — retry turn; placeholders `{{validation_errors}}`, `{{attempt}}`.
- `response.schema.json` — Draft 2020-12; used both as Vertex `response_schema`
  and for server-side validation.
- `CHANGELOG.md` — one entry per version; `prompt_version` recorded on jobs is
  `receipt_parse/v1` and `prompt_sha256` is the hash of `system.md` so silent
  edits are detectable (REQ-RCP-017).

Changing the prompt or schema = new directory `v2/` (never edit `v1/` after it
has produced jobs). Phase 2 adds `scripts/lint_prompts.py` to CI enforcing:
required files, placeholder whitelist, schema meta-validation, fixture
validation, no secret-like tokens.

---

## 7. Testing strategy (phase 2 stubs; mapping for review)

| Test (tests/backend/) | Satisfies |
|---|---|
| `test_receipt_parser_happy_path.py` — fake Gemini returns valid JSON; 200 with lines; products created; job `succeeded` with prompt_version | REQ-RCP-001/002/003/006/009/011/017/018 |
| `test_receipt_parser_retry_and_failure.py` — fake returns malformed → corrective retry ×2 → `failed`, receipt `needs_review`, fallback lines present, 3 attempts with raw responses | REQ-RCP-004/005/018 |
| `test_receipt_scan_correlation.py` — scan event 10 min earlier → line inherits UPC, event stamped | REQ-RCP-008/016 |
| `test_receipt_low_confidence_confirmation.py` — fuzzy 0.6 → `needs_confirmation`; `resolve` → `confirmed`, `confirmation_count` +1 | REQ-RCP-007/012/013 |
| `test_receipt_verified_conflict.py` — verified product, contradicting extraction → verified doc unchanged, `product_conflicts` written, line needs confirmation | REQ-RCP-014 |
| `test_receipt_confirm_writes_inventory.py` | REQ-RCP-015, REQ-005 AC3, REQ-015 |
| `test_enrichment_dispatcher.py` — adapter order + stop-at-first-authoritative | REQ-RCP-010 |
| `test_prompt_contract.py` — schema meta-valid, fixtures validate, placeholder whitelist | REQ-RCP-003/017 |
| `test_products_repository_postgres.py` — skipped unless `TEST_DATABASE_URL` points at a scratch database (CI `services: postgres:16`): applies `0001_shared_products.sql` twice + seed, unique `upc`, alias PK, once-per-household confirmation, verified-evidence `CHECK`, one live enrichment job per product, trigram fuzzy search, §4.1 re-key transaction, `.down.sql` | REQ-RCP-007/009/011/013/014 |

Gemini is behind a `ReceiptLLMClient` protocol; tests use
`FakeReceiptLLMClient` scripted from `tests/backend/fixtures/gemini/*.json`.
No test ever calls Vertex AI. All other tests run with `DATABASE_URL` unset
(in-memory repository); the `test-backend` CI job gains a
`services: postgres:16` container and sets `TEST_DATABASE_URL` so the Postgres
repository tests and the DDL are exercised on every PR (phase 2).

---

## 8. Architecture decisions (summarised; full text in `docs/architecture.md`)

- **ADR-007 — Gemini on Vertex AI for receipt parsing (supersedes the OCR+regex
  half of ADR-003).** Vertex over public Gemini API: IAM/ADC instead of API
  keys, data-residency and enterprise terms, same project/billing. Whole
  receipt in one call: line context (multi-line descriptions, discounts that
  apply to the previous line) is what regex parsing loses. Cloud Vision stays
  as the fallback engine.
- **ADR-008 — Shared, provenance-tracked product catalog on Cloud SQL for
  PostgreSQL (revised 2026-09-29).** One catalog for all accounts: `products`
  keyed by UPC, `product_aliases`, `product_confirmations`, `store_chains`,
  `enrichment_jobs`/`enrichment_steps`, `product_conflicts`. Postgres rather
  than a Firestore collection because the catalog's rules are uniqueness and
  similarity — `UNIQUE (upc)`, one product per alias per chain, once-per-
  household confirmations, verified-requires-evidence — which are constraints
  in SQL and application code in Firestore, and `pg_trgm` gives real fuzzy
  matching. Household data stays in Firestore (ADR-002a's real-time/offline
  reasons apply there, not to a server-only catalog). Costs accepted: a
  second database to run, ~US$10/month always-on, no realtime listeners on
  shared data (served via the API anyway); ADR-002a amended, not replaced.
  Connection over the `/cloudsql` socket with `DATABASE_URL` from Secret
  Manager; in-memory repository when unset. Households are never stored in
  the catalog.
  Retailer data enters only through official APIs; scraping behind bot
  protection or against `robots.txt` is prohibited.
- Single Cloud Run service + Cloud Tasks, not separate Cloud Functions —
  keeps one auth path, one persistence switch, one test harness.
- Async-first contract with bounded sync wait — protects mobile UX and Cloud
  Run concurrency while letting today's clients stay synchronous.

---

## 9. Open questions (need answers before or during phase 2)

1. **Model**: `gemini-2.5-pro` (accuracy) vs `gemini-2.5-flash` (~10× cheaper,
   ~3× faster)? Proposal: Pro for v1, measure, then A/B by `prompt_version`.
2. **Store chain detection**: when a household has several `store_ids`, do we
   (a) require the client to pass `store_id`, (b) let Gemini detect the chain
   from the header and reconcile, or (c) both (proposed: c, client hint wins).
3. **Verification thresholds** in §3.5 (3 distinct households; authoritative +
   1) — acceptable, or should `verified` require a human curator in v1?
4. **Conflict curation**: who resolves `product_conflicts`? Proposal: a
   `GET/POST /v1/admin/product-conflicts` behind a `curator` claim, out of
   scope here.
5. **Retention**: receipt images 400 days; raw Gemini JSON 180 days via
   Firestore TTL. Shorter? Also confirm Cloud Storage bucket naming and
   whether an `enrichment` Cloud Tasks queue may be created in
   `hackathon2025-472017`.
6. **Weighted items**: produce sold by weight (`1.32 lb @ 0.99/lb`) — schema
   models `qty` as decimal with `unit`; inventory `quantity` is `int`.
   Proposal: `qty` rounds to 1 for inventory, keep exact value on the line item.
7. **Legacy alias lifetime**: remove `POST /receipts/scan` once both apps use
   `/receipts`, or keep indefinitely?
8. **Receipt duplicates**: same image uploaded twice → reject by content hash
   within 24 h (proposed) or allow and let user delete?
9. **Currency**: assume `USD` for v1 (matches `SpendingReportResponse`)?
10. **Cloud SQL sizing/network**: `mekasa-pg` as `db-f1-micro`, zonal, socket
    access only (no authorised networks) for dev. Move to private IP +
    Serverless VPC connector, or to IAM database authentication (drops the
    password from `mekasa-database-url`), for prod?
11. **Alias uniqueness**: `product_aliases` makes a printed alias map to one
    product per chain. When the same text is later confirmed to a different
    product (e.g. `HEB MILK` for whole vs 2 %), proposal: keep the first
    mapping, record a `product_conflicts` row with `field: name`, and let the
    picker show both — or drop the alias and fall through to fuzzy?

---

## 10. Rollout

1. Phase 1: docs, schema, contract, prompt v1 — review pause. Revision: shared
   catalog on Cloud SQL (`0001_shared_products` idempotent DDL, validated
   locally on Postgres 16: apply twice, constraint checks, §4.1 transactions,
   rollback, re-apply).
2. Phase 2: repositories + services + routes behind `RECEIPT_PARSER=gemini|legacy`
   (default `legacy` until Vertex IAM is granted), test stubs, CI lint, and a
   `services: postgres:16` container on the `test-backend` job applying
   `0001_shared_products` + seed on every PR.
3. Migrations: `0001_shared_products` (create instance `mekasa-pg`, database
   `mekasa`, user `mekasa_api`, secret `mekasa-database-url`, `psql -f`, seed
   `store_chains` — `backend/postgres/README.md`)
   and `0001_receipt_parser` (deploy indexes, create bucket + queues, grant
   `roles/aiplatform.user`); no data backfill required.
4. Flip `RECEIPT_PARSER=gemini` on dev; clients adopt `/receipts` +
   line-item resolution; deprecate `/receipts/scan`.
