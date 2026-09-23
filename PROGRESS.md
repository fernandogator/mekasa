# Project MEKASA

- **Current Phase:** 3 — Live barcode + UPC lookup
- **Last Updated:** 2026-09-23

> **WARNING:** This file must be reconciled against the actual codebase at the
> start of every session. Never trust this file without verification.

---

## Phase 1: Backend API Foundation

| Module | Status | Test Coverage | Last Error | Next Step |
|--------|--------|---------------|------------|-----------|
| auth | deployed (Firebase verify) | unit + Cloud Run smoke | — | Real Google/email/Apple ID tokens from iOS; keep `ALLOW_TEST_AUTH=false` in prod |
| household | deployed (Firestore) | unit + smoke | — | Confirm live Cloud Run revision uses `HOUSEHOLD_PERSISTENCE=firestore` |
| inventory | deployed (CRUD + consume + member ACL + refresh-image) | unit | — | Redeploy Cloud Run for refresh-image |
| shopping-list | deployed (CRUD + sync + member ACL) | unit | — | Redeploy Cloud Run |
| spending | deployed (purchase events + reports) | unit (test_spending_members_api) | — | — |
| sync | ready (iOS Firestore listeners + rules) | unit (FirestoreDocumentMapperTests) | — | Deploy firestore.rules to mekasa-db |
| ocr | done | unit | — | Vision on Cloud Run when package + API enabled |
| barcode | deployed (Open Food Facts lookup) | unit | — | — |
| places | done | unit | — | Set `GOOGLE_PLACES_API_KEY` on Cloud Run |
| notifications | scaffold (FCM devices + invite hooks) | unit (test_devices_push) | — | APNs key in Firebase + redeploy Cloud Run |
| members/invites | done (Firestore dual-mode) | unit | — | Redeploy for durable invites |

### Live thin API (2026-09-07)

| Item | Value |
|------|--------|
| Cloud Run URL | `https://mekasa-api-934775015882.us-central1.run.app` |
| Project | `hackathon2025-472017` |
| Region | `us-central1` |
| Firestore DB | `mekasa-db` @ `nam5` (Standard, Restrictive) |
| Service account | `mekasa-api@hackathon2025-472017.iam.gserviceaccount.com` |
| Auth (prod) | Firebase ID token; `ALLOW_TEST_AUTH=false` |
| Persistence | Firestore when deployed with `HOUSEHOLD_PERSISTENCE=firestore` |

---

## Phase 2: Android App

| Module | Status | Test Coverage | Last Error | Next Step |
|--------|--------|---------------|------------|-----------|
| onboarding | ready (Welcome → household → address → stores; Firebase Auth + offline / test-token fallback) | stubs + AppSessionTest | — | Drop in real google-services.json for prod sign-in |
| dashboard | ready (summary + low stock + spend card + shell nav) | stubs | — | Home photo upload; expand DashboardUITest |
| inventory-screen | ready (list rows + images via Coil) | stubs | — | Detail + consume; expand InventoryScreenUITest |
| scanner | ready (CameraX + ML Kit barcode + UPC entry + product search + confirm → POST inventory) | stubs + AppSessionTest offline add | — | Receipt / voice parity with iOS |
| shopping-list-screen | ready (read list from API / preview) | stubs | — | Check/approve mutations |
| spending-screen | ready (week report read) | stubs | — | Period toggle + charts |
| settings | ready (profile + sign out + refresh) | stubs | — | Invites / family members API |
| trash-station-mode | stub filename only | stubs | — | Port iOS kiosk mode |

## Phase 3: iOS App

