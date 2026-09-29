# Design — Gemini-Based Receipt Scanner for the UPC Product Database

Spec version: 1.0 (adds REQ-RCP-001 … REQ-RCP-018)
Status: **Draft — awaiting review after data model + API contract (phase 1)**
Owner: backend
Related: ADR-002a (Firestore), ADR-003 (server-side OCR), ADR-004 / ADR-006
(UPC + image waterfall), ADR-007 (this design), ADR-008 (shared product DB)

---

## 0. Review checklist (what this phase asks you to decide)

Phase 1 deliverables are in this PR. Nothing under `backend/app/` changes yet.

| # | Deliverable | Where |
|---|-------------|-------|
| 1 | Data model + migration `0001_receipt_parser` | `backend/firestore/migrations/0001_receipt_parser.md`, `backend/firestore/schema/*.schema.json`, `backend/firestore/firestore.indexes.json` |
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
- Grow a **shared UPC product database** (`products`) from receipts, barcode
  scans, and enrichment sources, with provenance (`source`), a
  `confidence_score`, `confirmation_count`, and a `status` lifecycle
  `unverified → pending → verified`.
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
  API -->|2. create receipt + llm_parse_job| FS[(Firestore mekasa-db)]
  API -->|3. run job (in-request, wait_seconds)\nor enqueue| Tasks[Cloud Tasks\nreceipt-parse queue]
  Tasks -->|POST /internal/parse-jobs/{id}/run| API
  API -->|4. generate_content\nsystem prompt v1 + image| Vertex[Vertex AI\nGemini Pro]
  API -->|5. validate → retry ≤2| API
  API -->|6. persist line_items,\nraw response| FS
  API -->|7. match / correlate| FS
  API -->|8. enrichment_jobs| Tasks
  API -->|store API (Kroger) → UPCitemdb/OFF → GS1 verify| Ext[Enrichment sources]
  Client -->|GET receipt / resolve / confirm| API
