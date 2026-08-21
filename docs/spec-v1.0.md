# Mekasa Specification v1.0

> **Note:** Full functional (REQ-*) and nonfunctional (NFR-*) requirement text
> will be replaced in Step 11 with the authoritative product owner document.
> UI-001 through UI-005 below are seeded now with Design Artifact links (Step 9).
> Placeholder REQ/NFR stubs exist so the traceability matrix can reference stable IDs.

**Spec version:** 1.0  
**Status:** scaffold / partial seed

---

## Functional Requirements (placeholders pending Step 11)

### REQ-001: User Authentication
Priority: P0  
- AC1: Users can sign in securely  
- AC2: Sessions expire appropriately  
- AC3: Unauthorized access is rejected  

### REQ-002: Household Creation
Priority: P0  
- AC1: User can create a household with name  
- AC2: Optional home photo can be attached  
- AC3: Creator becomes household admin  

### REQ-003: Household Membership and Roles
Priority: P0  
- AC1: Admins can invite members  
- AC2: Role-based permissions enforced  
- AC3: Members can leave or be removed  

### REQ-004: Address Confirmation via GPS
Priority: P0  
- AC1: Device GPS used for address suggestion  
- AC2: Reverse geocoding produces confirmable address  
- AC3: User can correct address before save  

### REQ-005: Preferred Store Selection
Priority: P0  
- AC1: Nearby stores discovered within 15-mile radius  
- AC2: User can select preferred stores  
- AC3: Selection persists for the household  

### REQ-006: Inventory Item CRUD
Priority: P0  
- AC1: Items can be created, read, updated, deleted  
- AC2: Quantity and category supported  
- AC3: Changes sync across household devices  

### REQ-007: Initial Inventory Scan
Priority: P0  
- AC1: Onboarding supports first inventory capture  
- AC2: Scanned items appear in inventory  
- AC3: User can skip and add later  

### REQ-008: Barcode Lookup
Priority: P0  
- AC1: UPC/barcode resolves product metadata  
- AC2: Failures surface actionable errors  
- AC3: Manual fallback available  

### REQ-009: Receipt OCR
Priority: P0  
- AC1: Receipt image processed via Cloud Vision  
- AC2: Line items extracted into candidates  
- AC3: User confirms before committing  

### REQ-010: Voice Item Input
Priority: P1  
- AC1: Voice utterance parsed into item draft  
- AC2: User confirms draft before save  
- AC3: Unsupported locales handled gracefully  

### REQ-011: Manual Item Entry
Priority: P0  
- AC1: User can enter name, qty, category manually  
- AC2: Validation prevents empty required fields  
- AC3: Saved item appears in inventory  

### REQ-012: Shopping List Generation
Priority: P0  
- AC1: List auto-generated from inventory thresholds  
- AC2: User can add/remove list items  
- AC3: List shared with household in realtime  

### REQ-013: Shopping List Approvals
Priority: P1  
- AC1: Requests can be approved or rejected  
- AC2: Requester notified of decision  
- AC3: Only authorized roles may approve  

### REQ-014: Spending by Category
Priority: P0  
- AC1: Purchases attributed to categories  
- AC2: Reports aggregate by period  
- AC3: Household members see consistent totals  

### REQ-015: Trash Station Mode
Priority: P0  
- AC1: Mode supports quick depletion of items  
- AC2: Depleted items update inventory and list  
- AC3: Mode is reachable from Add Items flow  

### REQ-016: Realtime Sync
Priority: P0  
- AC1: Inventory and list changes propagate in realtime  
- AC2: Conflict handling is deterministic  
- AC3: Offline changes reconcile on reconnect  

### REQ-017: Push Notifications
Priority: P1  
- AC1: Members receive relevant household alerts  
- AC2: Notification preferences are respected  
- AC3: No PII leaked in notification payloads beyond necessity  

