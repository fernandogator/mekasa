# MEKASA — Specification v1.0

## Functional Requirements

### REQ-001: Household Account Creation
Priority: P0
Description: First adult creates a household account.
Design Artifact: N/A (backend)
Acceptance Criteria:
- AC1: User can sign up via Sign in with Apple — **Deferred** (2026-10-02): removed from the iOS build for now because free Personal Teams cannot provision the Sign in with Apple capability; re-enable once a paid Apple Developer team is in place (entitlement, Welcome button, Firebase `apple.com` provider)
- AC2: User can sign up via Sign in with Google
- AC3: User can sign up via email and password with strength validation

### REQ-002: Household Naming and Photo
Priority: P2
Description: User optionally names the household and adds a home
photo used as the home screen backdrop.
Design Artifact: design/mockups/OnboardingHouseholdSetup.jsx
Acceptance Criteria:
- AC1: Household name field is optional and skippable
- AC2: Photo upload is optional and skippable
- AC3: If provided, photo appears as home screen backdrop

### REQ-003: Home Address Detection and Store Discovery
Priority: P1
Description: During onboarding, GPS detects the home location,
reverse geocodes to a suggested address the user confirms or edits,
then queries for grocery and retail stores within 15 miles.
Design Artifact: design/mockups/OnboardingStoreSelection.jsx
Acceptance Criteria:
- AC1: App requests location permission and detects GPS coordinates
- AC2: Coordinates are reverse geocoded to a human-readable address
  shown to the user for confirmation
- AC3: User can manually edit or replace the detected address before
  confirming
- AC4: Confirmed address is used to query nearby stores within a
  15-mile radius including Walmart, Costco, Publix, and local stores
- AC5: User selects one or more regular stores from the returned list

### REQ-004: Barcode Scanning and Product Lookup
Priority: P0
Description: User scans a barcode and the app retrieves item name,
category, typical price, and product image URL from a third-party
database (Open Food Facts primary; see ADR-004 / ADR image waterfall).
Design Artifact: design/mockups/AddItems.jsx
Acceptance Criteria:
- AC1: Valid barcode returns product name and category within 5
  seconds on standard mobile network
- AC2: Unknown barcode prompts manual entry fallback
- AC3: Item is added to inventory with quantity of 1 by default,
  adjustable before confirming
- AC4: When the lookup provider returns a product image, the response
  includes a usable `image_url` (or equivalent) persisted with the
  inventory item for list thumbnails and item detail (UI-006)
- AC5: Missing image does not fail the lookup; client shows a category
  placeholder instead
- AC6: Equivalent code shapes resolve to the same product: UPC-E is
  expanded to UPC-A, and UPC-A / zero-padded EAN-13 are treated as one
  code, so the same can scans identically on iOS and Android
- AC7: A provider outage (timeout, rate limit, 5xx) is reported as a
  retryable error, never as "unknown product"; sister databases
  (Open Products / Beauty / Pet Food Facts) are consulted before a code
  is declared unknown
- AC8: A successful barcode read plays the bundled scanner beep
  (`design/scanner-beep.mp3`) plus a success haptic (iOS) or short
  vibration (Android); unknown / failed lookups use a distinct nack
  tone plus warning haptic / longer vibration. Feedback is muted when
  Family → Scan sounds is off and during UI tests

### REQ-005: Receipt Scanning and Bulk Entry
Priority: P0
Description: User photographs a receipt and backend OCR extracts
line items for bulk addition to inventory.
Design Artifact: design/mockups/AddItems.jsx
Acceptance Criteria:
- AC1: Receipt image is sent to backend OCR and returns parsed item list
- AC2: User reviews and confirms or edits parsed items before saving
- AC3: Prices from receipt are stored as price-paid per item
- AC4: Each extracted line includes an `image_url` (catalog photo when
  matched, otherwise a category placeholder)
- AC5: Lines that cannot be matched to a known product are flagged
  `identified=false` so the client can highlight them for review
- AC6: From the confirm haul screen, the user can search the product
  catalog for an unidentified line and apply a match (name, image, UPC)
  before saving
- AC7: Receipt text (e.g. from an emailed receipt) can be pasted and sent
  as `raw_text` through the same parse + confirm flow as a photo

### REQ-006: Manual Item Entry
Priority: P1
Description: User manually adds an item with name, category, and quantity.
Design Artifact: design/mockups/AddItems.jsx
Acceptance Criteria:
- AC1: Form includes name, category, quantity, and optional price
- AC2: Item saves to shared household inventory immediately
- AC3: Manual entry is accessible from the main inventory screen
- AC4: When signed in, user can search the product catalog by typed name
  (e.g. "Oreos") and pick a concrete variant (name, category, image, UPC)
  before confirming; free-form "add as typed" remains available

