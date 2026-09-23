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

### Firebase Auth

The repo ships a **CI stub** `app/google-services.json` (`project_id`: `mekasa-ci-stub`).
`FirebaseBootstrap` skips `FirebaseApp` init for that stub so builds never crash.

For real email / Google sign-in:

1. Firebase Console → add Android apps for `com.fernandogator.mekasa` and `com.fernandogator.mekasa.debug`
2. Download `google-services.json` and replace `android/app/google-services.json`
3. Ensure an OAuth **Web client** exists (needed for Google Sign-In `default_web_client_id`)
4. Enable Email/Password + Google providers

See `app/google-services.json.example`.

API base URL (Cloud Run):

`https://mekasa-api-934775015882.us-central1.run.app`

## Build

```bash
./gradlew :app:assembleDebug
./gradlew :app:testDebugUnitTest
```

Debug APK: `app/build/outputs/apk/debug/app-debug.apk`

## Run

1. Install the debug APK.
2. Welcome:
   - **Browse UI offline** — sample dashboard + local Add
   - **Continue with email** — Firebase when configured; otherwise falls back to Cloud Run `test:` bearer (only if `ALLOW_TEST_AUTH=true`)
   - **Continue with Google** — when Firebase is configured with a Web client ID
3. From MainShell, tap **+** to scan/enter a barcode, search products, and confirm into inventory.

## Package layout

| Path | Role |
|------|------|
| `auth/` | FirebaseBootstrap + AuthService |
| `ui/onboarding/` | Welcome → household → address → stores |
| `ui/additems/` | Barcode (CameraX + ML Kit) / search / confirm |
| `ui/shell/` | Bottom nav + Add FAB |
| `data/` | Ktor API client + DTOs |
| `session/AppSession` | Auth, onboarding, dashboard, inventory add |

Design tokens mirror `design/design-system.md` / iOS `MekasaTheme`.
