# MEKASA — Architecture Document v1.0

## 1. System Overview
Mekasa consists of two native mobile clients (Android/Jetpack Compose
and iOS/SwiftUI), a GCP-based backend REST API served via Cloud Run,
and a real-time sync layer via Cloud Firestore; the account-wide
product catalog shared by all households lives in Cloud SQL for
PostgreSQL (ADR-008). All clients communicate
through the same API, making future desktop clients straightforward
to add without any SDK dependency changes.

---

## 2. Component Diagram

```mermaid
graph TD
  AndroidApp[Android App\nJetpack Compose]
  iOSApp[iOS App\nSwiftUI]
  API[Cloud Run API\nREST]
  DB[(Cloud Firestore\nHousehold data)]
  Catalog[(Cloud SQL — PostgreSQL\nShared product catalog)]
  OCR[Cloud Vision API\nReceipt OCR fallback]
  Gemini[Vertex AI — Gemini Pro\nReceipt line-item extraction]
  Tasks[Cloud Tasks\nreceipt-parse / enrichment queues]
  Barcode[Third-Party Barcode API\nUPC / Open Food Facts]
  ImageAPI[Open Food Facts / UPC ItemDB\nImage API]
  Places[Google Places API\nStore Discovery]
  Secrets[GCP Secret Manager]
  Storage[Cloud Storage\nHome Photos · Receipt images]

  AndroidApp --> API
  iOSApp --> API
  API --> DB
  API --> Catalog
  API --> Gemini
  API --> Tasks
  Tasks --> API
  API --> OCR
  API --> Barcode
  API --> ImageAPI
  API --> Places
  API --> Secrets
  API --> Storage
```

---

## 3. Data Flows

### Barcode Scan Flow
Mobile client captures barcode → sends UPC to API → API queries
third-party barcode database (Open Food Facts primary) → returns
product name, category, estimated price, and `image_url` → client
confirms → API writes item + image URL to Firestore → real-time
sync pushes to all household devices → inventory list shows
thumbnail; item detail shows large image (tap to enlarge)

### Inventory Browse Flow
Dashboard / Inventory Screen shows rows with product thumbnails
(from stored `image_url` or category placeholder) → user taps row
→ Item Detail shows large product image, name, category, UPC,
quantity, and low-stock threshold → tap image opens full-screen
lightbox → back returns to list

### Receipt Scan Flow (ADR-007; design/gemini-receipt-parser.md)
Mobile client captures receipt image → `POST /receipts` → API stores
image in Cloud Storage, creates `receipts` + `llm_parse_jobs` → Gemini
(Vertex AI) extracts all line items in one call → response validated
against the versioned JSON schema (corrective retry ≤ 2, then Cloud
Vision + regex fallback) → line items persisted → matched against the
shared `products` database (UPC → scan-event correlation → alias →
fuzzy, all in the Cloud SQL catalog) → unmatched lines create
`llm_ocr` products + enrichment jobs →
client reviews / resolves low-confidence lines → `POST /confirm`
writes inventory items + purchase events to Firestore → sync pushes
to all household devices

### Trash Station Flow
Dedicated device scans barcode → sends to API → API decrements
quantity for matching household item → if below threshold,
auto-adds to shopping list → sync pushes to all household devices

### Onboarding Address + Store Flow
Client requests GPS → reverse geocode via API → present suggested
address to user → user confirms or edits → API queries Places
within 15-mile radius → returns store list → user selects
preferred stores → stored in household profile

### Request Approval Flow
Member submits request → API writes to Firestore in pending state →
Owner receives push notification → Owner approves/rejects/questions →
API updates record → sync notifies all devices → member receives
result notification

---

## 4. Security Model
- All API endpoints require JWT authentication
- Household data is scoped by household_id — cross-household access
  is impossible by design
- All secrets (API keys, DB credentials) stored in GCP Secret Manager
- No PII in application logs
- Role enforcement (Owner vs. Member) enforced server-side, not client-side

---

## 5. Architecture Decision Records (ADR)

### ADR-001: Native Mobile over Cross-Platform
Date: 2026-08-17
Status: Accepted
Decision: Build Android in Jetpack Compose and iOS in SwiftUI
rather than using a cross-platform framework like React Native
or Flutter.
Rationale: Native provides the best performance and user
experience for a scan-heavy, real-time app. Jetpack Compose
and SwiftUI are both mature, modern, and fully programmatic.
The household inventory use case benefits from tight OS
integration (camera, notifications, background sync).
Trade-off: Two separate codebases to maintain. Mitigated by
shared API contract and consistent business logic on the backend.