| Module | Status | Test Coverage | Last Error | Next Step |
|--------|--------|---------------|------------|-----------|
| onboarding | ready (scan step wired) | stubs + Features2to6Tests + AppleSignInNonceTests | — | Enable Apple provider in Firebase Console; keep Firebase plist local |
| dashboard | ready (home photo hero + approvals + inventory link) | stubs + HouseholdPhotoTests | — | Notifications; bind spend card to spend API when ready |
| inventory-screen | ready (list + detail + Add hub) | unit | — | Expand InventoryScreenUITest |
| scanner | ready (barcode + receipt + voice match) | unit (VoicePhraseParserTests) | — | Expand ScannerUITest on device |
| shopping-list-screen | ready (API sync + owner purchase gate) | unit | — | Expand ShoppingList UI tests |
| spending-screen | ready (live week/month/year report + local fallback) | unit (DTO decode) | — | Expand SpendingScreenUITest |
| settings / family | ready (invites, roles, ShareLink, accept) | Features2to6Tests | — | APNs delivery for invites (device tokens live) |
| trash-station-mode | ready (kiosk + unknown scans) | Features2to6Tests | — | Home-screen shortcut polish |

## Phase 4: UI Design and Visual Verification

| Module | Status | Test Coverage | Last Error | Next Step |
|--------|--------|---------------|------------|-----------|
| design-system | in progress | — | — | Tokens in `design/design-system.md`; keep synced with canvas |
| superdesign-mockups | ready (P0 approved) | — | — | Canvas + `design/mockups/*.jsx`; human approved P0 for coding |
| android-ui-tests | not started | unknown | — | Expand stubs once screens exist |
| ios-ui-tests | not started | unknown | — | Expand stubs once screens exist |
| baseline-screenshots | not started | unknown | — | Capture from approved mockup renders |
| visual-verification | not started | unknown | — | Wire semantic compare into CI |

## Phase 5: Integration and End-to-End Testing

| Module | Status | Test Coverage | Last Error | Next Step |
|--------|--------|---------------|------------|-----------|
| end-to-end-tests | not started | unknown | — | Define E2E scenarios after API + clients exist |
| performance-tests | not started | unknown | — | Define perf budgets from NFR-001 |
| sync-stress-tests | not started | unknown | — | Define multi-device sync stress plan |

## Phase 6: Launch Prep

| Module | Status | Test Coverage | Last Error | Next Step |
|--------|--------|---------------|------------|-----------|
| app-store-assets | not started | unknown | — | Collect screenshots and store listing copy |
| privacy-policy | not started | unknown | — | Draft privacy policy covering PII and location |
| secrets-rotation | not started | unknown | — | Document Secret Manager rotation per NFR-004 |
| monitoring-setup | not started | unknown | — | Configure Cloud Run / Firebase monitoring |

---

## Running Log

### 2026-09-22 — Dashboard home photo hero + HomePhotoView
- Dashboard top **150px** home photo hero (design system) with gradient + greeting
- Tap hero → `HomePhotoView`: **Take photo** (camera) or **Choose from Photos**, then Save
- `AppSession.uploadHouseholdHomePhoto` → `POST …/households/{id}/photo`

### 2026-09-22 — Home photo name + crop (Save unblocked)
- `HomePhotoView` presented as **fullScreenCover** (tab bar/FAB no longer covers Save)
- House name field (e.g. “The Guerrero Home”) → `PUT …/households/{id}/name`
- Pinch/drag crop canvas exports framed JPEG for the hero
- Header **Save** + bottom **Save**; `saveHomePhotoEdits` persists name and/or photo

### 2026-09-22 — Colocate HomePhotoView for local Xcode
- `HomePhotoView` lives in `DashboardView.swift` (no separate file / xcodegen needed)
- Onboarding household setup also offers Take a photo when camera is available
- Unit: `HouseholdPhotoTests`

### 2026-09-22 — App icon: red house + barcode scan
- Replaced `AppIcon.appiconset/AppIcon.png` (1024×1024) from Superdesign share
  (red house silhouette, barcode + scan line on white)

### 2026-09-20 — Sign in with Apple (REQ-001 AC1)
- Welcome **Continue with Apple** → `ASAuthorization` + Firebase `OAuthProvider.appleCredential`
- Entitlement: `Mekasa/Mekasa.entitlements` (`com.apple.developer.applesignin`)
- Unit: `AppleSignInNonceTests`; backend unchanged (still verifies Firebase ID tokens)
- **Enable Apple** in Firebase Auth + App ID capability before device testing

