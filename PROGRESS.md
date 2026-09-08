# Project MEKASA

- **Current Phase:** 3 — Live barcode + UPC lookup
- **Last Updated:** 2026-09-08

> **WARNING:** This file must be reconciled against the actual codebase at the
> start of every session. Never trust this file without verification.

---

## Phase 1: Backend API Foundation

| Module | Status | Test Coverage | Last Error | Next Step |
|--------|--------|---------------|------------|-----------|
| auth | deployed (Firebase verify) | unit + Cloud Run smoke | — | Real Google/email ID tokens from iOS; keep `ALLOW_TEST_AUTH=false` in prod |
| household | deployed (Firestore) | unit + smoke | — | Confirm live Cloud Run revision uses `HOUSEHOLD_PERSISTENCE=firestore` |
| inventory | deployed (CRUD + consume) | unit | — | Barcode/OCR lookup endpoints later |
| shopping-list | scaffolded (CRUD + sync API) | unit (test_shopping_list_api) | — | Redeploy Cloud Run; iOS wired in same PR |
| spending | not started | unknown | — | Scaffold category tracking per REQ-015–REQ-018 |
| sync | not started | unknown | — | Scaffold realtime sync per REQ-020 |
| ocr | not started | unknown | — | Wire Vision API receipt scan per REQ-005 |
| barcode | deployed (Open Food Facts lookup) | unit (test_barcode_lookup) | — | Redeploy Cloud Run; live camera on device |
| places | not started | unknown | — | Replace store stub with Places API (REQ-003) |
| notifications | not started | unknown | — | Scaffold push notifications per PRD §8 |

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
| onboarding | not started | unknown | — | After iOS path, or parallel later |
| dashboard | not started | unknown | — | Confirm UI-004 + Dashboard.jsx; expand DashboardUITest |
| inventory-screen | not started | unknown | — | Await mockup + UI req coverage beyond AddItems |
| scanner | not started | unknown | — | Confirm AddItems.jsx; expand ScannerUITest |
| shopping-list-screen | not started | unknown | — | Confirm ShoppingList.jsx; add ShoppingList UI test stubs |
| spending-screen | not started | unknown | — | Confirm SpendingReport.jsx |
| settings | not started | unknown | — | Confirm FamilyMembers.jsx |
| trash-station-mode | not started | unknown | — | Align TrashStation* test filename with UI-005 |

## Phase 3: iOS App

| Module | Status | Test Coverage | Last Error | Next Step |
|--------|--------|---------------|------------|-----------|
| onboarding | ready (live auth verified) | stubs | — | Keep Firebase plist local; Google Sign-In OAuth client still optional |
| dashboard | ready (SwiftUI UI-004) | stubs | — | Wire spend APIs when backend endpoints exist |
| inventory-screen | in progress (Add hub + API sync) | unit (InventorySessionTests) | — | Inventory list UI; live camera/OCR |
| scanner | in progress (live camera + UPC API) | stubs | — | Expand ScannerUITest on device |
| shopping-list-screen | in progress (SwiftUI + API sync) | unit (ShoppingListSessionTests) | — | Expand ShoppingListUITest; member roles |
| spending-screen | not started | unknown | — | Confirm SpendingReport.jsx |
| settings | not started | unknown | — | Family tab placeholder exists; expand FamilyMembers |
| trash-station-mode | in progress (local consume) | stubs | — | Dedicated device mode + live barcode; UI-005 polish |

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