### ADR-002: GCP Backend over Firebase
Date: 2026-08-17
Status: Accepted
Decision: Use a custom GCP Cloud Run REST API rather than
Firebase as the primary backend.
Rationale: GCP backend is platform-agnostic — future Windows
desktop or web clients can connect without any SDK dependency.
Provides full control over business logic, pricing, and scaling.
Firestore can still be used as the database layer.
Trade-off: More initial setup than Firebase. Mitigated by
Cloud Run's simplicity and prior GCP experience from FALLOUT.

### ADR-002a: Firestore over Cloud SQL as the Database Layer
Date: 2026-09-06
Status: Accepted; amended 2026-09-29 — Firestore for household data;
Postgres for cross-account shared catalog data (ADR-008)
Decision: Use Cloud Firestore as the primary database rather
than Cloud SQL (PostgreSQL).

Context: Mekasa stores household inventory items, receipt OCR
line items, trash station events, child request queues, store
discovery data, and family member profiles. Multiple family
members on different devices interact with the same household
data concurrently.

Options considered:

**Option A — Cloud Firestore (Document DB)**
- Real-time multi-device sync built in — all family members see
  inventory changes instantly without polling
- Offline support built in — local cache keeps the app usable
  without a connection; syncs automatically on reconnect
- Flexible document schema — receipt OCR results vary widely by
  store and format; a document model handles irregular structures
  better than rigid columns
- Native mobile SDKs with live listeners — ideal for reactive
  Jetpack Compose and SwiftUI UI patterns
- No schema migrations — new fields can be added without
  `ALTER TABLE`; supports rapid early iteration
- Already in the GCP org — no additional infrastructure, same
  billing and IAM
- Weakness: Limited ad-hoc querying — no joins, no arbitrary
  `WHERE` clauses across collections
- Weakness: Spending reports and category rollups require either
  denormalized data or aggregation via Cloud Functions

**Option B — Cloud SQL (PostgreSQL)**
- Complex queries trivial — spending reports, category rollups,
  date-range analytics are standard SQL
- Relational integrity enforced at DB level — foreign keys between
  items, receipts, and line items
- Familiar tooling — standard SQL, easy to inspect and debug
- Weakness: No real-time push — polling or a separate Pub/Sub
  layer required for live family sync; significant custom work
- Weakness: No built-in offline support — must be built separately
  or omitted
- Weakness: Schema migrations required for every new field —
  slower iteration in early development
- Weakness: Cloud SQL instance runs 24/7 even when idle — higher
  baseline cost for a household-scale app

Rationale: Real-time multi-device sync and offline support are
core requirements for Mekasa — they are what makes a household
inventory app actually usable by a family on the go. Firestore
provides both for free. Replicating them on Cloud SQL would
require significant custom engineering with no functional
advantage for this use case.

The one Firestore weakness — spending analytics — is resolved by
a Cloud Function that aggregates spending totals into a
`spending_summaries` collection on every confirmed receipt save.
Reporting screens read from this pre-aggregated collection rather
than running live queries across raw line-item documents.

Trade-off: Spending report logic requires Cloud Function
aggregation rather than live SQL queries. Acceptable given that
spending reports are low-frequency reads, not real-time views.

### ADR-003: Server-Side Receipt OCR
Date: 2026-08-17
Status: Accepted
Decision: Receipt OCR processing is done server-side via
Google Cloud Vision rather than on-device.
Rationale: Server-side OCR is significantly more accurate for
receipts, which vary widely in format, font, and print quality.
On-device ML Kit is sufficient for barcodes but not for
unstructured receipt text.
Trade-off: Requires network connectivity for receipt scanning.
Acceptable since receipt scanning is not a core offline use case.

### ADR-004: Third-Party Barcode Database
Date: 2026-08-17
Status: Accepted
Decision: Use a third-party barcode/UPC database API (e.g.,
Open Food Facts, UPC ItemDB) rather than building our own.
Rationale: Third-party databases have millions of products
already indexed. Building and maintaining our own is not
justified for v1.0. Our own database grows organically as
users scan items not found in the third-party source.
Trade-off: Dependency on third-party availability and coverage.
Mitigated by a manual entry fallback for unknown barcodes.

