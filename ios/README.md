# Mekasa iOS

SwiftUI client for Mekasa v1.0. First slice: **onboarding** (Welcome → Household → Address → Stores → Scan stub → Invite stub → Home stub) talking to Cloud Run.

## Live API

`https://mekasa-api-934775015882.us-central1.run.app`

## Bundle ID (default)

`com.fernandogator.mekasa`

Change in `project.yml` if you use a different id — it must match the Firebase iOS app.

## One-time: Firebase iOS app

1. [Firebase Console](https://console.firebase.google.com/project/hackathon2025-472017/settings/general/) → **Add app** → iOS  
2. Bundle ID: `com.fernandogator.mekasa`  
3. Download **`GoogleService-Info.plist`**  
4. Place it at `ios/Mekasa/GoogleService-Info.plist` (gitignored)  
5. Authentication already has **Google** + **Email/Password** enabled  

Then regenerate so Xcode copies the plist into the app:

```bash
cd ios
xcodegen generate
open Mekasa.xcodeproj
```

In Xcode, select `GoogleService-Info.plist` → File inspector (right panel) → **Target Membership** → check **Mekasa**.  
Build settings → Mekasa → **Build Phases → Copy Bundle Resources** must list `GoogleService-Info.plist`.

### Google Sign-In URL scheme

From `GoogleService-Info.plist`, copy `REVERSED_CLIENT_ID` into `ios/Mekasa/Info.plist` under `CFBundleURLTypes` (replace `REPLACE_WITH_REVERSED_CLIENT_ID`).

## Open in Xcode (Mac)

```bash
brew install xcodegen   # once
cd ios
xcodegen generate
open Mekasa.xcodeproj
```

`project.yml` already wires SPM packages:

- Firebase (`FirebaseCore`, `FirebaseAuth`) from `firebase-ios-sdk` ≥ 11.6.0  
- GoogleSignIn from `GoogleSignIn-iOS` ≥ 8.0.0  

Then in Xcode:

1. Signing & Capabilities → your Team  
2. First resolve packages (File → Packages → Resolve)  
3. Run on simulator or device  

### DEBUG: offline UI walkthrough

On the welcome screen, tap **Browse UI offline** to walk the full onboarding flow with local fixtures (no Firebase, no API). Useful for layout review before Auth is configured.

## Auth modes

| Mode | Behavior |
|------|----------|
| DEBUG + **Browse UI offline** | Local fixtures only; no network |
| With `GoogleService-Info.plist` | Email + Google → Firebase ID token → `Authorization: Bearer <idToken>` |

Prod API has `ALLOW_TEST_AUTH=false` — live onboarding needs a real Firebase token.

## Spec mapping

- UI-003 Onboarding · REQ-001 Auth · REQ-002 Household · REQ-003 Address/Stores  
- Design: `design/mockups/OnboardingHouseholdSetup.jsx`, `OnboardingStoreSelection.jsx`

## Tests

`MekasaTests/APIModelsTests.swift` covers JSON decoding for household + store search payloads.
