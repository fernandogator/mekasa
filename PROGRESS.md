# Project MEKASA

- **Current Phase:** 1 — Backend API Foundation (thin onboarding slice)
- **Last Updated:** 2026-09-07

> **WARNING:** This file must be reconciled against the actual codebase at the
> start of every session. Never trust this file without verification.

---

## Phase 1: Backend API Foundation

| Module | Status | Test Coverage | Last Error | Next Step |
|--------|--------|---------------|------------|-----------|
| auth | deployed (Firebase verify) | unit + Cloud Run smoke | — | Real Google/email ID tokens from iOS; keep `ALLOW_TEST_AUTH=false` in prod |
| household | deployed (in-memory) | unit + Cloud Run smoke | — | **Wire Firestore `mekasa-db`**; then invites (REQ-019) |
| inventory | not started | unknown | — | Scaffold inventory CRUD per REQ-004–REQ-008 |
| shopping-list | not started | unknown | — | Scaffold list generation per REQ-011–REQ-014 |
| spending | not started | unknown | — | Scaffold category tracking per REQ-015–REQ-018 |
| sync | not started | unknown | — | Scaffold realtime sync per REQ-020 |
| ocr | not started | unknown | — | Wire Vision API receipt scan per REQ-005 |
| barcode | not started | unknown | — | Integrate UPC lookup per REQ-004 |
| places | not started | unknown | — | Replace store stub with Places API (REQ-003) |
| notifications | not started | unknown | — | Scaffold push notifications per PRD §8 |

### Live thin API (2026-09-07)

| Item | Value |
|------|--------|
| Cloud Run URL | `https://mekasa-api-934775015882.us-central1.run.app` |
| Project | `hackathon2025-472017` |
| Region | `us-central1` |
| Firestore DB | `mekasa-db` @ `nam5` (Standard, Restrictive) — **not wired in API yet** |
| Service account | `mekasa-api@hackathon2025-472017.iam.gserviceaccount.com` |
| Auth (prod) | Firebase ID token; `ALLOW_TEST_AUTH=false` |
| Auth (smoke) | Temporarily enabled stub; smoke passed; stub disabled again |
| Persistence | **In-memory only** (lost on new revision/restart) |

**Smoke verified:** `/health`, `/v1/me` (stub then real reject), POST household, PUT address, GET nearby stores (stub), PUT store selection, GET current.

---

## Phase 2: Android App

| Module | Status | Test Coverage | Last Error | Next Step |
|--------|--------|---------------|------------|-----------|
| onboarding | not started | unknown | — | After Firestore + iOS path, or parallel later |
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
| onboarding | not started | unknown | — | After Firestore persistence; full flow + Google/email auth |
| dashboard | not started | unknown | — | Confirm UI-004 + Dashboard.jsx; expand DashboardUITest |
| inventory-screen | not started | unknown | — | Await mockup + UI req coverage beyond AddItems |
| scanner | not started | unknown | — | Confirm AddItems.jsx; expand ScannerUITest |
| shopping-list-screen | not started | unknown | — | Confirm ShoppingList.jsx; add ShoppingList UI test stubs |
| spending-screen | not started | unknown | — | Confirm SpendingReport.jsx |
| settings | not started | unknown | — | Confirm FamilyMembers.jsx |
| trash-station-mode | not started | unknown | — | Align TrashStation* test filename with UI-005 |

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

### 2026-09-07 — Cloud Run smoke + progress save
- Deployed thin API: `https://mekasa-api-934775015882.us-central1.run.app`
- GCP console setup complete: APIs, Firebase Auth (Google+email), Firestore `mekasa-db`/`nam5`, SA `mekasa-api` + local JSON key.
- Smoke path passed with temporary `ALLOW_TEST_AUTH=true`; then set back to `false` (401 on stub token confirmed).
- Household CRUD still **in-memory** on the service.
- **Next:** Wire Firestore repository for durable households; then iOS onboarding against live API.
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
- **Reconcile mismatches flagged (no code changes):**
  - Spec references mockups not yet in repo: `OnboardingHouseholdSetup.jsx`, `SpendingReport.jsx`, `FamilyMembers.jsx`.
  - UI-005 Test File paths say `TrashStationUITest.kt` / `TrashStationUITest.swift`; scaffold has `TrashStationModeUITest.kt` / `TrashStationModeUITest.swift`.
  - Scaffold UI test stubs also exist for ShoppingList, Spending, Settings, Inventory, Scanner beyond the five UI-XXX entries — keep until Superdesign + UI req coverage expands.
- Still no application code. Next: Superdesign session for real `design/mockups/` once Node/Superdesign available; then Phase 1 backend.

### 2026-08-20 — AI-SDLC scaffold session
- Scaffolded Steps 1–10 under `mekasa/` (no application code).
- Created progress tracker, guardrails, CI stub, design artifacts, UI test stubs, seeded UI requirements and traceability matrix.
- Pending user delivery of full PRD, spec-v1.0, and architecture texts (Steps 11–12).
