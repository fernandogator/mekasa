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

### REQ-INV-019: Replace an Item Picture With a Private Photo
Priority: P1
Description: A household member **shall** be able to replace any inventory
item's picture (and a draft's picture before it saves) with a photo they
take or pick. The photo is stored in Google Cloud Storage under the
household's account and is served only to signed-in members of that
household; it is never shared with other households or with the shared
product catalog.
Design Artifact: design/pages/product-image-editor.html, design/mockups/ItemDetail.jsx
Test File: tests/backend/test_item_photos.py, ios/MekasaTests/ItemPhotoTests.swift, android-fable/app/src/test/java/app/mekasa/fable/ItemPhotoTest.kt
Acceptance Criteria:
- AC1: `POST /v1/households/{hid}/item-photos` (multipart `file`, JPEG/PNG/WebP ≤ 8 MB, household member; both apps re-encode camera output to JPEG before upload) re-encodes the image as JPEG with all metadata (EXIF, GPS) stripped, limits the long edge to 1600 px, and returns `{photo_id, url}` where `url` is `/v1/households/{hid}/item-photos/{photo_id}`
- AC2: Objects live in bucket `ITEM_PHOTO_BUCKET` (`mekasa-item-photos-<env>`) at `households/{hid}/item-photos/{photo_id}.jpg` with uniform bucket-level access and no public ACL; the only readers are the API's service account
- AC3: `GET /v1/households/{hid}/item-photos/{photo_id}` requires a bearer token for a member of `{hid}`; non-members receive `403`, unknown ids `404`; bytes are served with `Cache-Control: private`
- AC4: Setting `image_url` on an inventory item through the existing `PATCH …/inventory/{item_id}` to a photo URL from AC1 replaces the picture; a previous private photo of the same household that the item pointed at is deleted from the bucket after the update succeeds
- AC5: `DELETE /v1/households/{hid}/item-photos/{photo_id}` (member) removes the object; an item still pointing at it falls back to the category placeholder on the next image refresh
- AC6: Private photos are never copied into the shared product catalog (`products.image_url`) and are never written to `product_conflicts`; a user who wants to contribute a product picture to the catalog does so through the separate, explicit product capture flow (REQ-RCP-020 AC5, REQ-RCP-021)
- AC7: With `ITEM_PHOTO_BUCKET` unset (local, tests) the API keeps photos in memory with the same endpoints and rules
- AC8: Both apps upload through AC1 and load private photo URLs with the bearer token (plain image loaders cannot fetch them); the iOS item detail hero, list thumbnails, and confirm-haul drafts offer "Take photo / Choose from library"; Android item detail offers the same

### REQ-INV-020: Swipe Between Items in Item Detail
Priority: P2
Description: **While** an item detail is open from a list, a household
member **shall** be able to swipe left for the next item and right for the
previous item of that list, without going back to it.
Design Artifact: design/pages/item-detail-swipe.html (Superdesign "Mekasa v1.0", draft "Item Detail Pager", 2026-10-05)
Test File: ios/MekasaTests/ItemPagerTests.swift, android-fable/app/src/test/java/app/mekasa/fable/ui/ItemPagerTest.kt
Acceptance Criteria:
- AC1: The order is the list the detail was opened from, as shown at that moment: the Inventory list with its search and category grouping, or the Dashboard section (Low stock, or Recently added on Android). Items removed while the detail is open are skipped
- AC2: A horizontal swipe (at least 60 pt/dp and clearly more horizontal than vertical) moves one item: left → next, right → previous. Vertical scrolling is unaffected; on iOS a swipe that starts at the left screen edge stays the system "back" gesture
- AC3: The header shows the position ("3 of 24"); the hero shows chevrons at its edges for the previous and next item, which also move on tap, and a dimmed sliver of the neighbouring item's picture. The content slides in from the swipe direction with a light haptic
- AC4: At the first or last item a swipe does not wrap: the content bounces back with a firmer haptic, and the chevron on that side is hidden
- AC5: VoiceOver/TalkBack offer "Next item" and "Previous item" actions with the same result (NFR-005)
- AC6: Opened without a list (e.g. a deep link or route straight to the item), the detail shows no position, chevrons or swipe
- AC7: Moving to another item shows that item's own quantity, threshold, picture and status, and runs the same on-open refreshes (image, health) as opening it from the list

### REQ-INV-021: Find and Merge Duplicate Items
Priority: P2
Description: A household member **shall** be able to ask the app to find
inventory items that are the same product listed more than once, review
each group, and merge it into one item that keeps the newest picture.
Nothing merges without the member's confirmation.
Design Artifact: design/pages/inventory-duplicates.html (Superdesign "Mekasa v1.0", draft "Duplicates Review", 2026-10-06)
Test File: tests/backend/test_inventory_duplicates.py, ios/MekasaTests/InventoryDuplicatesTests.swift, android-fable/app/src/test/java/app/mekasa/fable/ui/InventoryDuplicatesTest.kt
Acceptance Criteria:
- AC1: `GET /v1/households/{hid}/inventory/duplicates` (household member) returns groups of two or more visible (not soft-deleted) items that share any of the following:
  - the same non-empty `barcode` (reason `same_barcode`);
  - the same catalog `product_id` (reason `same_product`);
  - the same category and the same normalized name (reason `same_name`). Names are normalized by ignoring case, accents, punctuation and repeated spaces, and by reducing simple plurals to their singular ("Bananas" → "banana", "Berries" → "berry", "Boxes" → "box").
  Items linked through any chain of these rules form one group. A group's reason is the strongest rule that links it (barcode, then product, then name).
