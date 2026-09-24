# Mekasa iOS

SwiftUI client for Mekasa v1.0.

**Shipped so far**
- Onboarding: Welcome (Google + **Apple** + email) → Household → Address → Stores → scan/invite stubs
- Home: **Dashboard** (UI-004) with **home photo hero**, bottom nav + Add FAB
- Tap hero → **Home photo** screen (camera or Photos library)
- **Add items** hub (FAB): Type it in / confirm sync to Cloud Run; **Scan barcode** uses live camera + Open Food Facts UPC lookup
- **Shopping list** (List tab): check off, approve/deny, add custom — syncs to Cloud Run when signed in; low-stock auto-adds via API
- **Spending** (Spend tab): week/month/year report from purchase events; Dashboard card shows weekly total

Talks to Cloud Run for auth/household/**inventory**/**shopping list**/**spending**/**barcode lookup**.

## Live API

`https://mekasa-api-934775015882.us-central1.run.app`

## Bundle ID

`com.fernandogator.mekasa`

## Versioning

Every app build gets a **unique build number**. Marketing version starts at **1.0.0**.

| Field | Source | Notes |
|-------|--------|--------|
| `CFBundleShortVersionString` | `Config/MarketingVersion.xcconfig` | User-facing, starts `1.0.0` |
| `CFBundleVersion` | auto via `scripts/ensure_unique_build_number.sh` | Unique per build (CI uses `GITHUB_RUN_NUMBER`) |

Xcode runs the stamp script automatically as a pre-build phase. Override with `MEKASA_BUILD_NUMBER=42 ./scripts/ensure_unique_build_number.sh`.

Bump marketing for a release:

```bash
cd ios
./scripts/bump_marketing_version.sh patch   # 1.0.0 → 1.0.1
./scripts/bump_marketing_version.sh minor   # 1.0.1 → 1.1.0
./scripts/bump_marketing_version.sh major   # 1.1.0 → 2.0.0
```

### Google Sign-In URL scheme crash

If Xcode stops in `GIDSignIn.m` with:

`Your app is missing support for the following URL schemes: com.googleusercontent.apps.…`

the reversed client ID is not registered. Fix:

```bash
cd ios
./scripts/sync_google_signin_config.sh   # writes literal scheme into Info.plist
xcodegen generate
```

Or in Xcode: target **Mekasa** → **Info** → **URL Types** → add:

| URL Types | Value |
|-----------|--------|
| Identifier | `GoogleSignIn` |
| URL Schemes | value of `REVERSED_CLIENT_ID` from your plist (starts with `com.googleusercontent.apps.`) |

```bash
/usr/libexec/PlistBuddy -c 'Print :REVERSED_CLIENT_ID' Mekasa/GoogleService-Info.plist
```

Clean + Run again.

### Google Sign-In (Continue with Google)

The app already has Google Sign-In wired. You need a real plist **with** `CLIENT_ID` + `REVERSED_CLIENT_ID`:

