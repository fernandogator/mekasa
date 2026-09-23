# Mekasa Android

Jetpack Compose client for the Mekasa household inventory API.

## Requirements

- JDK 17+
- Android SDK 35 (`platforms;android-35`)
- Optional: physical device or emulator (API 26+)

## Configure

```bash
# From android/
echo "sdk.dir=$HOME/android-sdk" > local.properties
```

`local.properties` is gitignored. Default API base URL is the Cloud Run service:

`https://mekasa-api-934775015882.us-central1.run.app`

Override via `BuildConfig.API_BASE_URL` in `app/build.gradle.kts` if needed.

## Build

```bash
./gradlew :app:assembleDebug
./gradlew :app:testDebugUnitTest
```

Debug APK: `app/build/outputs/apk/debug/app-debug.apk`

## Run

1. Install the debug APK on a device/emulator.
2. On Welcome, use **Browse UI offline** for sample dashboard data, or **Continue with email** to hit Cloud Run with a `test:<uid>` bearer (only when the backend has `ALLOW_TEST_AUTH=true`).
3. Firebase Auth (Google / email / Apple) is not wired in this foundation build — that follows once `google-services.json` is added.

## Package layout

| Path | Role |
|------|------|
| `ui/onboarding/` | Welcome → household → address → stores |
| `ui/shell/` | Bottom nav + Add FAB |
| `ui/dashboard/` | Home summary |
| `ui/shopping/`, `ui/spending/`, `ui/family/` | Tab screens |
| `data/` | Ktor API client + DTOs |
| `session/AppSession` | Onboarding + dashboard state |

Design tokens mirror `design/design-system.md` / iOS `MekasaTheme`.