### REQ-007: Voice Input for Item Entry
Priority: P2
Description: User adds an item using voice input.
Design Artifact: design/mockups/AddItems.jsx
Acceptance Criteria:
- AC1: Voice input is triggerable from the inventory screen
- AC2: Spoken item name is transcribed and matched against known
  products where possible
- AC3: User confirms item before it is saved

### REQ-008: Trash Station Consumption Scanning
Priority: P0
Description: A dedicated scanning mode on a secondary device
auto-decrements inventory when an item is scanned before disposal.
Design Artifact: design/mockups/TrashStationMode.jsx
Acceptance Criteria:
- AC1: Trash station mode runs on a secondary device logged into
  the household account
- AC2: Scanning a known item barcode decrements quantity by 1 immediately
- AC3: Unknown item scans are logged but do not create negative quantities
- AC4: Accepted scans play the scanner beep + haptic/vibrate (same as
  REQ-004 AC8); unknown scans play the nack feedback. A 5-second cooldown
  disarms the camera after each accepted scan so one toss is not
  double-counted
- AC5: Scan sounds honour the Family → Scan sounds toggle (default on)

### REQ-009: Low Stock Threshold — Manual
Priority: P0
Description: User sets a minimum quantity threshold per item.
Design Artifact: design/mockups/Dashboard.jsx
Acceptance Criteria:
- AC1: Threshold is settable from the item detail screen
- AC2: Default threshold is 1 if not set
- AC3: Changes apply immediately to low-stock calculations
- AC4: The item detail screen offers a "Use 1" action that consumes one
  unit through the same path as swipe / trash-station and reports the
  remaining quantity

