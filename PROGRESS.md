# Project MEKASA

- **Current Phase:** 1 — Backend API Foundation (thin onboarding slice)
- **Last Updated:** 2026-09-06

> **WARNING:** This file must be reconciled against the actual codebase at the
> start of every session. Never trust this file without verification.

---

## Phase 1: Backend API Foundation

| Module | Status | Test Coverage | Last Error | Next Step |
|--------|--------|---------------|------------|-----------|
| auth | in progress | unit (local stub) | — | Wire real Firebase project; disable ALLOW_TEST_AUTH in prod |
| household | in progress | unit (in-memory) | — | Swap in-memory repo for Firestore; invite (REQ-019) later |
| inventory | not started | unknown | — | Scaffold inventory CRUD per REQ-004–REQ-008 |
| shopping-list | not started | unknown | — | Scaffold list generation per REQ-011–REQ-014 |
| spending | not started | unknown | — | Scaffold category tracking per REQ-015–REQ-018 |
| sync | not started | unknown | — | Scaffold realtime sync per REQ-020 |
| ocr | not started | unknown | — | Wire Vision API receipt scan per REQ-005 |
| barcode | not started | unknown | — | Integrate UPC lookup per REQ-004 |
| places | not started | unknown | — | Places API within 15 mi per REQ-003 |
| notifications | not started | unknown | — | Scaffold push notifications per PRD §8 |

## Phase 2: Android App

| Module | Status | Test Coverage | Last Error | Next Step |
|--------|--------|---------------|------------|-----------|
| onboarding | not started | unknown | — | Confirm UI-003 + mockups; expand OnboardingUITest stubs |
| dashboard | not started | unknown | — | Confirm UI-004 + Dashboard.jsx; expand DashboardUITest |
| inventory-screen | not started | unknown | — | Await mockup + UI req coverage beyond AddItems |
| scanner | not started | unknown | — | Confirm AddItems.jsx; expand ScannerUITest |
| shopping-list-screen | not started | unknown | — | Confirm ShoppingList.jsx; add ShoppingList UI test stubs |
| spending-screen | not started | unknown | — | Await SpendingReport.jsx from Superdesign |
| settings | not started | unknown | — | Await FamilyMembers.jsx from Superdesign |
| trash-station-mode | not started | unknown | — | Align TrashStation* test filename with UI-005 |

## Phase 3: iOS App

| Module | Status | Test Coverage | Last Error | Next Step |
|--------|--------|---------------|------------|-----------|
| onboarding | not started | unknown | — | Confirm UI-003 + mockups; expand OnboardingUITest stubs |
| dashboard | not started | unknown | — | Confirm UI-004 + Dashboard.jsx; expand DashboardUITest |
| inventory-screen | not started | unknown | — | Await mockup + UI req coverage beyond AddItems |
| scanner | not started | unknown | — | Confirm AddItems.jsx; expand ScannerUITest |
| shopping-list-screen | not started | unknown | — | Confirm ShoppingList.jsx; add ShoppingList UI test stubs |
| spending-screen | not started | unknown | — | Await SpendingReport.jsx from Superdesign |
| settings | not started | unknown | — | Await FamilyMembers.jsx from Superdesign |
| trash-station-mode | not started | unknown | — | Align TrashStation* test filename with UI-005 |

## Phase 4: UI Design and Visual Verification

| Module | Status | Test Coverage | Last Error | Next Step |
|--------|--------|---------------|------------|-----------|
| design-system | not started | unknown | — | Flesh out tokens after Superdesign session |
| superdesign-mockups | blocked | unknown | Missing mockups referenced by spec | Run Superdesign; add OnboardingHouseholdSetup, SpendingReport, FamilyMembers |
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
