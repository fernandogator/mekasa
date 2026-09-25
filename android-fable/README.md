# Mekasa Android — Fable build

> Implemented by Claude Fable 5.1 for comparison with the auto-model build in `android/`.

An independent, from-scratch Android client for the Mekasa household-inventory
API. It targets the same Cloud Run backend and the same feature list as
`android/`, but shares no Kotlin with it (only the launcher icons and the Gradle
wrapper were copied). Package name: `com.fernandogator.mekasa.fable`
(debug builds add `.debug`).

## Requirements

- JDK 21 (Gradle runs on 21; the app compiles to JVM 17)
- Android SDK with platform 35 and build-tools; point `sdk.dir` at it in a
  gitignored `local.properties`:

  ```properties
  sdk.dir=/home/ubuntu/android-sdk
  ```

## Build & test

```bash
cd android-fable
./gradlew :app:assembleDebug :app:testDebugUnitTest
```

- APK: `app/build/outputs/apk/debug/app-debug.apk`
- Unit test reports: `app/build/reports/tests/testDebugUnitTest/index.html`

Unit tests are plain JVM tests (`app/src/test`) and cover the voice phrase
parser, invite-link parsing, the in-memory demo backend, the Ktor API layer
(via `MockEngine`), onboarding routing, and the session ViewModel (sign-in,
offline preview, onboarding stages, REQ-014 purchase gate, REQ-002 owner-only
photo, REQ-022 session expiry, barcode consume, inventory remove/undo/purge,
invites).

## Testing layers

Everything below runs on a plain Linux JVM — no emulator — and is what the
`android-fable` job in `.github/workflows/ci.yml` executes:

```bash
cd android-fable
./gradlew :app:testDebugUnitTest :app:verifyRoborazziDebug
```

| Layer | What it checks | Where | Command |
|-------|----------------|-------|---------|
| 0 — Unit | Parsers, demo backend rules, Ktor API mapping, `SessionViewModel` state machine | `app/src/test/.../{voice,invite,data,session}` | `./gradlew :app:testDebugUnitTest` |
| 1 — Structural | Compose semantics under Robolectric (`@GraphicsMode(NATIVE)`, SDK 34): key composables present, taps/inputs fire the ViewModel, navigation lands on the next screen, reading order matches the baseline. One file per screen, four tests each (`layout_`, `interaction_`, `flow_`, `visual_`). Includes REQ-INV-014..017 swipe Use 1 / Remove / Undo via `performTouchInput`. | `app/src/test/java/app/mekasa/fable/ui/*UITest.kt` (9 files, 36 tests) | `./gradlew :app:testDebugUnitTest --tests '*UITest*'` |
| 2 — Snapshot | Roborazzi PNG of every Layer-1 screen state (16) on a fixed Pixel-7-class qualifier with demo fixtures; compared at a 15% change threshold (semantic, not pixel-exact — see `design/baselines/README.md`). Diffs are written to `app/build/outputs/roborazzi/`. | `app/src/test/java/app/mekasa/fable/ui/ScreenSnapshotTest.kt` → `design/baselines/android/<Screen>_baseline.png` | `./gradlew :app:verifyRoborazziDebug` (compare) / `./gradlew :app:recordRoborazziDebug` (re-record after an approved design change) |
| 3 — Vision | Manual pre-release gate: a vision model compares a real device/emulator capture with the recorded baseline for layout, hierarchy and palette. Cases live in `Scripts/ui_vision_cases.json` (`"platform": "android"`). | `Scripts/verify_ui_vision.py` | `python3 Scripts/verify_ui_vision.py --list-cases --platform android` then `ANTHROPIC_API_KEY=… python3 Scripts/verify_ui_vision.py --platform android --screen UI-004 --spec design/baselines/android/Dashboard_baseline.png --actual <capture.png>` |

Layers 1 and 2 drive the real composables through the production
`SessionViewModel` + `MekasaRoot` path: "Browse UI offline" installs the same
`DemoBackend` the app ships, onboarding runs against a scripted `MekasaApi`
(`OnboardingApi`), and the REQ-014 member view uses `MemberApi`. Test tags
come from `ui/TestTags.kt`, which mirrors
`ios/Tests/TestSupport/TestIdentifiers.swift`. Shared fixtures are in
`app/src/test/java/app/mekasa/fable/support/UiHarness.kt`.

What Robolectric cannot do, and how it is covered instead:

- **Camera.** CameraX/ML Kit never start on the JVM, so the scanner renders its
  permission fallback (`Allow camera`). Tests assert that fallback and drive
  barcode lookups / trash-station consumption through the manual UPC field,
  which shares the same `lookup()` / `consume()` code path.
- **Coil images.** `coil-test`'s `FakeImageLoaderEngine` resolves every URL to
  a flat swatch so thumbnails are deterministic and offline.
- **Undo timer.** `SessionViewModel(undoWindowMillis = …)` is injectable; UI
  tests hold the window open, `SessionViewModelTest` advances virtual time to
  cover the purge.

## Firebase configuration

`app/google-services.json` in git is a **CI stub** (`project_id =
mekasa-ci-stub`) that declares clients for both package names so the
`google-services` Gradle plugin is satisfied. `FirebaseGate` recognises the
stub project id and skips `FirebaseApp` initialisation, so the app still
builds and runs: the Welcome screen offers **Browse UI offline** (in-memory
demo household) and, in debug builds, **test-token sign-in** (`test:<uid>`
bearers, accepted by Cloud Run only when `ALLOW_TEST_AUTH=true`).

