# MEKASA — Specification v1.0

## Functional Requirements

### REQ-001: Household Account Creation
Priority: P0
Description: First adult creates a household account.
Design Artifact: N/A (backend)
Acceptance Criteria:
- AC1: User can sign up via Sign in with Apple
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
Test File: android/src/test/ui/TrashStationUITest.kt, ios/MekasaTests/UI/TrashStationUITest.swift
Acceptance Criteria:
- AC1: Simplified single-purpose UI for scanning only
- AC2: No navigation or non-scanning elements visible
- AC3: Scan confirmation is displayed briefly then resets

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