### 2026-09-20 — Inventory swipe 3-layer UI stubs (UI-006 / REQ-INV-014–018)
- Layer 1: `UI006StructureTests` — list/empty runnable; swipe Use 1 / Remove / Undo XCTSkip stubs
- Layer 2: `UI006SnapshotTests` — list / empty / Undo toast / detail (skip until baselines)
- Layer 3: `Scripts/ui_vision_cases.json` + `verify_ui_vision.py --list-cases`
- Accessibility ids: `InventoryListView`, Use 1 / Remove / Undo toast + button

### 2026-09-20 — Inventory swipe Use 1 / Remove + Undo (REQ-INV-014–018)
- List trailing swipe: qty > 1 → **Use 1** (consume); qty = 1 → **Remove**
- Remove soft-deletes (`deleted` / `deleted_at`), Undo toast 5s, then `POST …/purge`
- Restore via `POST …/restore`; listeners skip soft-deleted docs
- Unit: `InventorySwipeSessionTests`, `test_inventory_soft_delete`
- **Redeploy Cloud Run** for soft-delete / restore / purge routes.

### 2026-09-19 — Realtime sync + push scaffold (REQ-020 / PRD §8)
- iOS: `FirebaseFirestore` + `HouseholdSyncService` listeners on `inventory_items` /
  `shopping_list_items` (named DB `mekasa-db`); offline persistence enabled.
- Mutations remain on Cloud Run; listeners reconcile local caches.
- `firestore.rules` + `firebase.json` — member read, client writes denied.
- Push: `POST/DELETE /v1/devices`, FCM best-effort on invite create/accept;
  iOS `FirebaseMessaging` + APNs registration.
- ShoppingList / Scanner unit stubs filled; Apple Sign-In wired on Welcome (enable provider in Firebase).
- Unit: `FirestoreDocumentMapperTests`, `test_devices_push` (41 backend tests green).
- **Deploy Firestore rules** + **redeploy Cloud Run** (devices + invite push) + APNs key.

### 2026-09-19 — Voice → product catalog match (REQ-007)
- `VoiceSpeechRecognizer` (Speech + mic) transcribes spoken item names.
- `VoicePhraseParser` extracts quantity (“two avocados”, “3 packs of oat milk”).
- After hear/sample, signed-in clients call `GET /v1/products/search` and pick a variant
  (same row UI as manual entry); **Add as spoken** still confirms free-form.
- Sample phrases cover produce + brand search when mic/speech is unavailable.
- Unit: `VoicePhraseParserTests`.

### 2026-09-18 — Backend spending + durable members
- Purchase events + spending reports (`POST …/purchases`, `GET …/spending`, `PATCH …/purchases/{id}`) — REQ-015/017/018.
- Inventory create with `price_paid` also records a purchase event.
- Members/invites Firestore dual-mode; invited members can use inventory/shopping/`/households/current`.
- Unit: 26 backend tests green (`test_spending_members_api`).
- **Redeploy Cloud Run** for prod.

### 2026-09-19 — Shopping list owner purchase gate (REQ-014)
- Backend: only owners (or future `buyer` permission) may set `is_checked`.
- Non-owners creating list rows are forced into `needs_approval` requests.
- Approve/reject are owner-only. Member `permissions` field added for AC3.
- iOS: checkboxes / approve actions gated by `canMarkShoppingPurchased` / `isHouseholdOwner`.
- **Redeploy Cloud Run** for the ACL change.

### 2026-09-19 — Resolve unidentified receipt lines
- Confirm haul: **Find in catalog** / **Change match** opens product search picker.
- Applying a hit sets name, category, barcode, image, and `isIdentified=true` (keeps price/qty).

