# Mekasa Traceability Matrix

Spec version: 1.0  
Last updated: 2026-09-25

| Requirement ID | Description | Design Artifact | Test Case ID | Test File | Status | Last Verified |
|----------------|-------------|-----------------|--------------|-----------|--------|---------------|
| REQ-001 | Household Account Creation | — | done (iOS Welcome: Apple/Google/email) | pending (console Apple provider) | unit (nonce) | AuthService.signInWithApple |
| REQ-002 | Household Naming and Photo | design/mockups/OnboardingHouseholdSetup.jsx | done | done | unit (backend photo) | HouseholdSetupView + Dashboard backdrop |
| REQ-003 | Home Address Detection and Store Discovery | design/mockups/OnboardingStoreSelection.jsx | done | done | unit (places/stub) | StoreSelectionView + Places lookup |
| REQ-004 | Barcode Scanning and Product Lookup | design/mockups/AddItems.jsx | pending | pending | not tested | — |
| REQ-005 | Receipt Scanning and Bulk Entry | design/mockups/AddItems.jsx | done | done | unit (OCR parse) | ReceiptScanView + ItemConfirmView |
| REQ-006 | Manual Item Entry | design/mockups/AddItems.jsx | pending | pending | not tested | — |
| REQ-007 | Voice Input for Item Entry | design/mockups/AddItems.jsx | VoicePhraseParserTests | ios/MekasaTests/VoicePhraseParserTests.swift | unit (phrase parse + match draft) | 2026-09-19 |
| REQ-008 | Trash Station Consumption Scanning | design/mockups/TrashStationMode.jsx | done | done | unit (consume+unknown) | TrashStationView barcode consume |
| REQ-009 | Low Stock Threshold — Manual | design/mockups/Dashboard.jsx | done | done | unit (PATCH threshold) | ItemDetailView |
| REQ-010 | Low Stock Threshold — Learned | — | pending | pending | not tested | — |
| REQ-011 | Automatic Shopping List Addition | design/mockups/ShoppingList.jsx | pending | pending | not tested | — |
| REQ-012 | Child Shopping Request Submission | design/mockups/ShoppingList.jsx | pending | pending | not tested | — |
| REQ-013 | Request Approval Workflow | design/mockups/ShoppingList.jsx | pending | pending | not tested | — |
| REQ-014 | Shopping List Purchase Restriction | design/mockups/ShoppingList.jsx | test_shopping_list_purchase_gate | tests/backend/test_shopping_list_purchase_gate.py | unit (owner/buyer gate) | 2026-09-19 |
| REQ-015 | Price Capture from Receipt | — | pending | pending | not tested | — |
| REQ-016 | Price Estimation Fallback | — | pending | pending | not tested | — |
| REQ-017 | Spending Categorization | — | pending | pending | not tested | — |
| REQ-018 | Spending History Reporting | design/mockups/SpendingReport.jsx | pending | pending | not tested | — |
| REQ-019 | Household Member Invitation | design/mockups/FamilyMembers.jsx | done | done | unit (invites API) | InviteView + FamilyMembersView |
| REQ-020 | Real-Time Multi-Device Sync | — | FirestoreDocumentMapperTests | ios/MekasaTests/FirestoreDocumentMapperTests.swift | unit (doc map) + listeners | 2026-09-19 |
| REQ-022 | Expired Session Auto Sign-Out | design/mockups/OnboardingHouseholdSetup.jsx | SessionExpiryTests / test_auth_session | ios/MekasaTests/SessionExpiryTests.swift; tests/backend/test_auth_session.py | implemented | 2026-09-10 |
| UI-001 | Native Android Interface | design/mockups/ (all screens); design/baselines/android/ | android-fable Layer 1 (*UITest) + Layer 2 (ScreenSnapshotTest, 16 baselines) | android-fable/app/src/test/java/app/mekasa/fable/ui/*UITest.kt; android-fable/app/src/test/java/app/mekasa/fable/ui/ScreenSnapshotTest.kt | tested (Robolectric structural + Roborazzi snapshot, CI job android-fable) | 2026-09-25 |
| UI-002 | Native iOS Interface | design/mockups/ (all screens) | pending | ios/MekasaTests/UI/ | not tested | — |
| UI-003 | Onboarding Flow | design/mockups/OnboardingStoreSelection.jsx; design/baselines/android/{Welcome,HouseholdName,Address,StoreSelection}_baseline.png | OnboardingUITest (Android); ScreenSnapshotTest.welcome/householdName/address/storeSelection | android-fable/app/src/test/java/app/mekasa/fable/ui/OnboardingUITest.kt; ios/MekasaTests/UI/OnboardingUITest.swift | tested (Android structural + snapshot); iOS pending | 2026-09-25 |
| UI-004 | Home Dashboard | design/mockups/Dashboard.jsx; design/baselines/android/Dashboard_baseline.png | DashboardUITest (Android); ScreenSnapshotTest.dashboard | android-fable/app/src/test/java/app/mekasa/fable/ui/DashboardUITest.kt; ios/MekasaTests/UI/DashboardUITest.swift | tested (Android structural + snapshot); iOS pending | 2026-09-25 |
| UI-005 | Trash Station Mode | design/mockups/TrashStationMode.jsx; design/baselines/android/TrashStation_baseline.png | TrashStationModeUITest (Android, kiosk + dispose; camera fallback on JVM); ScreenSnapshotTest.trashStation | android-fable/app/src/test/java/app/mekasa/fable/ui/TrashStationModeUITest.kt; ios/MekasaTests/UI/TrashStationUITest.swift | tested (Android structural + snapshot); iOS pending | 2026-09-25 |
| UI-006 | Inventory List Thumbnails and Item Detail | design/pages/inventory-list.html; design/pages/item-detail.html; design/mockups/InventoryList.jsx; design/mockups/ItemDetail.jsx; design/baselines/android/{InventoryList,InventorySwipeUseOne,InventorySwipeRemove,InventoryUndoToast,ItemDetail}_baseline.png | InventoryScreenUITest + ItemDetailUITest (Android, incl. REQ-INV-014..017 swipe/undo via performTouchInput); ScreenSnapshotTest.inventory*/itemDetail; ios/Tests/UI/Structure/UI006StructureTests.swift; ios/Tests/Snapshots/UI006SnapshotTests.swift | android-fable/app/src/test/java/app/mekasa/fable/ui/InventoryScreenUITest.kt; android-fable/app/src/test/java/app/mekasa/fable/ui/ItemDetailUITest.kt; ios/Tests/UI/Structure/UI006StructureTests.swift | tested (Android structural + snapshot; iOS structural + snapshot) | 2026-09-25 |
| NFR-001 | Scan Performance | — | pending | pending | not tested | — |
| NFR-002 | Data Privacy | — | pending | pending | not tested | — |
| NFR-003 | Offline Resilience | — | pending | pending | not tested | — |
| NFR-004 | Secrets Management | — | pending | pending | not tested | — |