To enable real email/password and Google sign-in:

1. In the Firebase console add Android apps for
   `com.fernandogator.mekasa.fable` and `com.fernandogator.mekasa.fable.debug`
   (add the debug SHA-1 for Google).
2. Download `google-services.json`, keep it as `app/google-services.real.json`
   (gitignored), and copy it over `app/google-services.json` locally. Do not
   commit the real file.
3. Ensure a Web OAuth client (`client_type: 3`) exists so the plugin generates
   `R.string.default_web_client_id`; Google Sign-In is hidden otherwise.
4. Enable the Email/Password and Google providers under Authentication.

See `app/google-services.json.example` for the same steps inline.

## What is implemented

| Area | Notes |
|------|-------|
| Onboarding | Welcome (email/password, Google, offline preview, debug test token) → household name → address → store picker. Stage is derived from the household record, so a returning user resumes where they stopped. |
| Shell | Bottom pill nav (Home / List / Spend / Family) with a raised red FAB; secondary routes (inventory, item detail, home photo, trash station) via `navigation-compose`. |
| Dashboard | Hero photo with gradient scrim, low-stock/spend stat cards, pending approvals, low-stock list, shopping summary, recently added. |
| Home photo | Gallery (Photo Picker with `GetContent` fallback) or camera; downscaled and JPEG-encoded on device, multipart `file` upload; owner-only with a client-side check (REQ-002). |
| Add items | Bottom-sheet hub: barcode camera (CameraX + ML Kit) → `/v1/barcode/{code}` → confirm; product search; voice (system speech recogniser or typed phrase → `VoicePhraseParser` → search); receipt (photo → base64, pasted text, or demo haul) → select lines → bulk add with `source=receipt` and `price_paid`. |
| Inventory | Grouped by category, search, Coil thumbnails (https or data URLs), trailing swipe: Use 1 when qty > 1 (REQ-INV-014) or Remove when qty ≤ 1 with soft delete, "Item removed · Undo" toast and purge after 5 s (REQ-INV-015..018); item detail with quantity/threshold steppers (PATCH), lightbox, refresh image. |
| Shopping list | Add/remove, approve/reject requests, sync from inventory, mark purchased gated to owners or members with the `buyer` permission (REQ-014); non-owners see a lock notice. |
| Spending | Week/month/year toggle re-fetches `/spending?period=`; animated category bars. |
| Family | Members with "Make owner", invite form with role toggle, share sheet for `mekasa://invite?token=…`, deep-link acceptance (held until signed in), kiosk trash station. |
| Trash station | Continuous barcode scanning plus manual UPC; consume-by-barcode with Used/Depleted/Unknown feedback, unknown scans logged (REQ-008); full-screen kiosk mode. |
| Session expiry | Any 401 triggers one forced ID-token refresh and retry; a second failure or Firebase dropping the user signs out to Welcome with a notice and the remembered email (REQ-022). |
| Theme | Design-system tokens (sage/charcoal/red, 40/24/16 radii, 64 dp pill nav, 56 dp FAB) plus a dark palette. |

## How this differs from `android/`

Both apps hit the same routes and DTOs, but the internals are deliberately
different so the two can be compared honestly:

- **Transport abstraction.** A `HouseholdBackend` interface has two
  implementations — `RemoteBackend` (Ktor + OkHttp against Cloud Run) and
  `DemoBackend` (in-memory, seeded). The offline preview and the unit tests use
  the same ViewModel code path as production instead of a separate mock layer.
- **One guarded pipeline.** Every mutation runs through
  `SessionViewModel.guarded {}`, which owns busy state, error mapping,
  403 swallowing where appropriate, and the 401 → refresh → retry → sign-out
  rule. Screens never catch exceptions themselves.
- **Auth behind an interface.** `AuthGateway` wraps Firebase Auth and Google
  Sign-In; `FakeAuthGateway` drives the ViewModel tests, including the
  "Firebase signed us out" flow.
- **Navigation.** In-shell routing uses `navigation-compose` with saved tab
  state; `android/` keeps its own enum-driven navigation.
- **Networking.** Ktor client with kotlinx.serialization (`explicitNulls =
  false`, so PATCH bodies omit untouched fields) and an injectable engine for
  `MockEngine` tests.
- **Build.** Gradle version catalog (`gradle/libs.versions.toml`), Kotlin
  2.0.21 with the Compose compiler plugin, `firebase-auth` (not `-ktx`).
- **Demo data and receipts.** The demo backend enforces the same rules the
  server does (non-negative quantities, unknown-scan logging, low-stock sync),
  and the receipt flow lets you deselect lines before bulk-adding.

## Known gaps

- No GPS auto-detection on the address step (address is typed; stores come
  from `/stores/nearby` after the server geocodes it).
- The Nunito typeface from the design system is not bundled; the theme uses the
  platform sans-serif with the design system's sizes and weights.
- No instrumented (device) tests; Compose UI coverage is Robolectric +
  Roborazzi on the JVM (see "Testing layers").
- Voice input uses the system `RecognizerIntent`; devices without a speech
  recogniser fall back to the typed phrase field.
