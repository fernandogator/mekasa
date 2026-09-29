# MEKASA — Architecture Document v1.0

## 1. System Overview
Mekasa consists of two native mobile clients (Android/Jetpack Compose
and iOS/SwiftUI), a GCP-based backend REST API served via Cloud Run,
and a real-time sync layer via Cloud Firestore. All clients communicate
through the same API, making future desktop clients straightforward
to add without any SDK dependency changes.

---

## 2. Component Diagram

```mermaid
graph TD
  AndroidApp[Android App\nJetpack Compose]
  iOSApp[iOS App\nSwiftUI]
  API[Cloud Run API\nREST]
  DB[(Cloud Firestore\nDatabase)]
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
fuzzy) → unmatched lines create `llm_ocr` products + enrichment jobs →
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
Status: Accepted
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
Date: 2026-09-26
Status: Proposed (phase-1 review)
Decision: Maintain a single top-level Firestore collection `products`
keyed by UPC (or a deterministic `llm:` id until a UPC is known),
grown from receipts, barcode scans, and enrichment sources, with
`source`, `confidence_score`, `confirmation_count`, and a
`status` lifecycle `unverified → pending → verified`.

Context: ADR-004 anticipated that "our own database grows organically
as users scan items not found in the third-party source", but nothing
persists product knowledge today — every lookup goes live to Open
Food Facts and receipt matches are discarded after the response.
Receipt parsing (ADR-007) produces store-specific descriptions that
third-party databases do not know; households repeatedly confirming
the same line is the signal that turns them into trustworthy entries.

Options considered:

**Option A — Per-household product cache**
- Trivially private
- Weakness: no network effect; every household re-teaches the same
  Publix abbreviations

**Option B — Shared `products` collection in Firestore (chosen)**
- Consistent with ADR-002a; the queries needed (equality on chain +
  `array_contains` on aliases/tokens) are Firestore-native with
  composite indexes
- Cross-household learning without storing household identity:
  confirmations are counted via salted household hashes; product
  documents carry no `household_id`/`uid` (NFR-002 AC1)
- Weakness: fuzzy search is token-based, not full-text — acceptable
  since matching is always chain-scoped and aliases dominate

**Option C — Cloud SQL / AlloyDB product table with trigram search**
- Better fuzzy matching
- Weakness: reopens ADR-002a; second datastore to operate for a
  household-scale app

Rules embedded in the decision:
- Provenance weights: `gs1_registry 0.9 > store_api 0.8 > user_scan
  0.7 > llm_ocr 0.4`; only GS1-verified and official-store-API hits
  are authoritative for status transitions.
- `verified` entries are immutable to the parser and to individual
  users (REQ-RCP-014); disagreements are written to
  `product_conflicts` for curation.
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

Trade-off: Curation workload for conflicts and for promoting
`pending` entries. Mitigated by conservative automatic thresholds
(3 distinct households, or authoritative + 1) and by keeping the
curation surface (`/v1/admin/product-conflicts`) as a follow-up.