### REQ-INV-014: Swipe Use One
Priority: P0
Description: Swipe left on an inventory item with quantity greater than 1
decrements quantity by 1 via the inventory consume API.
Acceptance Criteria:
- AC1: Trailing swipe shows “Use 1” with minus icon in accent red (#ca0013)
- AC2: Quantity decreases by 1; never below 0
- AC3: No confirmation alert

### REQ-INV-015: Swipe Remove Affordance
Priority: P0
Description: When quantity is exactly 1, swipe shows a destructive Remove action.
Acceptance Criteria:
- AC1: Trailing swipe labeled “Remove” with trash icon in accent red (#ca0013)

### REQ-INV-016: Soft Delete With Undo Toast
Priority: P0
Description: Confirming Remove soft-deletes the item and offers Undo.
Acceptance Criteria:
- AC1: Item disappears from the list immediately
- AC2: API marks `deleted: true` with `deleted_at`
- AC3: Undo toast “Item removed” visible for 5 seconds

### REQ-INV-017: Undo Soft Delete
Priority: P0
Description: Tapping Undo within 5 seconds restores the item.
Acceptance Criteria:
- AC1: `deleted: false` and `deleted_at` cleared
- AC2: Item reappears at its original list position

### REQ-INV-018: Purge Soft-Deleted Item
Priority: P0
Description: After 5 seconds without Undo, the document is hard-deleted.
Acceptance Criteria:
- AC1: Client calls purge so the Firestore document no longer exists
  (Cloud Tasks/Function may replace the client timer later)

### REQ-010: Low Stock Threshold — Learned
Priority: P2
Description: System learns consumption rate and suggests threshold
adjustments over time.
Design Artifact: N/A (backend)
Acceptance Criteria:
- AC1: System tracks consumption events with timestamps
- AC2: After sufficient data, system suggests an adjusted threshold
- AC3: User must approve suggested changes before they take effect

### REQ-011: Automatic Shopping List Addition
Priority: P0
Description: When quantity hits the low-stock threshold, item
auto-adds to the shared shopping list.
Design Artifact: design/mockups/ShoppingList.jsx
Acceptance Criteria:
- AC1: Item appears on shopping list within 5 seconds of crossing threshold
- AC2: No approval step required for auto-additions
- AC3: Item is removed from shopping list once marked purchased
- AC4: Auto-added rows carry an "Auto" chip so a shopper can tell them
  from manual additions; the list is grouped into Needs approval /
  To buy / Purchased sections with a "N to buy" header summary

### REQ-012: Child Shopping Request Submission
Priority: P1
Description: A Member can submit a shopping request tagged with their name.
Design Artifact: design/mockups/ShoppingList.jsx
Acceptance Criteria:
- AC1: Request includes item name and is tagged with the requesting
  member's name
- AC2: Request appears in pending state visible to all Owners
- AC3: Request does not appear as confirmed until approved
- AC4: Any household member can remove a row from the list (their own
  request or a plain item); removal is synced to the household

### REQ-013: Request Approval Workflow
Priority: P1
Description: Owner can approve, reject, or request more info on
a pending child request.
Design Artifact: design/mockups/ShoppingList.jsx
Acceptance Criteria:
- AC1: Owner can approve, moving item to active shopping list
- AC2: Owner can reject with optional reason
- AC3: Owner can send a question back to the requesting member

### REQ-014: Shopping List Purchase Restriction
Priority: P1
Description: Only Owners can mark shopping list items as purchased in v1.0.
Design Artifact: design/mockups/ShoppingList.jsx
Acceptance Criteria:
- AC1: Purchase action is only available to Owner-role users
- AC2: Member-role users can view but not mark items purchased; the
  list shows a "Only household owners can mark items purchased." notice
- AC3: Data model supports a future "buyer" permission without schema migration

### REQ-015: Price Capture from Receipt
Priority: P0
Description: Actual price-paid is recorded when an item is purchased
and logged via receipt scan.
Design Artifact: N/A (backend)
Acceptance Criteria:
- AC1: Price-paid is stored per purchase event, not just per item
- AC2: Price history is retained for at least 12 months
- AC3: Price is associated with the store where purchased if known

### REQ-016: Price Estimation Fallback
Priority: P1
Description: When actual price is unknown, system estimates using
historical data, online lookup, or category average.
Design Artifact: N/A (backend)
Acceptance Criteria:
- AC1: System checks historical price for same item first
- AC2: If no history, attempts online price lookup
- AC3: If no data available, uses category or brand average,
  clearly marked as estimated

### REQ-017: Spending Categorization
Priority: P0
Description: All tracked spending is categorized.
Design Artifact: N/A (backend)
Acceptance Criteria:
- AC1: Every item has an assigned category at time of entry
- AC2: Spending reports can be filtered and grouped by category
- AC3: User can manually recategorize an item

### REQ-018: Spending History Reporting
Priority: P1
Description: Users can view historical spending by category and time period.
Design Artifact: design/mockups/SpendingReport.jsx
Acceptance Criteria:
- AC1: Report supports weekly, monthly, and yearly groupings
- AC2: Report is viewable by all household members
- AC3: No budget caps or alerts in v1.0

### REQ-019: Household Member Invitation
Priority: P0
Description: Owner can invite additional adults (Owners) or children
(Members) to the household.
Design Artifact: design/mockups/FamilyMembers.jsx
Acceptance Criteria:
- AC1: Invite requires name plus email or phone number
- AC2: Invited user receives a notification or link to download and join
- AC3: Role is set at invitation and changeable by any Owner later
- AC4: Family screen shows the signed-in account, the household name and
  address, and each member's role and status, with a "Refresh data"
  action that re-pulls household data
- AC5: Family → Scanner shows a "Scan sounds" toggle (default on) that
  enables or mutes barcode beep + haptic/vibrate on this device

### REQ-020: Real-Time Multi-Device Sync
Priority: P0
Description: All household data syncs in real time across all
members' devices.
Design Artifact: N/A (backend)
Acceptance Criteria:
- AC1: Changes appear on other devices within 5 seconds under
  normal network conditions
- AC2: Sync conflicts resolve without data loss
- AC3: Offline changes queue and sync once connectivity is restored

### REQ-021: Product Health Grade and Member Avoidances
Priority: P1
Description: Barcoded products carry a health grade (A–E) derived from
Open Food Facts data (Nutri-Score, NOVA group, additives) plus their
additive, allergen and trace lists. Each household member keeps an
"I'm allergic to / I avoid" list (e.g. MSG, gluten, peanuts); products
containing any listed item warn which members are affected.
Design Artifact: design/pages/item-detail.html, design/mockups/FamilyMembers.jsx
Test File: tests/backend/test_product_health.py, ios/MekasaTests/ProductHealthTests.swift
Acceptance Criteria:
- AC1: A member can edit their own avoid list from a catalog of common
  allergens/additives plus free text; Owners can edit any member's list
- AC2: Scanning or viewing a product whose additives, allergens, traces or
  ingredients match a member's list shows "<member> avoids <item>" for
  every affected member, at scan-confirm time and on the item detail
- AC3: The grade formula is deterministic and documented
  (`backend/app/product_health.py`); products without Nutri-Score or NOVA
  data show "No grade" rather than a guess
- AC4: Health data is stored with the inventory item so the grade and
  warnings are available offline / via real-time sync without re-lookup

---

## UI Requirements

### UI-001: Native Android Interface
Priority: P0
Design Artifact: design/mockups/ (all screens)
User Flow: design/user-flows.md
Test File: android/src/test/ui/
Acceptance Criteria:
- AC1: Built entirely in Jetpack Compose, no XML layouts
- AC2: Follows Material Design 3
- AC3: Supports light and dark mode

### UI-002: Native iOS Interface
Priority: P0
Design Artifact: design/mockups/ (all screens)
User Flow: design/user-flows.md
Test File: ios/MekasaTests/UI/
Acceptance Criteria:
- AC1: Built entirely in SwiftUI, no Storyboards
- AC2: Follows Apple Human Interface Guidelines
- AC3: Supports light and dark mode

### UI-003: Onboarding Flow
Priority: P0
Design Artifact: design/mockups/OnboardingStoreSelection.jsx
User Flow: design/user-flows.md
Test File: android/src/test/ui/OnboardingUITest.kt, ios/MekasaTests/UI/OnboardingUITest.swift
Acceptance Criteria:
- AC1: Follows sequence: signup → household name/photo → address
  confirmation → store selection → inventory scan → invite prompt
- AC2: Every optional step is clearly skippable
- AC3: Onboarding is resumable if interrupted

### UI-004: Home Dashboard
Priority: P0
Design Artifact: design/mockups/Dashboard.jsx
User Flow: design/user-flows.md
Test File: android/src/test/ui/DashboardUITest.kt, ios/MekasaTests/UI/DashboardUITest.swift
Acceptance Criteria:
- AC1: Displays low-stock items prominently
- AC2: Displays pending child requests for Owner users
- AC3: Displays home photo as top hero band if set (tap to change via camera/Photos)
- AC4: Displays a shopping list teaser ("N items to pick up" / "List is
  clear" with a preview of open rows) that opens the List tab

### UI-005: Trash Station Mode
Priority: P0
Design Artifact: design/mockups/TrashStationMode.jsx
User Flow: design/user-flows.md
Test File: ios/Tests/UI/Structure/UI005StructureTests.swift,
  android/app/src/test/java/app/mekasa/android/ui/TrashStationModeUITest.kt,
  ios/MekasaTests/ScanFeedbackTests.swift, ios/MekasaTests/ScanCooldownTests.swift
Acceptance Criteria:
- AC1: Simplified single-purpose UI for scanning only
- AC2: No navigation or non-scanning elements visible
- AC3: Scan confirmation is displayed briefly then resets
- AC4: A typed-UPC fallback ("Or type UPC", 6–14 digits) consumes the
  matching item through the same path as a camera scan
- AC5: Accepted / unknown scans fire audible + haptic feedback per
  REQ-008 AC4–AC5 (scanner beep asset, nack tone, Scan sounds toggle,
  5 s cooldown after an accepted scan)

### UI-006: Inventory List Thumbnails and Item Detail
Priority: P0
Design Artifact: design/pages/inventory-list.html, design/pages/item-detail.html
User Flow: design/user-flows.md
Test File: ios/Tests/UI/Structure/UI006StructureTests.swift, ios/Tests/Snapshots/UI006SnapshotTests.swift, Scripts/ui_vision_cases.json (legacy stubs: ios/MekasaTests/UI/InventoryScreenUITest.swift)
Description: Inventory rows show a product thumbnail from barcode lookup
(Open Food Facts image URL when available). Tapping the row (or thumbnail)
opens item detail with a larger product image and product metadata.
Acceptance Criteria:
- AC1: Each inventory row displays a thumbnail when `image_url` is known;
  otherwise a category/placeholder image is shown
- AC2: Item detail shows a large product image; tapping it opens a
  full-screen enlarged view
- AC3: Item detail shows at least name, category, UPC (when known),
  quantity, and low-stock threshold
- AC4: Thumbnail and detail images use the barcode lookup image URL
  (REQ-004 / Open Food Facts) without blocking the UI on load failure
- AC5: When item detail opens for a row with no stored `image_url`, the
  client calls `POST .../inventory/{id}/refresh-image`; the API looks up
  Open Food Facts (or a category placeholder) and persists `image_url`
- AC6: The list is grouped under category headers (sorted by category,
  then item name), the header summarises "N items · M low" for the whole
  inventory, and a search field filters rows by name or category
  (case-insensitive) with a "No items match" state
- AC7: The list offers an Add entry point (header button, and an
  "Add items" CTA in the empty state) that opens the Add Items hub

---

## Non-Functional Requirements

### NFR-001: Scan Performance
Priority: P0
Acceptance Criteria:
- AC1: 95th percentile barcode scan-to-result under 5 seconds
- AC2: Works in typical indoor lighting
- AC3: Failed scans provide immediate manual entry fallback

### NFR-002: Data Privacy
Priority: P0
Acceptance Criteria:
- AC1: No cross-household data access possible
- AC2: All API calls require authentication
- AC3: No PII in plaintext application logs

### NFR-003: Offline Resilience
Priority: P1
Acceptance Criteria:
- AC1: Manual entry and trash-station scans work offline and queue
- AC2: Clear offline indicator shown when disconnected
- AC3: No data loss on reconnect

### NFR-004: Secrets Management
Priority: P0
Acceptance Criteria:
- AC1: All secrets stored in GCP Secret Manager
- AC2: No secrets in source control history
- AC3: Secrets rotated on a defined schedule

### REQ-022: Expired Session Auto Sign-Out
Priority: P0
Description: When the GCP / Firebase authenticated session expires
or the API rejects the bearer token (HTTP 401), the app detects the
failure, signs the user out, and returns them to the sign-in screen.
Design Artifact: design/mockups/OnboardingHouseholdSetup.jsx (Welcome / Sign in)
Test File: ios/MekasaTests/SessionExpiryTests.swift, tests/backend/test_auth_session.py
Acceptance Criteria:
- AC1: An API response of HTTP 401 for an authenticated call is treated
  as a session failure
- AC2: The client attempts one Firebase ID token refresh before ending
  the session; if refresh fails, the user is signed out
- AC3: After forced sign-out, the Welcome / Sign in screen is shown and
  ready for a new sign-in, with a clear "session expired" message
- AC4: Firebase Auth becoming unauthenticated while a session was active
  also returns the user to Welcome / Sign in
- AC5: After sign-out (including session expiry), the last signed-in
  username/email is remembered and prefilled on the Welcome sign-in form

---

## Receipt Intelligence (Gemini parser) — REQ-RCP-001 … REQ-RCP-018

Status: **Draft — phase 1 review** (design: `docs/design/gemini-receipt-parser.md`;
data model: `backend/firestore/migrations/0001_receipt_parser.md`; API:
`docs/api/receipt-parser.openapi.yaml`; prompt contract:
`backend/prompts/receipt_parse/v1/`).

These requirements extend REQ-005 (receipt scanning) and REQ-015 (price
capture). They were authored in the kickoff as REQ-1 … REQ-18; that numbering
collides with the permanent REQ-001 … series, so they are keyed
`REQ-RCP-0NN` in the same order (REQ-1 → REQ-RCP-001). Wording below follows
EARS patterns (ubiquitous / event-driven / state-driven / unwanted behaviour).
Design Artifact for all REQ-RCP entries: design/mockups/AddItems.jsx (confirm
haul) unless noted. Test File column is the phase-2 stub listed per entry.

### REQ-RCP-001: Receipt Upload Creates Receipt and Parse Job
Priority: P0
Description: **When** a household member uploads a receipt image (or pasted
text), the system **shall** create a `receipts` record and an `llm_parse_jobs`
record and return their identifiers.
Test File: tests/backend/test_receipt_parser_happy_path.py
Acceptance Criteria:
- AC1: `POST /v1/households/{id}/receipts` accepts `image_base64` (JPEG/PNG/HEIC ≤ 10 MB) or `raw_text`, plus optional `store_id`
- AC2: Response includes `receipt_id`, `status`, and `parse_job.id`; `202` when parsing continues asynchronously, `200` when finished within `wait_seconds` (≤ 45)
- AC3: The original image is stored in a private Cloud Storage object; the API never returns a public URL
- AC4: Non-members receive `403`; unknown household `404`

### REQ-RCP-002: Gemini Invocation via Vertex AI
Priority: P0
Description: **When** a parse job starts, the system **shall** invoke Gemini
through the Vertex AI SDK with the whole receipt in a single request, using
the versioned system prompt with the store chain name injected.
Test File: tests/backend/test_receipt_parser_happy_path.py
Acceptance Criteria:
- AC1: Exactly one `generate_content` call per attempt covers all receipt lines (no per-line calls)
- AC2: Vertex AI is authenticated with the runtime service account (ADC); no API key exists in code, config, or Secret Manager for this feature
- AC3: The rendered prompt substitutes `{{store_chain_name}}` from the receipt's resolved chain (`Unknown` when unresolved) and contains no other placeholder
- AC4: `response_mime_type` is `application/json` and the response schema passed to the model is `backend/prompts/receipt_parse/vN/response.schema.json`

### REQ-RCP-003: Response Schema Validation Before Persistence
Priority: P0
Description: **When** Gemini returns a response, the system **shall** validate
it against the version's JSON Schema and semantic rules before persisting any
line item.
Test File: tests/backend/test_prompt_contract.py
Acceptance Criteria:
- AC1: Validation uses JSON Schema Draft 2020-12 against `response.schema.json`; any error prevents writes to `line_items`
- AC2: Semantic checks reject `price < 0`, `qty ≤ 0`, `confidence ∉ [0,1]`, and any `raw_text` containing ≥ 13 consecutive digits
- AC3: Validation errors are recorded verbatim (truncated to 500 chars each) on the attempt

### REQ-RCP-004: Corrective Retry on Invalid Response
Priority: P0
Description: **If** validation fails, **then** the system **shall** re-invoke
Gemini with a corrective prompt containing the validation errors, up to two
retries (three attempts total).
Test File: tests/backend/test_receipt_parser_retry_and_failure.py
Acceptance Criteria:
- AC1: Retry uses the same system prompt version plus `corrective.md` rendered with `{{attempt}}` and `{{validation_errors}}`
- AC2: `llm_parse_jobs.attempts` holds one entry per attempt with `corrective_prompt_applied=true` on retries
- AC3: No more than 3 attempts are ever made for one job
- AC4: A valid response on a retry completes the job as `succeeded`

### REQ-RCP-005: Exhausted Retries Fail Safely
Priority: P0
Description: **If** all attempts fail (schema invalid, model error, timeout,
safety block), **then** the system **shall** mark the job `failed`, mark the
receipt `needs_review`, and provide fallback line items from the legacy OCR
path so the user can still review a haul.
Test File: tests/backend/test_receipt_parser_retry_and_failure.py
Acceptance Criteria:
- AC1: Job `status=failed` with `error_code ∈ {schema_invalid, model_error, timeout, safety_blocked, pii_detected}`
- AC2: Receipt `status=needs_review`, `extraction_engine ∈ {vision_regex, text_regex, stub}`
- AC3: `GET /receipts/{id}` returns the fallback lines with `resolution_status=unmatched` and `extraction_confidence=0`
- AC4: Failure is logged with job id and error code only (no receipt text)

### REQ-RCP-006: Persist Validated Line Items
Priority: P0
Description: **When** a response is valid, the system **shall** persist one
`line_items` document per extracted product line.
Test File: tests/backend/test_receipt_parser_happy_path.py
Acceptance Criteria:
- AC1: Each document stores `line_no`, `raw_text`, `description`, `price`, `qty`, `unit`, `discount`, `printed_code`, `category`, `extraction_confidence`
- AC2: Receipt header fields `store_chain_detected`, `purchased_at`, `subtotal`, `tax`, `total`, `currency` are written from the response
- AC3: Legacy fields `name`, `quantity`, `price_paid`, `image_url`, `identified` are derived so existing clients render the haul unchanged
- AC4: Receipt `line_item_count` and `unresolved_count` are maintained

### REQ-RCP-007: Match Lines Against the Product Database
Priority: P0
Description: The system **shall** attempt to match every line item to a
`products` entry scoped to the receipt's store chain, in the order exact UPC
→ scan correlation → alias → fuzzy name.
Test File: tests/backend/test_receipt_low_confidence_confirmation.py
Acceptance Criteria:
- AC1: Every matched line stores `matched_product_id`, `match_method`, `match_confidence`
- AC2: Alias and fuzzy lookups only consider products with the same `store_chain_id` (or `unknown`)
- AC3: `match_confidence ≥ 0.85` → `resolution_status=auto_matched`; otherwise see REQ-RCP-012
- AC4: A successful match upserts the normalized `raw_text` into `product_aliases (store_chain_id, alias) → product_id` (one product per alias per chain; an alias already mapped to a different product is never overwritten — handling is design open question §9.11)

### REQ-RCP-008: Correlate Receipt Lines with Recent Scan Events
Priority: P1
Description: **While** a receipt is being resolved, the system **shall**
correlate unmatched line items with the household's uncorrelated barcode
`scan_events` from the 72 h before purchase (backward pass); **when** a new
scan event arrives, the system **shall** correlate it with the household's
still-unmatched line items from the previous 30 days (forward pass), so UPCs
are recovered for chains that print none.
Test File: tests/backend/test_receipt_scan_correlation.py
Acceptance Criteria:
- AC1: Backward pass considers only events with `context=add_items`, `correlated_receipt_id=null`, and `scanned_at ∈ [purchased_at − 72 h, receipt.created_at + 1 h]`
- AC2: Assignment is one-to-one by name similarity ≥ 0.6; the line gets `match_method=scan_correlation` and the event's UPC
- AC3: The scan event is stamped with `correlated_receipt_id` and `correlated_line_item_id` and is never reused
- AC4: Correlation never lowers a confidence already obtained by exact UPC match
- AC5: Forward pass runs on every new scan event in any context (`add_items`, `trash_station`, `manual_entry`) against the household's `unmatched`/`needs_confirmation` lines with `created_at ≥ now − 30 d`; the scanned UPC is named via `products` or Open Food Facts before similarity is computed
- AC6: A forward-pass hit on a line already confirmed to an `llm:` product re-keys that product to the UPC (REQ-RCP-010 AC2) instead of altering the confirmed line

### REQ-RCP-009: Unmatched Lines Create Unverified Products and Enrichment Jobs
Priority: P0
Description: **When** a line item has no product match, the system **shall**
create an `llm_ocr` product entry with `status=unverified` and dispatch an
enrichment job.
Test File: tests/backend/test_receipt_parser_happy_path.py
Acceptance Criteria:
- AC1: Product id is `llm:<sha1(store_chain_id|normalized_name)>`; repeated sightings update the same row (`last_seen_at`, aliases) instead of duplicating
- AC2: `source=llm_ocr`, `confidence_score = extraction_confidence × 0.6`, `origin_parse_job_id`, `origin_prompt_version` set
- AC3: Exactly one `enrichment_jobs` row is created per new product (none for repeat sightings within 7 days); the catalog enforces at most one `queued`/`running` job per product
- AC4: Catalog rows contain no household or user identifiers; households appear only as salted SHA-256 hashes in `product_confirmations` / `product_conflicts`

### REQ-RCP-010: Enrichment Source Order
Priority: P1
Description: The enrichment dispatcher **shall** attempt discovery sources in
the order official store API → Open Food Facts → UPCitemdb, stopping at the
first that returns a UPC; **shall** then verify any known UPC against the GS1
registry; and **shall** mark the product crowdsourced-pending when no UPC is
found. The dispatcher **shall not** scrape retailer websites.
Test File: tests/backend/test_enrichment_dispatcher.py
Acceptance Criteria:
- AC1: Each step is recorded as an `enrichment_steps` row (`job_id`, `step_no`, `adapter`) with `hit|miss|error|not_implemented|skipped`
- AC2: A discovery hit re-keys an `llm:` product to a `products` row with `product_id = <upc>` and sets `superseded_by` on the old row
- AC3: `store_api` hits set `source=store_api`; a GS1-verified UPC sets `source=gs1_registry`; both count as authoritative for REQ-RCP-011 transitions. UPCitemdb/OFF hits are recorded as `user_scan` grade
- AC4: External calls honour the 10 s timeout / 3-retry standard and provider quotas (UPCitemdb free tier, Kroger daily limit) via the `enrichment` queue
- AC5: With no discovery hit, the product stays `unverified` and is flagged `crowdsourced_pending` in the job result
- AC6: `store_api` adapters use only official, documented retailer APIs with credentials in Secret Manager (first adapter: Kroger Products API; Walmart.io behind a flag pending approval). Chains without an official API (H-E-B, Publix, Costco, Target) return `not_implemented`; no adapter may fetch retailer web pages, bypass bot protection, ignore `robots.txt`, or call undocumented app endpoints
- AC7: `gs1_verify` runs only when a UPC is already known (discovery hit, scan correlation, or printed code); it never runs as a name search
- AC8: Name search is brand-gated: lines with `brand=null` skip it; queries filter by brand and US market; a hit auto-links only when brand matches, `unit_size` is compatible or unknown, and name similarity ≥ 0.6 — otherwise the top 3 hits are stored as `candidate_product_ids` and the line stays `needs_confirmation`
- AC9: Bulk produce resolves to `products.product_id = 'plu:<IFPS code>'` (shared across chains) rather than a UPC

### REQ-RCP-011: Product Provenance, Confidence, and Status
Priority: P0
Description: Every `products` entry **shall** carry `source`,
`confidence_score`, `confirmation_count`, and `status ∈ {unverified, pending,
verified}`, with status transitions driven by confirmations and authoritative
sources.
Test File: tests/backend/test_receipt_low_confidence_confirmation.py
Acceptance Criteria:
- AC1: `unverified → pending` when a second distinct household confirms or an authoritative source matches
- AC2: `pending → verified` when ≥ 3 distinct households have confirmed, or an authoritative source matched and ≥ 1 household confirmed
- AC3: `verified` is never downgraded automatically
- AC4: `confidence_score` is recomputed on every transition per the design formula and stays within [0, 1]
- AC5: Distinct households are counted via salted hashes only

### REQ-RCP-012: Low-Confidence Matches Require User Confirmation
Priority: P0
Description: **While** a line's best `match_confidence` is below the auto-accept
threshold, the system **shall** require an explicit user confirmation before
linking the line to a product.
Test File: tests/backend/test_receipt_low_confidence_confirmation.py
Acceptance Criteria:
- AC1: `0.5 ≤ match_confidence < 0.85` → `resolution_status=needs_confirmation` with up to 5 `candidate_product_ids`
- AC2: `< 0.5` or no candidate → `resolution_status=unmatched`
- AC3: `GET …/candidates` returns stored candidates plus live product / Open Food Facts search results
- AC4: `POST …/resolve` with exactly one of `product_id | upc | candidate_index | manual` sets `resolution_status=confirmed`, `match_method=user`
- AC5: `POST …/reject` marks the line `rejected` or `skipped` and excludes it from confirm

### REQ-RCP-013: User Confirmation Strengthens the Product
Priority: P0
Description: **When** a user confirms a match (via resolve, or via receipt
confirm for auto-matched lines), the system **shall** increment the product's
`confirmation_count` once per household and re-evaluate its status.
Test File: tests/backend/test_receipt_low_confidence_confirmation.py
Acceptance Criteria:
- AC1: `confirmation_count` increases by 1 the first time a household confirms a product; later confirmations from the same household do not increment (`confirmation_counted=false`)
- AC2: `product_aliases` gains the line's normalized `raw_text` for the receipt's chain (or its `seen_count` increments)
- AC3: Status transition rules of REQ-RCP-011 run immediately and `status_changed_at` is updated on change

### REQ-RCP-014: Verified Entries Are Never Mutated by the Parser
Priority: P0
Description: **If** a resolution conflicts with a `verified` product entry,
**then** the system **shall not** modify the verified entry, **shall** record
the conflict, and **shall** require user confirmation for the line.
Test File: tests/backend/test_receipt_verified_conflict.py
Acceptance Criteria:
- AC1: A conflict is any of: name/brand similarity < 0.5, differing `unit_size`, differing `category`, or a different UPC submitted for a verified name
- AC2: The verified row's `name`, `brand`, `category`, `unit_size`, `upc`, and `status` are byte-identical before and after the parse and after any user resolve
- AC3: A `product_conflicts` row is written with `field`, `verified_value`, `observed_value`, `status=open`
- AC4: The line becomes `needs_confirmation` with the verified product as sole candidate and `conflict_id` set; a user confirmation increments `dispute_count`, not `confirmation_count`

### REQ-RCP-015: Receipt Confirm Writes Inventory and Purchase Events
Priority: P0
Description: **When** a user confirms a receipt, the system **shall** write
inventory items and purchase events for every non-rejected line, carrying
price paid and store.
Test File: tests/backend/test_receipt_confirm_writes_inventory.py
Acceptance Criteria:
- AC1: Inventory upsert matches by barcode first, then case-insensitive name; `source=receipt`, `price_paid`, `image_url`, `product_id`, `receipt_line_item_id` set
- AC2: One purchase event per line with `source=receipt`, `store_id`, `receipt_id`, `receipt_line_item_id`, `product_id`
- AC3: Receipt `status=confirmed`, `confirmed_by_uid`, `confirmed_at` set; the operation is idempotent
- AC4: `rejected`/`skipped` lines are ignored; `unmatched` lines are saved as plain items only when `include_unmatched=true` (default)

### REQ-RCP-016: Persist Scan Events
Priority: P1
Description: The system **shall** persist every barcode scan as a
`scan_events` document with UPC, household, timestamp, context, and outcome.
Test File: tests/backend/test_receipt_scan_correlation.py
Acceptance Criteria:
- AC1: Barcode lookups from Add Items write `context=add_items` with `outcome ∈ {found, unknown}` and `product_name_at_scan`
- AC2: Trash-station consume writes `context=trash_station` with `outcome ∈ {consumed, unknown}`; the existing unknown-barcode log is served from this collection (REQ-008 AC3 preserved)
- AC3: `GET /v1/households/{id}/scan-events` lists events newest first with `outcome`/`since` filters
- AC4: Household members only; no cross-household reads

### REQ-RCP-017: Record Prompt and Model Provenance
Priority: P0
Description: Every parse job **shall** record the prompt version, prompt
hash, response-schema version, model id, and Vertex location used.
Test File: tests/backend/test_prompt_contract.py
Acceptance Criteria:
- AC1: `prompt_version` matches `receipt_parse/vN`; `prompt_sha256` equals the SHA-256 of that version's `system.md`
- AC2: `schema_version` embeds the first 12 hex chars of the SHA-256 of `response.schema.json`
- AC3: `model` and `vertex_location` reflect the values actually sent to Vertex AI
- AC4: Prompt version directories are immutable once referenced; CI lint fails on modification of a referenced version

### REQ-RCP-018: Retain Raw Gemini Output for Audit
Priority: P0
Description: The system **shall** retain the raw JSON returned by Gemini for
every attempt of every parse job.
Test File: tests/backend/test_receipt_parser_retry_and_failure.py
Acceptance Criteria:
- AC1: Each attempt stores `raw_response` inline when ≤ 200 KB, otherwise `raw_response_gcs_uri`
- AC2: Raw output is retained for the audit window (180 days, TTL on `expires_at`; value under review)
- AC3: Raw output is only readable by household Owners via `GET …/parse-job?include_raw=true`
- AC4: Raw output never appears in application logs