### 2026-09-19 — Receipt scan enrichment (images + unidentified)
- After OCR, each line is matched via Open Food Facts name search.
- Response includes `image_url`, optional `barcode`, and `identified`.
- Confirm haul UI shows recognition summary, “Not identified” badges, and thumbs.
- **Redeploy Cloud Run** for enriched receipt scan.

### 2026-09-19 — Manual entry product variant search
- Backend `GET /v1/products/search?q=` via Open Food Facts (distinct named variants).
- iOS ManualEntry: **Find matching products** → pick Oreo Double Stuf / Thins / etc. → confirm.
- Free-form **Add as typed** still works for produce / unknown items.
- **Redeploy Cloud Run** for the search route.

### 2026-09-19 — iOS spending API sync
- `GET /v1/households/{id}/spending` wired via `MekasaAPIClient` + `AppSession.refreshSpending`.
- Spend tab shows period picker (week/month/year), category totals, recent purchases.
- Dashboard Spend card uses live weekly total with local inventory fallback.
- Unit: `APIModelsTests.testSpendingReportDecodes`.

### 2026-09-19 — Item detail image refresh
- Backend `POST /v1/households/{id}/inventory/{item_id}/refresh-image` fills
  missing `image_url` via Open Food Facts (or category placeholder) and persists it.
- iOS `ItemDetailView` calls refresh on appear when `imageURL` is nil.
- **Redeploy Cloud Run** for the new route.

### 2026-09-18 — Remaining iOS features + UI polish
- Invite accept deep link `mekasa://invite?token=` + Family ShareLink; trash kiosk `mekasa://trash` / `--trash-station`.
- Onboarding InitialScan wired to barcode / receipt / manual.
- Dashboard approvals from live shopping-list pending; inventory list + Spending local rollup.
- Receipt confirm edits price; unknown trash-scan list; Places provider badge.
- Unit: Features2to6Tests (deep link, invite share URL, approvals).

### 2026-09-08 — Live barcode camera + UPC lookup (REQ-004)
- Backend `GET /v1/barcode/{code}` via Open Food Facts (found=false → manual fallback).
- iOS VisionKit `BarcodeCameraView` + typed UPC lookup; confirm before save.
- Simulator keeps Simulate / Look up code paths. **Redeploy Cloud Run** for barcode route.

### 2026-09-08 — Shopping list API + iOS sync (REQ-011–014)
- Backend: `/v1/households/{id}/shopping-list` CRUD, approve/reject, `sync-from-inventory`.
- Firestore path `households/{id}/shopping_list_items/{item_id}`.
- iOS List tab refreshes/syncs when signed in; custom add / check / approve / deny persist.
- Unit: `test_shopping_list_api.py` (12 backend tests total green).
- **Redeploy** Cloud Run for prod shopping list routes.

### 2026-09-08 — iOS inventory API sync
- `MekasaAPIClient` inventory list/create/consume (+ patch/delete helpers).
- `AppSession` optimistic local add/consume; persists to Cloud Run when signed in with household.
- `MainShellView` refreshes inventory on appear; Add Items copy reflects sync.
- Unit: inventory DTO decode + `canSyncInventory` guard.

### 2026-09-08 — iOS Shopping list (REQ-011–014 client)
- List tab shows `ShoppingListView` matching `ShoppingList.jsx`.
- Check off items, approve/deny pending requests, add custom items.
- Empty inventory seeds demo rows; low-stock inventory auto-adds (REQ-011).
- Unit: `ShoppingListSessionTests`.

### 2026-09-07 — iOS Add items (REQ-004–008 client)
- FAB opens `AddItemsView` hub matching `AddItems.jsx`.
- **Type it in** saves to `AppSession.inventory` (local); merges same name/category.
- Barcode / receipt / voice: demo → confirm before save; unknown barcode → manual fallback.
- Trash station decrements local qty; Dashboard low-stock + activity reflect live inventory.
- Camera/mic usage strings in `Info.plist`. Unit: `InventorySessionTests`.