- AC2: Each group names the item that survives: the item whose picture changed most recently. A real picture always wins over a category placeholder or no picture. When no item has a picture, the most recently updated item survives. Each item exposes `image_updated_at`, set whenever its `image_url` changes; items saved before this field existed fall back to `updated_at`.
- AC3: `POST /v1/households/{hid}/inventory/merge` with `item_ids` (2–20 ids that AC1 places in one group) merges them in one write:
  - **Survivor fields:** the survivor keeps its id, name, category and picture.
  - **Higher values:** `quantity` and `low_stock_threshold` become the highest value in the group. Quantities are not added together.
  - **Gap filling:** an empty `barcode`, `product_id`, `price_paid` or `health` on the survivor is filled from the most recently updated other item.
  - **Removed items:** the other items are deleted permanently (not moved to the REQ-INV-016 undo window).
  - **Shopping list:** rows that pointed at a removed item point at the survivor.
  - **Photos:** a household-private photo (REQ-INV-019) used only by a removed item is deleted.
  - **Response:** returns the merged item and the removed ids.
- AC4: Ids that are unknown, already deleted, or not one duplicate group are rejected (`404 not_found`, or `409 not_duplicates`), and nothing changes.
- AC5: Both apps offer "Find duplicates" on the inventory screen. It opens the Duplicates review:
  - **Group cards:** one card per group, with the reason chip ("Same barcode", "Same product", "Same name") and each item's picture, name, category, quantity and photo age. The survivor is marked "Keeps this photo", above a one-line preview of the result ("Merges into Bananas · keeps qty 3 (higher) · newest photo").
  - **Card actions:** "Merge" merges that group. "Not duplicates" hides the group on this device for this household until the items change.
  - **Bulk action:** a bottom button "Merge all N" merges every group shown.
  - **Confirmation:** a merge is confirmed with "Merged N items into {name}".
  - **Empty state:** when there are no groups, the screen shows "No duplicates found · Your inventory is tidy."
- AC6: The local inventory and shopping list update from the merge response without a full reload. Signed-out and preview sessions find and merge duplicates locally with the same rules (AC1–AC3).
- AC7: Group cards, the survivor badge and the actions are announced by VoiceOver/TalkBack (for example "Organic Bananas, keeps this photo"), and the screen follows NFR-005.

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
- AC4: Categories are a fixed list of eight, in this order: Produce, Dairy, Pantry, Meat, Frozen, Beverages, Household, Other. Every category picker (manual add, receipt edit sheet, product capture new-product card) offers only these, and no other value is stored on inventory items, receipt lines or purchases. Any source that produces a finer category (receipt parser, UPC lookup, catalog) maps it before storage: Bakery and Snacks → Pantry, Seafood → Meat, Alcohol → Beverages, Personal Care, Baby and Pet → Household, anything unknown → Other. Design drafts follow the same list. (Decided 2026-10-04.)

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
Test File: android-fable/app/src/test/java/app/mekasa/fable/ui/
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
Test File: android-fable/app/src/test/java/app/mekasa/fable/ui/OnboardingUITest.kt, ios/MekasaTests/UI/OnboardingUITest.swift
Acceptance Criteria:
- AC1: Follows sequence: signup → household name/photo → address
  confirmation → store selection → inventory scan → invite prompt
- AC2: Every optional step is clearly skippable
- AC3: Onboarding is resumable if interrupted

### UI-004: Home Dashboard
Priority: P0
Design Artifact: design/mockups/Dashboard.jsx
User Flow: design/user-flows.md
Test File: android-fable/app/src/test/java/app/mekasa/fable/ui/DashboardUITest.kt, ios/MekasaTests/UI/DashboardUITest.swift
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
  android-fable/app/src/test/java/app/mekasa/fable/ui/TrashStationModeUITest.kt,
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

### NFR-005: Accessible Text, Contrast and Targets
Priority: P0
Description: Every iOS and Android screen, and every design draft it is built from, meets minimum text size, contrast and touch-target rules. (Decided 2026-10-04.)
Acceptance Criteria:
- AC1: Text is at least 12 pt (sp on Android); 11 pt is allowed only for secondary captions; status chips and placeholders count as text
- AC2: Contrast meets WCAG 2.2 AA against the actual background: 4.5:1 for normal text (including placeholder and disabled-but-readable text), 3:1 for large text (≥ 18 pt, or ≥ 14 pt bold), icons, chip outlines and input borders
- AC3: Text scales with the system setting (iOS Dynamic Type, Android font scale) up to at least 200% without clipping or overlap; truncation (e.g. REQ-RCP-020 AC14) still exposes the full string to VoiceOver/TalkBack
- AC4: Tap targets are at least 44×44 pt on iOS and 48×48 dp on Android, including chips, the photo thumbnail and "Scan →"
- AC5: Colors come from theme roles (`MekasaTheme` on iOS and Android), not hardcoded values; any new or changed color scheme is adopted only after every role pair it defines (text on surface, text on brand, text on warning/success, light text on the dark camera surface) passes AC2 in every appearance the app supports