### ADR-005: GPS + Reverse Geocoding for Store Discovery
Date: 2026-08-17
Status: Accepted
Decision: Use device GPS plus reverse geocoding to detect home
address during onboarding, then query Google Places API within
a 15-mile radius for nearby stores.
Rationale: Eliminates manual store entry, improves price
estimation accuracy by localizing to the user's actual
shopping area, and creates a better out-of-box experience.
Trade-off: Requires location permission. Mitigated by clear
explanation during onboarding and a manual address entry
fallback if permission is denied.

### ADR-006: UPC Product Image Lookup Strategy
Date: 2026-09-08
Status: Accepted
Decision: Retrieve product images using a three-step waterfall:
(1) Open Food Facts, (2) UPC ItemDB, (3) category placeholder.
All lookups are performed server-side in the Cloud Run API.

Context: After a barcode scan, Mekasa already resolves product
name and category via a third-party UPC database (ADR-004). Users
also need a product image next to each inventory item. Image
lookup must stay on the Cloud Run API so API keys stay in Secret
Manager and waterfall retry logic is centralized—never called
directly from mobile clients.

Options considered:

**Option A — Open Food Facts**
- Free, no API key required, open source
- Best for food and grocery items (~3 million products globally)
- Returns `image_url` and `image_front_url` fields
- Endpoint: `https://world.openfoodfacts.org/api/v0/product/{barcode}.json`
- Weakness: Community-contributed photos, variable quality
- Weakness: Limited coverage for non-food household items

**Option B — UPC ItemDB**
- Free up to 100 requests/day; paid plans above that
- General retail coverage beyond food (~1.5 million products)
- Returns `items[0].images[]` array
- Weakness: 100/day free tier may be limiting at scale
- Weakness: Requires an API key (must live in GCP Secret Manager)

**Option C — Nutritionix**
- Free for modest usage
- Strong on branded US grocery items
- Includes nutrition data as a bonus
- Weakness: Food-only, not general retail

**Option D — Google Cloud Vision Web Detection**
- Already in the Mekasa GCP stack (used for receipt OCR)
- Image-first matching: user photo → similar product images on
  the web — useful when no UPC database returns an image
- Weakness: Not a UPC lookup — requires an image as input, not a
  barcode string
- Weakness: Higher per-call cost than static database lookups

Rationale: A three-step waterfall maximizes free coverage for
grocery scans while keeping a second source for non-food retail
and a deterministic UI fallback. Open Food Facts is primary
because it needs no key and will resolve most household food
scans at zero cost. UPC ItemDB is the secondary step for broader
retail coverage when Open Food Facts has no image. Category
placeholders guarantee every inventory row still shows something
useful. Cloud Vision Web Detection is deferred to a future ADR
until production coverage proves insufficient, avoiding Vision
API cost in v1.0.

Implementation Notes:
- Image lookup handler: `api/handlers/image_lookup.py`
- Category placeholder map: `api/config/category_icons.py`
- Secret name for UPC ItemDB key: `UPCITEMDB_API_KEY`
- Waterfall must be a single internal function:
  `get_product_image(upc: str, category: str) -> str`
  returning a URL in all cases — never `None` or an exception
- Add `UPCITEMDB_API_KEY` to the Secret Manager setup
  instructions in `docs/runbook.md` when that file is created
  (`docs/runbook.md` does not exist yet)

Trade-off: Two external API dependencies instead of one.
Mitigated by Open Food Facts requiring no key and UPC ItemDB
free tier being sufficient for household-scale usage.

