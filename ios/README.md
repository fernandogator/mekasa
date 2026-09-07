# Mekasa iOS

SwiftUI client for Mekasa v1.0. First slice: **onboarding** (Welcome → Household → Address → Stores → Scan stub → Invite stub → Dashboard stub) talking to Cloud Run.

## Live API

`https://mekasa-api-934775015882.us-central1.run.app`

## Bundle ID (default)

`com.fernandogator.mekasa`

Change in `project.yml` if you use a different id — it must match the Firebase iOS app.

## One-time: Firebase iOS app

1. [Firebase Console](https://console.firebase.google.com/project/hackathon2025-472017/settings/general/) → **Add app** → iOS  
2. Bundle ID: `com.fernandogator.mekasa`  
3. Download **`GoogleService-Info.plist`**  
4. Place it at `ios/Mekasa/GoogleService-Info.plist` (gitignored — do not commit secrets you care about locking down)  
5. Authentication already has **Google** + **Email/Password** enabled  

### Google Sign-In URL scheme

From `GoogleService-Info.plist`, copy `REVERSED_CLIENT_ID` into `ios/Mekasa/Info.plist` under `CFBundleURLTypes` (placeholder noted in file).

## Open in Xcode (Mac)

Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) if needed:

```bash
brew install xcodegen
cd ios
xcodegen generate
open Mekasa.xcodeproj
```

In Xcode:

1. Add **Firebase** via SPM: `https://github.com/firebase/firebase-ios-sdk`  
   Products: `FirebaseAuth`, `FirebaseCore`  
2. Add **GoogleSignIn** via SPM: `https://github.com/google/GoogleSignIn-iOS`  
3. Signing & Capabilities → your Team  
4. Run on simulator or device  

## Auth modes

| Mode | Behavior |
|------|----------|
| Debug + no `GoogleService-Info.plist` | Dev sign-in button uses API stub only if you point at a build with `ALLOW_TEST_AUTH` (not recommended against prod) |
| Release / with Firebase plist | Email + Google → Firebase ID token → `Authorization: Bearer <idToken>` |

Prod API has `ALLOW_TEST_AUTH=false` — you need a real Firebase token.

## Spec mapping

- UI-003 Onboarding · REQ-001 Auth · REQ-002 Household · REQ-003 Address/Stores  
- Design: `design/mockups/OnboardingHouseholdSetup.jsx`, `OnboardingStoreSelection.jsx`
