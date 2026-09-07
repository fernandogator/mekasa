# Mekasa iOS

SwiftUI client for Mekasa v1.0. First slice: **onboarding** (Welcome → Household → Address → Stores → Scan stub → Invite stub → Home stub) talking to Cloud Run.

## Live API

`https://mekasa-api-934775015882.us-central1.run.app`

## Bundle ID

`com.fernandogator.mekasa`

## Fix Firebase “default app has not yet been configured”

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
4. Auth: **Google** + **Email/Password** enabled  

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

SPM (via `project.yml`): FirebaseCore, FirebaseAuth, GoogleSignIn.

Signing → your Team → Run on an **iPhone Simulator** (not “Any iOS Device”).

### DEBUG: offline UI walkthrough

**Browse UI offline** walks onboarding with local fixtures (no Firebase/network).

## Spec mapping

- UI-003 Onboarding · REQ-001 Auth · REQ-002 Household · REQ-003 Address/Stores  
- Design: `design/mockups/OnboardingHouseholdSetup.jsx`, `OnboardingStoreSelection.jsx`