### NFR-006: Request Tracing and Diagnostic Logs
Priority: P1
Description: The Cloud Run API writes structured logs that show what happened on every request, and a correlation ID ties together all the calls of one user flow (for example a receipt scan and the captures and saves that follow it), so one search in Cloud Logging shows the whole story. (Decided 2026-10-06.)
Design Artifact: N/A (backend logging and client headers)
Test File: tests/backend/test_request_tracing.py, ios/MekasaTests/RequestTracingTests.swift, android-fable/app/src/test/java/app/mekasa/fable/data/remote/RequestTracingTest.kt
Acceptance Criteria:
- AC1: **IDs.** Every request has a request ID and a correlation ID:
  - **Request ID:** taken from the `X-Request-ID` header, or generated when it is missing or invalid.
  - **Correlation ID:** taken from `X-Correlation-ID`, or set to the request ID.
  - **Valid IDs:** 8–128 characters from `A–Z a–z 0–9 . _ : -`.
  - **Echoed:** both are returned in the response headers.
- AC2: **JSON logs.** Every backend log line, including library and server logs, is one JSON object on stdout that Cloud Logging reads:
  - **Standard fields:** `severity`, `message`, `time` and `logger`.
  - **Request fields:** `request_id`, `correlation_id`, `household_id` (when the path has one) and `user_ref`.
  - **Trace:** `logging.googleapis.com/trace` when Cloud Run sends a trace header.
  - **Event name:** structured events add `event` plus their own fields.
  - **Settings:** `LOG_LEVEL` sets the level; `LOG_FORMAT=text` gives plain lines for local runs.
- AC3: **Request summary.** Each request ends with one `http.request` event:
  - **Fields:** method, route template, status and duration in ms.
  - **Severity:** `INFO` below 400, `WARNING` for 4xx, `ERROR` for 5xx.
  - **Crashes:** an unhandled error also logs `http.exception` with its stack trace.
  - **No duplicates:** the server's own access log is off, so each request is logged once.
