# Mekasa Code Standards

Spec version referenced by these standards: **1.0**

## Requirement Traceability

Every function includes:

```
# Satisfies: REQ-XXX (requirement title)
# Acceptance criteria: AC1, AC2, AC3
# Spec version: 1.0
```

## Backend (Python)

- Type hints required on all function signatures.
- Docstrings required on all public functions and classes.
- All external API calls: 10-second timeout, 3-retry exponential backoff.
- No hardcoded credentials or secrets anywhere, ever.
- All secrets via GCP Secret Manager only.
- No PII in any log output.

## UI Components

- Named to match spec `UI-XXX` requirement where applicable.
- Every UI requirement links to a design artifact under `design/mockups/`.
- No UI screen ships without a passing layout test and a visual verification pass.

## Tests

- Test files: one test file per UI screen, named to match the screen module.
- Android: `android/src/test/ui/[ScreenName]UITest.kt`
- iOS: `ios/MekasaTests/UI/[ScreenName]UITest.swift`
- Visual verification is semantic/structural, not pixel-exact.
  Content differences from test data are expected and acceptable.

## Versioning

- Spec, code, and tests must always match the same version.
- No application code without a versioned spec entry first.
- Requirement IDs are permanent — mark deprecated, never delete or renumber.
