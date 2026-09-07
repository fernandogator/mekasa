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
  OCR[Cloud Vision API\nReceipt OCR]
  Barcode[Third-Party Barcode API\nUPC / Open Food Facts]
  Places[Google Places API\nStore Discovery]
  Secrets[GCP Secret Manager]
  Storage[Cloud Storage\nHome Photos]

  AndroidApp --> API
  iOSApp --> API
  API --> DB
  API --> OCR
  API --> Barcode
  API --> Places
  API --> Secrets
  API --> Storage
```

---

## 3. Data Flows

### Barcode Scan Flow
Mobile client captures barcode → sends UPC to API → API queries
third-party barcode database → returns product name, category,
estimated price → client confirms → API writes to Firestore →
real-time sync pushes to all household devices

### Receipt Scan Flow
Mobile client captures receipt image → uploads to Cloud Storage →
API triggers Cloud Vision OCR → returns parsed line items →
client presents for user review → confirmed items written to
Firestore → sync pushes to all household devices

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