- AC4: **Change events.** Every successful write (`POST`, `PUT`, `PATCH`, `DELETE`) logs one `change` event:
  - **Fields:** `action` (the route's handler name, e.g. `update_inventory_item`), the route template, the ids in the path, the cleaned request body (`changes`) and the id of the written record (`result_id`).
  - **Skipped:** multipart uploads log only the file size. `POST …/receipts/scan` writes nothing, so it logs no `change` event; AC5 covers it.
- AC5: **Receipt scan story.** A receipt scan logs these events in order:
  - `receipt.scan.started`: input type, image size or text line count.
  - `receipt.llm.finished`: model, outcome (`ok`, `disabled`, `timeout`, `error`, `empty`), item count, duration.
  - `receipt.ocr.finished`: only when the fallback ran, with engine and item count.
  - `receipt.store.resolved`: printed store name and chain.
  - One `receipt.line` per line: index, receipt text, printed code, final name, category, `match_method`, `matched_product_id` and `identified`.
  - `receipt.scan.finished`: engine, line count, identified and unidentified counts, counts per match method, total duration.
- AC6: **Privacy (NFR-002 AC3).** Logs never contain:
  - **Credentials:** bearer tokens or Authorization headers.
  - **Personal details:** email addresses, street addresses, or household and person names.
  - **Raw receipt input:** the receipt image or pasted text, logged only as sizes.

  These keys are replaced with `[redacted]` wherever they appear, and email addresses in messages are masked. The user is logged only as `user_ref`, a short SHA-256 hash of the Firebase uid. Product and item names, receipt line text and barcodes are logged as-is.
- AC7: **App headers.** iOS and Android send a new `X-Request-ID` on every API call. They send `X-Correlation-ID` on every call of a receipt flow: the ID is created when the scan starts and reused for that flow's item saves, photo uploads and catalog captures. Calls outside a flow send no correlation ID.

### NFR-007: App Error Reports and Diagnostics
Priority: P1
Description: When something goes wrong in the iOS or Android app, enough detail reaches Cloud Logging to see what happened on the phone next to what the API did, crashes reach Firebase Crashlytics, and a user can send the app's recent log with one tap. (Decided 2026-10-08.)
Design Artifact: design/pages/family-members.html (Help card, AC5)
Test File: tests/backend/test_client_diagnostics.py, ios/MekasaTests/AppDiagnosticsTests.swift, android-fable/app/src/test/java/app/mekasa/fable/diagnostics/AppDiagnosticsTest.kt
Acceptance Criteria:
- AC1: **On-device log.** Each app keeps its last 500 log entries in a file on the device, and also writes them to the system log (iOS `os.Logger`, subsystem `app.mekasa`; Android Logcat, tag `Mekasa`):
  - **Entry:** time, level (`debug`, `info`, `warning`, `error`), category (`api`, `session`, `receipt`, `photos`, `scanner`, `auth`, `app`), message, optional `request_id` / `correlation_id`, and a few named fields.
  - **API calls:** one entry per call with method, path, status (or the network error), duration and both ids (NFR-006 AC7).
  - **Errors:** one `error` entry wherever the app shows an error or gives up on a call, naming the place (e.g. `receipt.scan`), the error type and its message.
  - **Breadcrumbs:** key actions such as receipt scan started / finished, items saved, sign-in and sign-out.
- AC2: **Automatic error reports.** Every `error` entry becomes a report: the entry, the HTTP status, path and ids of the failed call when there is one, and the 20 entries before it.
  - **Queue:** reports are kept in a file (at most 50; the oldest are dropped) and sent in batches of up to 20 to `POST /v1/client-errors` while signed in, shortly after an error and when the app returns to the foreground. A report is removed once the server accepts it.
  - **No loops:** a failed report upload is retried later and never creates a report itself.
  - **Off in tests:** preview, UI-test and unit-test runs never upload.
- AC3: **Error report API.** `POST /v1/client-errors` (bearer token) takes `{app, reports}`: `app` is the platform, app version, build, OS version and device model; up to 20 reports with up to 30 breadcrumbs each.
  - **Logs:** one `client.error` WARNING per report with the app fields, `report_id`, `where`, `error_type`, `error_message`, `status`, `path`, `app_request_id` and the breadcrumbs. The line's `correlation_id` is the failed call's correlation ID when the report has one, so one Cloud Logging search shows the app's and the API's side together.
  - **Limits:** at most 120 reports per user per hour; the rest are dropped. The response is `202` with `accepted` and `dropped` counts.
- AC4: **Diagnostics API.** `POST /v1/client-diagnostics` (bearer token) takes `{app, note, entries}` with up to 500 entries:
  - **Logs:** one `client.diagnostics` INFO line (app fields, entry count, note) and one `client.log` line per entry (`diagnostics_id`, `seq`, `client_level`, category, message, fields), each with the entry's correlation ID when it has one.
  - **Reference:** the response is `201` with `diagnostics_id` (the upload's request ID) and `reference`, its first 8 characters.
  - **Limits:** at most 10 uploads per user per hour; more return `429`.
- AC5: **Send diagnostics.** Family → Help shows "Send diagnostics" with the line "Sends this phone's recent app log to Mekasa support." Tapping it uploads the on-device log (AC4) and then shows "Sent. Reference ABCD1234", or "Couldn't send diagnostics. Try again." on failure. It is disabled while sending and in the offline preview.
- AC6: **Crashes.** Both apps report crashes to Firebase Crashlytics with the last on-device log entries attached as Crashlytics logs and the user identified only by `user_ref` (NFR-006 AC6). Collection is off in debug builds, previews, UI tests and when Firebase is not configured. The iOS build uploads dSYMs when the real `GoogleService-Info.plist` is present.
- AC7: **Privacy (NFR-002 AC3).** Apps never log bearer tokens, passwords, email addresses (masked in messages), street addresses, phone numbers, or household and person names; item names, receipt line text and barcodes are allowed. The server applies NFR-006 AC6 scrubbing again before logging.

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

## Receipt Intelligence (Gemini parser) — REQ-RCP-001 … REQ-RCP-022

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
- AC3: Legacy fields `name`, `quantity`, `price_paid`, `image_url`, `identified` are derived so existing clients render the haul unchanged; `quantity` follows AC5 for weighed lines
- AC4: Receipt `line_item_count` and `unresolved_count` are maintained
- AC5: Weighed lines (`unit` ∈ `lb`, `oz`, `kg`, `g`, e.g. bananas "2.41 lb @ 0.50/lb") count as one unit as sold — a bunch, a bag, a piece — so `quantity = 1`; `qty`, `unit`, and `unit_price` keep the weight and per-unit price, and `price_paid` is the printed line total. Only count units (`each`, `pack`, or none) derive `quantity` from `qty` (rounded, min 1). The user can change `quantity` before confirming (REQ-RCP-019 AC1). (Decided 2026-10-04.)

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
- AC5: Until receipts are persisted (REQ-RCP-006), `POST …/receipts/scan` matches each line against the shared catalog before Open Food Facts, in this order: the printed `receipt_code` as a UPC (8–14 digits) or PLU (4–5 digits, `plu:<code>`); then the normalized `receipt_text` in `product_aliases` for the detected chain; then the same text under `unknown`. The detected chain is `store_chain_id` on the response: the printed store name matched against the `store_chains` names and aliases, or `unknown`. A catalog hit returns the line `identified=true` with the product's name, category, UPC and image (a user capture photo is served as `/v1/product-photos/{photo_id}`), plus `matched_product_id` and `match_method` (`upc`, `plu`, `alias`); Open Food Facts hits carry `match_method=open_food_facts`. Only lines the catalog does not know go to Open Food Facts. The scan writes nothing to the catalog; aliases are written by capture (REQ-RCP-020 AC6) and confirmation (REQ-RCP-013). If the catalog is unavailable, the scan falls back to Open Food Facts alone. (Decided 2026-10-04.) Lines the catalog does not know are checked against the standard produce list (REQ-RCP-022) before Open Food Facts. (Amended 2026-10-05.)
- AC6: A slow or unreachable catalog never stalls the scan: waiting for a catalog connection is capped at 3 s (`DATABASE_POOL_TIMEOUT_SECONDS`), and after the first catalog error in a scan the remaining lines skip the catalog and continue with the produce list (REQ-RCP-022) and Open Food Facts, so an outage adds about 3 s rather than 30 s per batch of lines. The iOS client allows 120 s for the scan request, because Gemini on a long receipt plus Open Food Facts can approach the 60 s default. (Decided 2026-10-05.)

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
- AC5: The salt is a random per-environment value held in Secret Manager (`mekasa-catalog-salt`, injected as `CATALOG_HOUSEHOLD_SALT`) and never changes once hashes exist. In `ENVIRONMENT=prod` the API refuses to compute a household hash with the built-in development salt, so a missing secret fails the catalog write instead of storing guessable hashes

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
- AC5: Inventory uses the line's `quantity` (one bunch for a weighed line, REQ-RCP-006 AC5); the purchase event carries `price_paid` plus `qty`, `unit`, `unit_price`, so spending stays exact while inventory counts what the household handles. Weight never becomes an inventory quantity

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

### REQ-RCP-019: User Corrections to Product Details and Image
Priority: P0
Description: **When** a user views a receipt line, an inventory item, or the
product behind either, the system **shall** let them correct every
user-facing attribute — name, brand, category, unit size, quantity, price —
and replace the product image with a photo they take or pick, so that
mis-parsed or mis-matched products never have to be accepted as-is.
Design Artifact: design/mockups/AddItems.jsx (confirm haul), design/mockups/ItemDetail.jsx
Test File: tests/backend/test_product_corrections.py
Acceptance Criteria:
- AC1: `PATCH …/line-items/{lid}` accepts `name`, `brand`, `category`, `unit_size`, `qty`, `unit`, `quantity`, `price_paid`, `unit_price`, and `photo_id`; the edit is stored on the line (`user_edited_fields` lists the fields) and is what `confirm` writes to inventory and purchases
- AC2: A correction of `category` (or any attribute) on a line that is `auto_matched`/`confirmed` keeps the link to the product; the line stores the override and `POST /v1/catalog/products/{id}/corrections` is offered as a separate, explicit step ("also fix it for everyone")
- AC3: `POST /v1/catalog/products/{id}/corrections` on an `unverified` or `pending` product applies the correction directly, appends `user_scan` to `sources_seen`, resets `confirmation_count` to 0 and `status` to `unverified` when `name`, `brand`, `upc`, or `category` changed; on a `verified` product the row is left untouched and a `product_conflicts` record (`field` ∈ name, brand, unit_size, category, upc, image_url) is written and returned
- AC4: The product image can be replaced on a line and an inventory item with a household-private photo (REQ-INV-019); replacing the *shared* product image through a correction (`photo_id` on `POST /v1/catalog/products/{id}/corrections`) remains Deferred. Sharing a photo with a UPC happens only through the product capture flow (REQ-RCP-020 AC5, REQ-RCP-021)
- AC5: Corrections are attributed only by `household_hash`; no user id or household id is written to the shared catalog (NFR-002 AC1)
- AC6: Inventory corrections keep working through the existing `PATCH …/inventory/{item_id}` (`name`, `category`, `quantity`, `price_paid`, `barcode`, `image_url`), which now also accepts `photo_id`

### REQ-RCP-020: Scan and Photograph a Product When the UPC Is Not Discovered
Priority: P0
Description: **If** a receipt line has no discovered UPC after parsing,
alias lookup, scan-event correlation, and enrichment (`matched_product_id`
is `null` or an `llm:`/`plu:` key), **then** the system **shall** offer the
user an in-app capture flow: scan the product's barcode with the camera and
take a picture of the product, and **shall** create or link the shared
product from that capture.
Design Artifact: design/pages/scan-receipt-results.html, design/pages/scan-barcode.html, design/pages/scan-picture-step.html, design/pages/scan-plu-entry.html, design/pages/scan-new-product.html, design/pages/scan-haul-summary.html, design/pages/scan-photo-only.html (AC15), design/pages/scan-flow-component-sheet.html (exported 2026-10-04 from the Superdesign project "Mekasa v1.0" after revising the drafts for AC7–AC14, REQ-RCP-021 AC7, REQ-017 AC4 and NFR-005 in the Rich & Grounded palette; the component sheet holds the chips, error states, photo thumbnail, sharing sheet and save-button states); earlier: design/mockups/AddItems.jsx
Test File: tests/backend/test_line_item_capture.py
Acceptance Criteria:
- AC1: Every line whose `barcode` is `null` exposes `capture_available=true`; the confirm-haul screen shows a "Scan product" action on such lines (and on `needs_review`/`unresolved` lines regardless of barcode). Until the Haul Summary (AC8) ships, the iOS confirm-haul card asks for the capture as a local item: "This looks like a local {store} item. Scan its barcode and take a picture so Mekasa recognizes it next time." ("a local item" when the receipt prints no store), with the button "Scan & photograph"; the capture screen repeats the message under the item's name. (Decided 2026-10-05.)
- AC2: `POST …/line-items/{lid}/capture` takes exactly one of `upc` (8–14 digits) or `plu_code` (4–5 digits, AC7) — or neither, with receipt text, under AC15 — plus optional `photo_id`, `name`, `brand`, `category`, `unit_size`; when a product with that UPC exists the line is linked to it (`match_method=user`, `resolution_status=confirmed`) and REQ-RCP-013 counting applies; when none exists a new `products` row keyed by the UPC is created with `source=user_scan`, `confidence_score=0.9`, attributes from the request falling back to the line's description and category, and `image_url` from `photo_id` when given
- AC3: When the line previously pointed at an `llm:` product, the capture re-keys it under the REQ-RCP-010 AC2 rules in the same transaction (`superseded_by`, alias repoint, `receipt_line_items` repoint)
- AC4: The capture records a `scan_events` entry (`context=receipt_capture`, `outcome=found|created`) correlated with the receipt and line, and an `enrichment_jobs` row for the new UPC so store/registry adapters can fill in missing attributes later
- AC5: Barcode scanning uses the existing camera scanner; the photo step is optional and may be skipped — a capture with `upc` alone is valid. A capture photo is uploaded through REQ-RCP-021 (`POST …/product-photos`) and is shared with the UPC: it becomes the product's `image_url` when the product has none, the line's image when it already has one, or a `product_conflicts` proposal when the product is `verified` (`photo_applied_as`)
- AC6: The same capture works from inventory: `POST …/inventory/{item_id}/capture` with the same body links or creates the product and sets `inventory_items.barcode`, `product_id`, `image_url`. When the item came from a receipt, the request may also carry the line's `receipt_text` and the scan's `store_chain_id` (REQ-RCP-007 AC5); the normalized text is then upserted into `product_aliases` under that chain (an unrecognised chain falls back to `unknown`; an alias mapped to a different product is never overwritten). The photo and the receipt text are sent in the same capture, so the next scan of that receipt text matches the product with the user's photo. (Decided 2026-10-04.)
- AC7: Produce lines (category `Produce`, or a printed 4–5 digit code) are captured by typing the PLU from the sticker — no camera viewfinder, since barcode scanners cannot read most PLU stickers — plus the optional photo. A capture with `plu_code` links to or creates the shared product `plu:<code>` (`code_kind=plu`, shared across chains, REQ-RCP-010 AC9) with the same `source`, confidence, alias, photo and `scan_events` rules as a UPC capture; it is never re-keyed to a UPC and, having no UPC, stays at most `pending` (REQ-RCP-011). (Decided 2026-10-04.)
- AC8: The flow ends on one review screen, the Haul Summary, which replaces the earlier confirm-haul list and keeps REQ-005 AC2/AC6: every line shows its code and, when it needs action, a status chip (AC11); lines still missing a code show "Scan →" (re-entering the capture for that line), and tapping any row opens an edit sheet with name, quantity, price, category, photo, and catalog search. Nothing saves until the user taps the add-to-inventory button. (Decided 2026-10-04.)
- AC9: Capture usually happens at home while unpacking the groceries, not in the store, so copy and flow assume the product is in hand with time to spare (no store-aisle wording; skipping stays available for items already used or thrown away). After a code is captured the screen shows one of two cards: a **catalog match** (name, category, size, image) with "Looks right — next" and a "Not this product?" action that discards the code and returns to scanning; or a **new product** card (the code is unknown to the catalog) with editable name and category, pre-filled from the receipt line, whose values become the `name`/`category` of the capture. Brand and size are left to enrichment (AC4). (Decided 2026-10-04.)
- AC10: The scan step offers two distinct exits. **"Skip this item"** leaves the line as parsed; it stays "Needs scan" on the Haul Summary with "Scan →". **"No barcode on this item"** (deli, bakery, butcher counter) opens a photo + name/category step and saves the line as a household item with no code: nothing is written to the shared catalog, and the photo is household-private (REQ-INV-019). The choice is remembered for the household per store chain and normalized receipt text (`POST …/line-items/{lid}/no-barcode`, stored in Firestore `households/{hid}/no_barcode_aliases/{chain}:{alias}`, never in Postgres — NFR-002): later lines with the same text get `capture_available=false` and `no_barcode=true`, show "No barcode" in place of a code on the Haul Summary instead of "Scan →", and reuse the remembered name and category. The edit sheet's "This item has a barcode" action deletes the memory (`DELETE …/line-items/{lid}/no-barcode`) and restores the scan action. (Decided 2026-10-04.)
- AC11: Haul Summary chips appear only on lines that need action: **"Needs scan"** (no code and not `no_barcode`; paired with "Scan →") or **"Needs info"** (has a code but name or category is still unconfirmed, e.g. `needs_confirmation`). Ready lines (matched, captured, or `no_barcode`) carry no chip and show only their code (UPC or PLU) or the plain text "No barcode". The headline counts remaining work ("6 of 7 ready · 1 needs a scan") and reads "All set" only when no line needs action; the add-to-inventory button stays enabled either way, since skipped lines save as parsed (AC10). (Decided 2026-10-04.)
- AC12: The scan step handles failures in place, without an offline queue. **Camera permission denied:** a full-screen explainer with "Open Settings", "Type the code instead" (the same typed entry used for PLU, AC7, accepting 8–14 digit UPCs) and "Skip this item". **Barcode not read:** after about 5 seconds without a read the viewfinder shows a "Type the code" hint; typing is always available. **Offline:** the step shows "You're offline — captures need a connection", no capture is sent or queued, and the line stays "Needs scan" (AC11) to finish later from the Haul Summary. **Capture save fails** (5xx, timeout, photo upload error): an inline error on the card with "Try again" that resubmits without losing the code, photo, name or category; client errors such as `invalid_upc` or `invalid_plu` show their message beside the code field instead. (Decided 2026-10-04.)
- AC13: After the shutter the flow returns straight to the catalog match or new-product card (AC9), which shows the photo as a thumbnail; there is no separate preview screen. Tapping the thumbnail opens the photo full size with "Retake" (reopens the camera and replaces the photo) and "Remove" (the capture continues without a photo, AC5). The photo is uploaded only when the card is submitted, so retaking or removing before then sends nothing to the shared catalog. (Decided 2026-10-04.)
- AC14: The new-product card's save button reads "Save as {name}" and follows the name field live as the user types; names longer than about 24 characters are truncated with "…" so the button stays on one line (the full name stays visible in the field and is announced in full by VoiceOver/TalkBack). With the name empty or whitespace the button reads "Save product" and is disabled. (Decided 2026-10-04.)
- AC15: A capture from a receipt line may be saved with a photo and no code, when the product has no barcode or PLU or the user did not scan one. This contributes the item's name, category and photo to the shared catalog, so the next scan of that receipt text at that chain matches it with the photo:
  - **Request:** the capture body carries the line's `receipt_text` (and the scan's `store_chain_id`) but neither `upc` nor `plu_code`. A capture with no code and no receipt text is still rejected with `exactly_one_code_required`.
  - **Product:** the catalog links the alias already recorded for that text under the chain, if there is one. Otherwise it links or creates the chain's product `llm:<sha1(chain|normalized name)>` (`code_kind=llm`, the chain from REQ-RCP-007 AC5, or `unknown`). The product gets `source=user_scan` and `confidence_score=0.9`, takes the name and category from the request or the item, and the photo follows the AC5 rules.
  - **Alias:** the normalized receipt text is recorded under that chain only.
  - **Inventory item and events:** the item gets the product's `product_id` and no barcode. The `scan_events` entry carries no code, and no enrichment job is queued (the adapters look products up by UPC).
  - **Later code:** a code added later for the same inventory item re-keys that product, so its photo, aliases and confirmations move to the code's product. A UPC re-keys under AC3. A PLU re-keys into the shared `plu:<code>` product, which keeps the photo when it has none. AC7 still holds: a PLU product is never re-keyed to a UPC.
  - **Adding a code from item detail:** both apps' item detail offers "Add barcode or PLU" on an item with no barcode whose product is missing or `llm:`. It scans or types the code and sends it through the inventory capture, with no photo required.
  - **Nutrition:** adding a code is what unlocks nutrition. After a UPC is added, the app refreshes the item's health grade right away (`POST …/inventory/{item_id}/refresh-health`, REQ-021 AC4). PLU produce has no nutrition source yet, so a PLU links the product but adds no health grade.
  - **Apps:** the iOS and Android capture screens show the REQ-RCP-021 AC7 sharing label and one-time sheet on the photo step whenever the line has receipt text, not only after a code is scanned.
  - **Copy:** once a photo is taken without a code, the barcode step reads "No barcode scanned — the photo and name are shared for {store} receipts" ("for these receipts" when the receipt prints no store). The confirm-haul card then shows a "Shared photo" label and "No barcode · matched by receipt text next time".
  - **Design:** design/pages/scan-photo-only.html (Superdesign "Mekasa v1.0", draft "Photo-only Capture", 2026-10-06).
  - **Private exception:** the explicit "No barcode on this item" choice (AC10) still keeps its photo household-private and writes nothing to the catalog.
  - (Decided 2026-10-05.)

### REQ-RCP-021: Product Photo Upload and Storage
Priority: P0
Status: Active (2026-10-04) for photos taken in the product capture flow
(REQ-RCP-020): the capture is the explicit sharing action, and its photo is
shared with the scanned UPC or PLU, or with the receipt text's product when
no code was captured (REQ-RCP-020 AC15, 2026-10-05). Was Deferred 2026-10-03. Item-picture
replacements from item detail stay household-private (REQ-INV-019) and do
not use these endpoints.
Description: The system **shall** accept product photos taken by users
during a product capture, store them without personal metadata, and serve
them to any signed-in user through a stable URL that carries no household
or user identifier, so that user photos can safely back shared catalog
images.
Design Artifact: design/pages/scan-picture-step.html, design/pages/scan-new-product.html, design/pages/scan-flow-component-sheet.html (sharing label and one-time sheet)
Test File: tests/backend/test_product_photos.py
Acceptance Criteria:
- AC1: `POST …/households/{hid}/product-photos` accepts a JPEG/PNG/HEIC ≤ 8 MB (base64 JSON or multipart), re-encodes it as JPEG with EXIF/GPS stripped, limits the long edge to 1600 px, and returns `photo_id` (UUID v4) and `image_url=/v1/product-photos/{photo_id}`
- AC2: Objects are stored in bucket `mekasa-product-photos-<env>` at `product-photos/{photo_id}.jpg` (no household or user id in the object name); the uploading household and uid are recorded only in Firestore `households/{hid}/product_photos/{photo_id}`
- AC3: `GET /v1/product-photos/{photo_id}` requires a bearer token (any household) and 302-redirects to a signed URL valid ≤ 15 minutes; it never exposes the bucket path or the uploading household
- AC4: A photo not referenced by any line item, inventory item, or product within 24 h is deleted by the daily cleanup job; referenced photos are retained while referenced
- AC5: A photo referenced by a shared product (`image_source=user_photo`) stays available even if the uploading household deletes its inventory item; the household can request removal via `DELETE …/product-photos/{photo_id}`, which replaces the catalog image with the next-best source or a category placeholder
- AC6: Photo bytes never appear in logs; uploads are rejected (`415 unsupported_media_type`, `413 payload_too_large`) rather than truncated
- AC8: With `PRODUCT_PHOTO_BUCKET` unset (local, tests) the API keeps photos and ownership records in memory with the same endpoints and rules, and `GET /v1/product-photos/{photo_id}` serves the bytes (`200`) instead of redirecting
- AC7: The capture screen's photo step states, before the photo is taken, that the picture will be shown with this product to other Mekasa households; the photo step stays optional (REQ-RCP-020 AC5). The first time a signed-in user reaches the photo step, a one-time sheet explains that product photos are shared with all Mekasa users while item-detail photos stay private to the household (REQ-INV-019), and asks them to keep people, faces and receipts out of the shot; it closes with "Got it", and that is remembered on the device per user. After that, the photo step shows only a short "Shared with all users" label with an info button that reopens the sheet. Copy never says the photo is shared only with the household. (Decided 2026-10-04.)

### REQ-RCP-022: Standard Produce PLU List
Priority: P1
Description: When a receipt line prints a standard produce PLU code that the
shared catalog does not know yet, the system **shall** identify the line from
a bundled list of standard IFPS PLU codes, so that common produce is
recognized on the first scan without asking Open Food Facts, whose PLU
entries are user-contributed and often in another language (checked
2026-10-05: 94011 returns a Danish product with no English name).
Design Artifact: n/a (backend only; the line shows as identified in the existing confirm-haul card)
Test File: tests/backend/test_produce_plu.py
Acceptance Criteria:
- AC1: The list is bundled with the API (`backend/app/data/plu_codes.json`, the MIT-licensed IFPS-derived list from `github.com/ankane/plu`, with its license file) and loaded once per process; no network call is made. Entries named "Retailer Assigned…" are excluded, because stores reuse those codes for different products
- AC2: A 4-digit code `3000`–`4999` uses its list entry. A 5-digit code starting with `9` is the organic version of its last four digits and its name is prefixed "Organic ". Other 5-digit codes (for example the reserved `8` prefix) are not identified
- AC3: Display names drop parenthetical notes and repeated whitespace and are cut to 120 characters, e.g. 4048 "Regular (incl. Persian, Tahiti & Bearss) Limes" → "Regular Limes", 94011 → "Organic Bananas"
- AC4: The list is used only when the parser's category for the line is Produce or the line's receipt text or name shares a word with the list name, so that a 4–5 digit store item number on a non-produce line is not taken for produce
- AC5: Order within REQ-RCP-007 AC5: printed code in the catalog → alias for the chain → alias under `unknown` → this list → Open Food Facts. A catalog product for the same `plu:<code>` (for example one with a user photo from REQ-RCP-020) always wins over the list
- AC6: A list hit returns the line `identified=true` with the list name, category Produce, no barcode, the Produce placeholder image, `match_method=plu_standard` and `matched_product_id=null` (nothing is written to the catalog). The list still applies when the catalog is unavailable
- AC7: The parser prompt asks for produce PLU codes in `receipt_code` as well as UPCs and item numbers