### ADR-007: Gemini on Vertex AI for Receipt Line-Item Extraction
Date: 2026-09-26
Status: Proposed (phase-1 review; supersedes the "OCR + heuristic
parsing" half of ADR-003 — server-side processing itself stands)
Decision: Parse receipts with Gemini Pro invoked through the Vertex
AI SDK, sending the whole receipt image in a single request with a
versioned system prompt and a JSON response schema. Cloud Vision OCR
plus the existing regex parser remain as the fallback engine.

Context: `receipt_ocr.parse_receipt_text` extracts lines with a
`<name> <price>` regex over Cloud Vision text. It loses multi-line
descriptions, mis-attributes coupons, cannot expand store
abbreviations, and has no notion of confidence. Building the shared
UPC product database (ADR-008) needs cleaner descriptions, quantities,
per-line confidence, and store-aware normalisation.

Options considered:

**Option A — Public Gemini API (API key)**
- Simplest SDK setup
- Weakness: API key must live in Secret Manager and be rotated;
  consumer terms, no data-residency controls, separate billing

**Option B — Gemini via Vertex AI (chosen)**
- IAM/ADC with the existing Cloud Run runtime service account — no
  key material anywhere (GUARDRAILS rule 4, NFR-004)
- Same project, billing, audit logging, and region (`us-central1`)
  as the rest of the stack; enterprise data-use terms
- Native `response_schema` constrained decoding
- Weakness: slightly heavier SDK and IAM setup (`roles/aiplatform.user`)

**Option C — Cloud Document AI (Expense parser)**
- Purpose-built receipt model with entities for line items
- Weakness: fixed schema, weaker at abbreviation expansion and
  categorisation, per-page pricing comparable to Gemini, no
  store-aware prompting

**Option D — Keep Cloud Vision + improve regex**
- Zero new dependencies
- Weakness: ceiling is low; every store format needs handcrafted rules

Decision details:
- Whole receipt per call (not per line): coupons and continuation
  lines only make sense with context; one call is also cheaper.
- Response validated server-side against the same JSON Schema sent as
  `response_schema`; invalid → corrective retry, max 2 (REQ-RCP-004);
  exhausted → fallback engine (REQ-RCP-005).
- Prompt versions are immutable directories under
  `backend/prompts/receipt_parse/vN/`; every job records
  `prompt_version`, `prompt_sha256`, `schema_version`, `model`
  (REQ-RCP-017) and retains raw output (REQ-RCP-018).
- Per-attempt timeout 60 s. This is the documented exception to the
  10 s external-call rule in `docs/code-standards.md`; LLM inference
  cannot meet 10 s on full receipts.
- Async-first API (`202` + poll) with a bounded synchronous
  `wait_seconds` so current clients keep a synchronous path.
- Runs inside the existing Cloud Run service with Cloud Tasks for
  background execution rather than separate Cloud Functions: one auth
  path, one persistence switch, one test harness.

Trade-off: Non-deterministic output and LLM cost per receipt
(~US$0.01–0.03 with Gemini Pro at typical receipt sizes). Mitigated by
schema-constrained decoding, retries, raw-output audit, and the option
to switch to Flash per prompt version once accuracy is measured.

### ADR-008: Shared, Provenance-Tracked UPC Product Database
Date: 2026-09-26 · Revised: 2026-09-29 (datastore changed to Cloud SQL)
Status: Proposed (phase-1 review)
Decision: Maintain a single **shared product catalog in Cloud SQL for
PostgreSQL** — tables `store_chains`, `products`, `product_aliases`,
`product_confirmations`, `enrichment_jobs`/`enrichment_steps`,
`product_conflicts` — keyed by UPC (or a deterministic `llm:` /
`plu:` id until a UPC is known), grown from receipts, barcode scans,
and enrichment sources, with `source`, `confidence_score`,
`confirmation_count`, and a `status` lifecycle
`unverified → pending → verified`. Household data (receipts, line
items, scan events, parse jobs, inventory) stays in Firestore per
ADR-002a; the stores reference each other only by opaque string ids.

Context: ADR-004 anticipated that "our own database grows organically
as users scan items not found in the third-party source", but nothing
persists product knowledge today — every lookup goes live to Open
Food Facts and receipt matches are discarded after the response.
Receipt parsing (ADR-007) produces store-specific descriptions that
third-party databases do not know; households repeatedly confirming
the same line is the signal that turns them into trustworthy entries.
Unlike every other Mekasa collection, this data is not owned by a
household: it is one catalog shared by all accounts, read on every
receipt line and barcode scan, and its value lies in uniqueness (one
row per UPC, one product per printed alias per chain) and fuzzy
matching — the two things ADR-002a explicitly listed as Firestore
weaknesses. ADR-002a's reasons for Firestore (real-time multi-device
sync, offline cache) do not apply to a server-only catalog.

Options considered:

**Option A — Per-household product cache**
- Trivially private
- Weakness: no network effect; every household re-teaches the same
  Publix abbreviations

**Option B — Shared `products` collection in Firestore** (rejected;
chosen in the 2026-09-26 draft, reversed on product-owner review)
- One datastore; consistent with ADR-002a
- Weakness: no uniqueness constraints — UPC and alias uniqueness had
  to be simulated with document ids and transactions
