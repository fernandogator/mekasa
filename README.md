# MEKASA

Household inventory management ("mi casa"). Native Android (Jetpack Compose) +
iOS (SwiftUI) clients backed by a GCP Cloud Run REST API.

This repository holds the AI-SDLC scaffold. Application code has not been written yet.

## Quick links

| Doc | Purpose |
|-----|---------|
| `PROGRESS.md` | Phase tracker — reconcile every session |
| `GUARDRAILS.md` | Non-negotiable project rules |
| `docs/spec-v1.0.md` | Requirements (UI seeded; full PRD pending) |
| `design/` | User flows, design system, Superdesign mockups |
| `traceability/` | Requirement ↔ test matrix |

## Superdesign (UI mockups)

Skill is installed under `.agents/skills/superdesign`. Init context is in `.superdesign/init/`.

```bash
npx --yes @superdesign/cli@latest
npx --yes @superdesign/cli@latest login
```

In Cursor: Settings → Rules and Commands → add command `superdesign` from the skill's `SKILL.md`, then `/superdesign`.

Approved React/Tailwind mockups land in `design/mockups/` and link to `UI-XXX` in the spec.

## Layout

```
android/     # Jetpack Compose app (+ UI test stubs)
ios/         # SwiftUI app (+ UI test stubs)
backend/     # Cloud Run API (Python)
design/      # Flows, tokens, mockups, baselines
docs/        # PRD, spec, architecture, standards
tests/       # Backend + integration tests
traceability/
```

## Status

Phase 1 (Backend API Foundation) — **thin onboarding API scaffolded** under `backend/`.  
GCP/Firebase project setup checklist: `docs/gcp-firebase-setup.md`. See `PROGRESS.md`.