### REQ-018: Home Photo Storage
Priority: P2  
- AC1: Photos stored in Cloud Storage  
- AC2: Access limited to household members  
- AC3: Failed uploads surface retry  

### REQ-019: Places Discovery
Priority: P0  
- AC1: Google Places used within 15-mile radius  
- AC2: Results include name and location  
- AC3: API errors degrade gracefully  

### REQ-020: Secrets Management
Priority: P0  
- AC1: All secrets via GCP Secret Manager  
- AC2: No secrets in source or logs  
- AC3: Rotation procedure documented  

---

## UI Requirements

### UI-001: Home Dashboard
Priority: P0  
Design Artifact: design/mockups/Dashboard.jsx  
User Flow: design/user-flows.md  
- AC1: Built entirely in Jetpack Compose (Android) / SwiftUI (iOS), no XML or Storyboards  
- AC2: Follows Material Design 3 (Android) / Apple HIG (iOS)  
- AC3: Supports light and dark mode  
Test File: android/src/test/ui/DashboardUITest.kt  
iOS Test File: ios/MekasaTests/UI/DashboardUITest.swift  

### UI-002: Onboarding Store Selection
Priority: P0  
Design Artifact: design/mockups/OnboardingStoreSelection.jsx  
User Flow: design/user-flows.md  
- AC1: Presents nearby stores discovered within 15 miles  
- AC2: User can select and confirm preferred stores  
- AC3: Navigation continues to Initial Inventory Scan on confirm  
Test File: android/src/test/ui/OnboardingUITest.kt  
iOS Test File: ios/MekasaTests/UI/OnboardingUITest.swift  

### UI-003: Shopping List
Priority: P0  
Design Artifact: design/mockups/ShoppingList.jsx  
User Flow: design/user-flows.md  
- AC1: Displays household shopping list items  
- AC2: Supports add/remove and approval actions where authorized  
- AC3: Reflects realtime sync updates  
Test File: android/src/test/ui/ShoppingListUITest.kt  
iOS Test File: ios/MekasaTests/UI/ShoppingListUITest.swift  

### UI-004: Add Items
Priority: P0  
Design Artifact: design/mockups/AddItems.jsx  
User Flow: design/user-flows.md  
- AC1: Entry points for barcode, receipt, voice, manual, and trash-station modes  
- AC2: Each path produces a confirmable item draft  
- AC3: Successful save returns user to inventory or dashboard as specified in user flows  
Test File: android/src/test/ui/ScannerUITest.kt  
iOS Test File: ios/MekasaTests/UI/ScannerUITest.swift  

### UI-005: Trash Station Mode
Priority: P0  
Design Artifact: design/mockups/TrashStationMode.jsx  
User Flow: design/user-flows.md  
- AC1: Enables rapid marking of items as depleted  
- AC2: Updates inventory and shopping list accordingly  
- AC3: Layout and hierarchy match approved design artifact structurally  
Test File: android/src/test/ui/TrashStationModeUITest.kt  
iOS Test File: ios/MekasaTests/UI/TrashStationModeUITest.swift  

---

## Nonfunctional Requirements (placeholders pending Step 11)

### NFR-001: Performance
Priority: P0  
- AC1: API p95 latency within agreed budget  
- AC2: Cold start acceptable for Cloud Run  
- AC3: Mobile screens remain responsive under normal load  

### NFR-002: Security
Priority: P0  
- AC1: Authn/authz on all protected endpoints  
- AC2: Secrets only via Secret Manager  
- AC3: No secrets in client binaries beyond public keys  

### NFR-003: Privacy
Priority: P0  
- AC1: No PII in logs  
- AC2: Location used only for stated features  
- AC3: Privacy policy covers data practices before launch  

### NFR-004: Reliability
Priority: P0  
- AC1: External calls use 10s timeout and 3-retry backoff  
- AC2: Sync recovers after transient network loss  
- AC3: Monitoring alerts on sustained error rates  