- Weakness: fuzzy matching limited to `array_contains_any` over ≤ 10
  hand-built tokens; brand + size gating (REQ-RCP-010 AC8) needs
  client-side filtering after over-fetching
- Weakness: cross-household aggregates (distinct confirming
  households, curation queues, "most disputed verified products")
  are array fields with 1 MiB document limits, not queries

**Option C — Cloud SQL for PostgreSQL (chosen)**
- Constraints express the rules: unique `upc` (partial index), `PRIMARY KEY
  (store_chain_id, alias)`, `PRIMARY KEY (product_id, household_hash)`
  for once-per-household confirmations, a `CHECK` that a `verified`
  row has a UPC and evidence, a partial unique index for one live
  enrichment job per product (REQ-RCP-009 AC3)
- `pg_trgm` GIN indexes on `normalized_name`, `brand`, and aliases
  give real similarity search for the fuzzy step and the picker
- Foreign keys between products, aliases, confirmations, jobs, steps,
  conflicts; `superseded_by` re-keying is a self-reference
- Migrations are reviewable, idempotent SQL files; the schema is the
  documentation
- Costs (recorded, accepted):
  - a second database to run: Cloud SQL instance, backups, schema
    migrations, a connection pool per Cloud Run instance
  - a small always-on monthly cost (`db-f1-micro`, ~US$10/month)
  - no realtime client listeners; shared product data reaches clients
    through the API, which is intended anyway — the catalog is
    server-owned
  - ADR-002a is amended rather than replaced: it still governs every
    household-scoped collection

**Option D — AlloyDB / Cloud Spanner**
- Weakness: cost and operational weight far beyond a household-scale
  catalog; nothing here needs their scale

What Postgres gives this particular database (the reasons the
decision rests on):

1. **Safe concurrent writes to the same rows.** Every household's
   receipts and scans update the same product, alias, and store rows.
   Firestore handles this with per-document transactions that retry
   on contention; each receipt line is its own retry loop. In
   Postgres a whole receipt — its lines' product upserts, their
   aliases, the store row — commits in one transaction, and the save
   takes a per-chain advisory lock
   (`pg_advisory_xact_lock(hashtext(store_chain_id))`), so two
   households saving the same chain's receipts at once cannot
   overwrite each other's alias mappings (design §4.1).
2. **Fuzzy matching of receipt text.** Lines like `GV CHOC CHP CKY`
   must be matched to known products. `pg_trgm` trigram similarity
   with a GIN index does this server-side; Firestore can only do
   exact token matches (`array_contains_any` on a `name_tokens`
   list), so misspellings and abbreviations miss unless that exact
   token was seen before.
3. **The database enforces data quality.** Crowd-sourced data is
   messy. Constraints enforce one row per UPC, valid `status` /
   `source` values, aliases that cannot point at products that do not
   exist, and confirmations that cannot name a raw household. With
   Firestore these were JSON Schemas that only the application
   checked.
4. **Moving a product to its UPC is atomic.** A product is keyed
   `llm:<hash>` until its UPC is found; then the UPC-keyed `products` row is
   created, aliases and confirmations move, counts merge, and the old
   row is marked `superseded_by`. In SQL that is one transaction
   (design §4.1); in Firestore it is a multi-document job that has to
   cope with failing halfway.
5. **Reviewing the data is easy.** "Which H-E-B items conflict?",
   "confirmation counts per chain", "codes seen at more than one
   store" are plain SQL joins over products, aliases, chains, and
   conflicts. In Firestore each new question needs a new composite
   index or an export.

Rules embedded in the decision:
- **One Postgres schema.** The pre-ADR-008 prototype per-store tables
  (`stores`, `store_items`, `store_item_codes`, `photos`,
  `household_latest_receipts`; DDL `backend/app/store_catalog.sql`
  applied at API startup, PR #106) were retired on 2026-10-03:
  migration `0003_retire_store_catalog_prototype.sql` drops them. They
  stored raw household ids (NFR-002) and user photo bytes behind a
  public URL, and their receipt-line / manual-scan bookkeeping is
  superseded by `products` + `product_aliases` +
  `product_confirmations`. Product capture for an unidentified
  receipt line now does a barcode lookup plus a household-private
  photo (REQ-INV-019); the shared-catalog write arrives with the
  REQ-RCP-020 `capture` endpoints. All DDL goes through numbered
  migrations — the API never creates tables.
- Connection: Cloud Run connects over the Cloud SQL Unix socket.
  `DATABASE_URL=postgresql://USER:PASS@/DB?host=/cloudsql/PROJECT:REGION:INSTANCE`
  is read from Secret Manager secret `mekasa-database-url`; only the
  secret's name appears in code or config (GUARDRAILS rule 4,
  NFR-004). Driver `psycopg` 3 with `psycopg_pool`. Runtime service
  account roles: `roles/cloudsql.client`,
  `roles/secretmanager.secretAccessor`. Instance `mekasa-pg`
  (Postgres 16, `us-central1`), database `mekasa`, user `mekasa_api`.