1. [Firebase Console](https://console.firebase.google.com/project/hackathon2025-472017/authentication/providers) → **Sign-in method** → enable **Google** → Save  
2. Project settings → iOS app `com.fernandogator.mekasa` → download **`GoogleService-Info.plist`**  
3. Save it at `ios/Mekasa/GoogleService-Info.plist` (gitignored)  
4. Confirm the file contains:

```xml
<key>CLIENT_ID</key>
<string>….apps.googleusercontent.com</string>
<key>REVERSED_CLIENT_ID</key>
<string>com.googleusercontent.apps.…</string>
```

If those keys are missing: [Google Cloud Credentials](https://console.cloud.google.com/apis/credentials?project=hackathon2025-472017) → create **OAuth client ID → iOS** for bundle `com.fernandogator.mekasa` → re-download the Firebase plist (or add the keys manually).

5. Sync URL scheme + regenerate Xcode project:

```bash
cd ios
chmod +x scripts/sync_google_signin_config.sh
./scripts/sync_google_signin_config.sh
xcodegen generate
open Mekasa.xcodeproj
```

6. Clean + Run. Tap **Continue with Google**.

The build runs `sync_google_signin_config.sh` automatically so `Info.plist` gets `$(GOOGLE_REVERSED_CLIENT_ID)` from your local plist.

Email/password works without the URL scheme; **Google Sign-In needs it**.

### Fix Firebase “default app has not yet been configured”

That log means **`GoogleService-Info.plist` is not inside the built `.app`**.

```bash
# 1. File must exist here (gitignored — do not commit):
ls -la ios/Mekasa/GoogleService-Info.plist

# 2. Regenerate Xcode project so the plist is a resource:
cd ios
xcodegen generate
open Mekasa.xcodeproj
```

In Xcode:

1. Select **`GoogleService-Info.plist`**
2. File inspector → **Target Membership** → ✅ **Mekasa**
3. Target **Mekasa** → **Build Phases** → **Copy Bundle Resources** → plist listed (use **+** if not)
4. **Product → Clean Build Folder** → **▶ Run**
5. Console should show: `[Mekasa] Firebase configured OK`

If you see `[Mekasa] GoogleService-Info.plist in bundle: false`, the plist is still not in Copy Bundle Resources.

## One-time: Firebase iOS app

1. [Firebase Console](https://console.firebase.google.com/project/hackathon2025-472017/settings/general/) → **Add app** → iOS  
2. Bundle ID: `com.fernandogator.mekasa`  
3. Download **`GoogleService-Info.plist`** → `ios/Mekasa/GoogleService-Info.plist`  
4. Auth: **Google** + **Email/Password** + **Apple** enabled (see `docs/gcp-firebase-setup.md` §2b)  

### Google Sign-In URL scheme

If `CLIENT_ID` / `REVERSED_CLIENT_ID` are missing from the plist, create an **iOS OAuth client** in Google Cloud Credentials for this bundle ID, then either re-download the plist or derive:

`CLIENT_ID` = `123-abc.apps.googleusercontent.com`  
→ URL scheme = `com.googleusercontent.apps.123-abc`

Put that value in `Info.plist` → URL Types → URL Schemes (replace `REPLACE_WITH_REVERSED_CLIENT_ID`).

Email/password works without the URL scheme; Google Sign-In needs it.

## Open in Xcode

```bash
brew install xcodegen   # once
cd ios
xcodegen generate
open Mekasa.xcodeproj
```

After pulling Swift file adds/removes, always re-run `xcodegen generate` (the `.xcodeproj` is generated, not committed). Then **Product → Clean Build Folder**.

## Tests

Preferred local simulator (see `Config/PreferredSimulator.env`): **iPhone 17 Pro**.

```bash
cd ios && xcodegen generate
# Convenience wrapper (reads PreferredSimulator.env):
./scripts/run_unit_tests.sh

# Or explicitly:
xcodebuild test -scheme Mekasa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -testPlan UnitTests
```

UI layers (structural / snapshots / vision): see `ios/Tests/README.md`. Launch args: `--uitesting` (fixtures, no network), optional `--uitesting-empty`.

SPM (via `project.yml`): FirebaseCore, FirebaseAuth, FirebaseFirestore, FirebaseMessaging, GoogleSignIn, SnapshotTesting.

After pulling (especially when `project.yml` gains packages or new Swift files), always:

```bash
cd ios && xcodegen generate
```

Then **Product → Clean Build Folder** and resolve SPM packages if prompted.

Signing → your Team → Run on **iPhone 17 Pro** simulator (not “Any iOS Device”).

### DEBUG: offline UI walkthrough

**Browse UI offline** walks onboarding with local fixtures (no Firebase/network).

## Spec mapping

- UI-003 Onboarding · REQ-001 Auth · REQ-002 Household · REQ-003 Address/Stores  
- UI-004 Dashboard + Add items hub · REQ-004–REQ-008 (inventory sync to API when signed in)  
- Shopping list · REQ-011–REQ-014 (client staging; low-stock auto-add)  
- Voice add · REQ-007 (speech or sample phrase → catalog match → confirm)  
- Realtime sync · REQ-020 (Firestore listeners when signed in; REST mutations)  
- Push · PRD §8 (device register + invite FCM hooks; APNs key required in prod)  
- Design: `design/mockups/OnboardingHouseholdSetup.jsx`, `OnboardingStoreSelection.jsx`, `Dashboard.jsx`, `AddItems.jsx`, `ShoppingList.jsx`