### 2026-09-07 — iOS Dashboard (UI-004)
- Replaced home stub with `DashboardView` + `MainShellView` (bottom nav + Add FAB).
- Low stock / spend cards, Needs Approval (local approve/deny), Recent Activity fixtures.
- List / Spend / Add are placeholders; Family tab includes Sign out.
- Design: `design/mockups/Dashboard.jsx`.

### 2026-09-07 — iOS onboarding scaffold
- Branched from merged `main` (Firestore PR #3).
- SwiftUI flow: Welcome (Google + email) → Household → Address (CoreLocation) → Stores → Scan stub → Invite stub → Home stub.
- API client points at live Cloud Run. XcodeGen wires Firebase + GoogleSignIn SPM.
- DEBUG **Browse UI offline** walks the flow with local fixtures (no Firebase).
- Needs Firebase iOS app + `GoogleService-Info.plist` on Mac for live auth (see `ios/README.md`).
- PR: https://github.com/fernandogator/mekasa/pull/4

### 2026-09-07 — Firestore household repository wired (code)
- Added `FirestoreHouseholdRepository` targeting named DB `mekasa-db`.
- `HOUSEHOLD_PERSISTENCE=memory|firestore|auto` (prod deploy → firestore).
- Deploy script also binds Cloud Run to `mekasa-api@…` service account.
- Unit tests: 7 passed. **User must redeploy** for prod to use Firestore.

### 2026-09-07 — Cloud Run smoke + progress save
- Deployed thin API: `https://mekasa-api-934775015882.us-central1.run.app`
- GCP console setup complete: APIs, Firebase Auth (Google+email), Firestore `mekasa-db`/`nam5`, SA `mekasa-api` + local JSON key.
- Smoke path passed with temporary `ALLOW_TEST_AUTH=true`; then set back to `false` (401 on stub token confirmed).
- Product decisions locked earlier: P0 mockups approved → iOS first → full onboarding → thin backend first → Firebase Auth + Cloud Run → ADR-002a Firestore.

### 2026-09-06 — ADR-002a accepted
- Recorded **ADR-002a: Firestore over Cloud SQL** in `docs/architecture.md`
  (real-time sync + offline; spending via `spending_summaries` Cloud Function).

### 2026-09-06 — GCP project wired
- User project: `hackathon2025-472017`, region `us-central1`, auth **Google + email first** (Apple later).
- Added `backend/.env.example`, `backend/scripts/deploy-cloud-run.sh`, updated setup doc.
- Agent host has no `gcloud`; user runs deploy from Mac and returns Service URL.

### 2026-09-06 — Thin onboarding API scaffold
- Decisions: approve P0 mockups → iOS next → full onboarding UI → full auth providers → **thin backend first** with **Firebase Auth + Cloud Run**.
- Scaffolded `backend/` FastAPI app: `/health`, `/v1/me`, household create/current, address, nearby stores (stub), store selection.
- Local stub auth via `ALLOW_TEST_AUTH=true` + `Bearer test:<uid>`.
- Unit tests: `tests/backend/test_onboarding_api.py` (4 passing).
- Console checklist: `docs/gcp-firebase-setup.md`.

### 2026-08-21 — Steps 11–12 document seeding
- Seeded `docs/PRD.md`, `docs/spec-v1.0.md`, and `docs/architecture.md` from authoritative v1.0 sources (exact copy).
- Rebuilt `traceability/matrix.md` and `matrix.csv` to match authoritative REQ/UI/NFR titles, Design Artifact paths, and Test File paths.
- Still no application code. Next: Superdesign session for real `design/mockups/` once Node/Superdesign available; then Phase 1 backend.

### 2026-08-20 — AI-SDLC scaffold session
- Scaffolded Steps 1–10 under `mekasa/` (no application code).
- Created progress tracker, guardrails, CI stub, design artifacts, UI test stubs, seeded UI requirements and traceability matrix.
- Pending user delivery of full PRD, spec-v1.0, and architecture texts (Steps 11–12).