- Local and tests: `DATABASE_URL` unset → in-memory
  `products_repository`; Postgres tests run only when
  `TEST_DATABASE_URL` points at a scratch database and are skipped
  otherwise. Repositories stay Protocols with in-memory and Postgres
  implementations, as `HOUSEHOLD_PERSISTENCE` does today.
- The catalog holds **no household or user identifiers** (NFR-002):
  households appear only as `SHA-256(household_id + server salt)` in
  `product_confirmations` and `product_conflicts`; a `CHECK` enforces
  the hash shape.
- Enumerations are `TEXT` + named `CHECK` constraints (not
  `CREATE TYPE`) so values can be added in one transaction; revisited
  in [ADR-009](adr/ADR-009-enum-strategy.md).
- Provenance weights: `gs1_registry 0.9 > store_api 0.8 > user_scan
  0.7 > llm_ocr 0.4`; only GS1-verified and official-store-API hits
  are authoritative for status transitions.
- `verified` entries are immutable to the parser and to individual
  users (REQ-RCP-014); disagreements are written to
  `product_conflicts` for curation.
- Users are the correction path of last resort, not bystanders: any
  attribute (name, brand, category, size, qty, price) and the image can
  be corrected per line / inventory item without touching the catalog,
  and proposed for the shared product through
  `POST /v1/catalog/products/{id}/corrections` — applied on `unverified`
  rows, filed as `product_conflicts` on `verified` rows (REQ-RCP-019).
  When no UPC is discovered the user scans the barcode and optionally
  photographs the product; the capture creates or re-keys the shared
  row in one transaction (REQ-RCP-020). The capture photo is shared with
  that UPC (decided 2026-10-04): it is stored under a random id
  (`/v1/product-photos/{uuid}`, EXIF stripped, auth-gated redirect to a
  signed URL) so it can back a shared `image_url` without leaking a
  household id (REQ-RCP-021; design §3.11). Pictures a member sets from
  item detail stay household-private (REQ-INV-019) and never reach the
  catalog.
- Enrichment order: official store API → Open Food Facts → UPCitemdb
  (discovery, stop at first UPC) → GS1 verification of any known UPC →
  crowdsourced pending (REQ-RCP-010), reusing the ADR-006 waterfall.
  Name search is brand-gated: measured on a real 40-line receipt, an
  unconstrained token-overlap match picked the wrong brand for a third
  of packaged lines; with a brand filter, none. Name-search hits are
  candidates unless brand and size agree (REQ-RCP-010 AC8).
  GS1 is a verification step, not a discovery step: its lookups are
  GTIN → product and cannot find a UPC from a receipt description.
- **Retailer data only through official APIs — no scraping.** The
  `store_api` adapter is implemented per chain only where a documented
  API exists (Kroger Products API first; Walmart.io once approved).
  Probing heb.com on 2026-09-29 showed `robots.txt` disallowing
  `/search`, `/graphql` and `*/ajax/*`, and Imperva bot management
  challenging every non-browser request, including the sitemap.
  Circumventing that would breach terms of use, be perpetually
  fragile, and taint the provenance weight this source carries.
  Chains without an API (H-E-B, Publix, Costco, Target) get UPCs from
  scan correlation — including the forward pass on later Add-Items
  and trash-station scans (REQ-RCP-008 AC5) — and Open Food Facts.

Trade-off: A second datastore (~US$10/month idle, one more thing to
migrate and back up) and curation workload for conflicts and for
promoting `pending` entries. Mitigated by a single Secret Manager
secret, idempotent SQL migrations validated in CI against a Postgres
service container, conservative automatic thresholds (3
distinct households, or authoritative + 1), and by keeping the
curation surface (`/v1/admin/product-conflicts`) as a follow-up.
