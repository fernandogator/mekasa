# MEKASA

Household inventory management ("mi casa"). Native Android (Jetpack Compose) +
iOS (SwiftUI) clients backed by a GCP Cloud Run REST API.

## Quick links

| Doc | Purpose |
|-----|---------|
| `PROGRESS.md` | Phase tracker — reconcile every session |
| `GUARDRAILS.md` | Non-negotiable project rules |
| `docs/spec-v1.0.md` | Requirements |
| `ios/README.md` | iOS XcodeGen + Firebase setup |
| `backend/README.md` | Thin onboarding API |
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
ios/         # SwiftUI onboarding client (+ UI test stubs)
backend/     # Cloud Run API (Python / FastAPI)
design/      # Flows, tokens, mockups, baselines
docs/        # PRD, spec, architecture, standards
tests/       # Backend + integration tests
traceability/
```

## Status

- **Backend:** thin onboarding API on Cloud Run + Firestore household persistence (see `PROGRESS.md`).
- **iOS:** onboarding flow scaffolded (Google + email auth, household, address, stores). Open `ios/README.md` to generate the Xcode project and add Firebase.
- **Android:** UI test stubs only so far.