```

### 3.1 Components (all inside the existing Cloud Run service)

| Component | Module (phase 2) | Responsibility |
|-----------|------------------|----------------|
| Receipt ingestion | `app/receipts_router.py`, `app/receipts_repository.py` | Auth + household membership, store image, create `receipts/{id}` and `llm_parse_jobs/{id}`, sync-wait or enqueue |
| Gemini invocation | `app/gemini_receipt_parser.py` | Build request from versioned prompt, call Vertex AI, validate, corrective retry, persist attempts + raw JSON |
| Matching / resolution | `app/product_resolver.py` | UPC → scan correlation → alias → fuzzy; confidence thresholds; verified-conflict guard |
| Enrichment dispatcher | `app/enrichment_dispatcher.py` | Create `enrichment_jobs`, run adapter chain, upgrade product `source`/`status` |
| Products repository | `app/products_repository.py` | Shared `products` + `store_chains`; status transitions; confirmation counting |
| Scan events | `app/scan_events_repository.py` | Replaces in-memory `unknown_barcode_log` with a persisted household subcollection |

One service, not separate Cloud Functions: keeps auth, Firestore clients, and
the memory/Firestore persistence switch (`HOUSEHOLD_PERSISTENCE`) that all
tests rely on. Cloud Tasks targets an internal route on the same service
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
   `products/{upc}` for any chain (Walmart, Costco print item numbers; mapping
   table per chain is in `store_chains.receipt_code_kind`).
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
3. **alias** — `products` where `store_chain_id == chain` and
   `receipt_aliases array_contains normalized(raw_text)`. Confidence 0.95.
4. **fuzzy** — `products` where `store_chain_id == chain` and
   `name_tokens array_contains_any top-3 tokens`; scored by Jaccard on token
   sets; take best if ≥ 0.5.
5. **none** → REQ-RCP-009: create `products/llm:{sha1(chain|normalized_name)}`
   with `source: llm_ocr`, `status: unverified`, `confidence_score` = Gemini
   line confidence × 0.6, and dispatch an `enrichment_jobs` doc.

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
verified document is **not** modified. A `product_conflicts/{id}` doc is
written `{product_id, receipt_id, line_item_id, field, verified_value,
observed_value, status: open}`, the line becomes `needs_confirmation` with the
verified product as the sole candidate, and a user confirmation only
increments `products.dispute_count` — never fields on a verified doc. Resolving
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
Households are counted via a hashed `confirming_household_hashes[]`
(SHA-256 of household id + server salt) so the shared collection holds no
household identifiers (NFR-002 AC1).

### 3.6 Enrichment dispatcher (REQ-RCP-009 / 010)

`enrichment_jobs/{id}` runs the adapter chain in order. Discovery adapters
stop at the first one that returns a UPC; the verification adapter then runs
on whatever UPC was found.

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
2. `upcitemdb` → `openfoodfacts` — name search (ADR-004/006 waterfall, reusing
   `barcode_lookup.py`). Hits are `user_scan` grade, not authoritative.

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

### 3.10 Security / privacy

- Every route: `verify_bearer_token` + `assert_household_member` (existing).
- Gemini receives the receipt image only; the system prompt instructs the
  model to **omit** card numbers, loyalty ids, cashier names and phone numbers
  from `raw_text` and to never return them in any field. The validator rejects
  `raw_text` matching a 13–19 digit PAN pattern (defence in depth) — a
  rejected line becomes a corrective retry, not a persisted PII leak.
- No PII in logs: log job ids, counts, error codes, never `raw_text`.
- Shared `products`/`store_chains` collections carry no household or user ids
  (§3.5). `verified_by_uid` is intentionally absent; curation actions are
  logged in `product_conflicts`/`enrichment_jobs` by job id only.
- Secrets: none introduced. Vertex AI and Cloud Storage use ADC. Optional
  `UPCITEMDB_API_KEY` stays in Secret Manager (ADR-006).

---

## 4. Data model (Firestore) — summary

Full field tables and JSON Schemas: `backend/firestore/migrations/0001_receipt_parser.md`
and `backend/firestore/schema/`.

| Kickoff table | Firestore location | Notes |
|---|---|---|
| `stores` | existing `households.store_ids` (Places ids) **+ new** `store_chains/{chain_id}` | Chain is what the prompt, matching, and `store_api` adapter selection need; Places store keeps the physical location for REQ-015 AC3 |
| `products` | **new** `products/{product_id}` (top-level, shared) | id = UPC when known, else `llm:<sha1>`; fields exactly as the kickoff + `image_url`, `receipt_aliases`, `name_tokens`, `dispute_count`, provenance |
| `receipts` | **new** `households/{hid}/receipts/{rid}` | household-scoped |
| `receipt_line_items` | **new** `households/{hid}/receipts/{rid}/line_items/{lid}` | `raw_text`, `price`, `qty`, `matched_product_id` nullable + resolution fields |
| `scan_events` | **new** `households/{hid}/scan_events/{id}` | supersedes in-memory unknown-barcode log |
| `llm_parse_jobs` | **new** `llm_parse_jobs/{job_id}` (top-level) | ops need cross-household queries by status/prompt_version |
| — | **new** `enrichment_jobs/{id}`, `product_conflicts/{id}` | dispatcher state, REQ-RCP-014 records |

Additions to existing documents (all optional, backwards compatible):

- `households/{hid}/inventory_items`: `product_id`, `receipt_line_item_id`
- `households/{hid}/purchases`: `receipt_id`, `receipt_line_item_id`, `product_id`

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

Gemini is behind a `ReceiptLLMClient` protocol; tests use
`FakeReceiptLLMClient` scripted from `tests/backend/fixtures/gemini/*.json`.
No test ever calls Vertex AI.

---

## 8. Architecture decisions (summarised; full text in `docs/architecture.md`)

- **ADR-007 — Gemini on Vertex AI for receipt parsing (supersedes the OCR+regex
  half of ADR-003).** Vertex over public Gemini API: IAM/ADC instead of API
  keys, data-residency and enterprise terms, same project/billing. Whole
  receipt in one call: line context (multi-line descriptions, discounts that
  apply to the previous line) is what regex parsing loses. Cloud Vision stays
  as the fallback engine.
- **ADR-008 — Shared, provenance-tracked product database.** One top-level
  `products` collection keyed by UPC, grown from receipts/scans/enrichment;
  households are never stored on product docs. Firestore rather than Cloud
  SQL (consistent with ADR-002a) — the matching queries needed are
  equality + `array_contains` on a chain-scoped subset, which Firestore
  handles with the composite indexes in `firestore.indexes.json`.
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

---

## 10. Rollout

1. Phase 1 (this PR): docs, schema, contract, prompt v1 — review pause.
2. Phase 2: repositories + services + routes behind `RECEIPT_PARSER=gemini|legacy`
   (default `legacy` until Vertex IAM is granted), test stubs, CI lint.
3. Migration `0001_receipt_parser`: deploy indexes, create bucket + queues,
   grant `roles/aiplatform.user`; no data backfill required (all new
   collections/optional fields).
4. Flip `RECEIPT_PARSER=gemini` on dev; clients adopt `/receipts` +
   line-item resolution; deprecate `/receipts/scan`.
