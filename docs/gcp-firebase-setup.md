# GCP + Firebase setup — Mekasa

## Confirmed for this repo

| Setting | Value |
|---------|--------|
| GCP / Firebase project ID | `hackathon2025-472017` |
| Cloud Run region | `us-central1` |
| Firestore database ID | `mekasa-db` |
| Firestore location | **`nam5` (United States multi-region)** |
| Firestore edition / rules | Standard · Restrictive |
| Auth for v1 onboarding | **Google + Email/Password** (Sign in with Apple deferred — REQ-001 AC1; §2b kept for when a paid team exists) |
| Cloud Run service | `https://mekasa-api-934775015882.us-central1.run.app` |
| Service account | `mekasa-api@hackathon2025-472017.iam.gserviceaccount.com` |

## Status (2026-09-22)

- [x] GCP project + APIs
- [x] Firebase Auth (Google + Email; Apple provider deferred with REQ-001 AC1)
- [x] Firestore `mekasa-db` @ `nam5` (Standard, Restrictive)
- [x] Service account + local JSON key
- [x] Cloud Run deploy + onboarding smoke
- [x] `ALLOW_TEST_AUTH=false` in prod
- [x] API persistence → Firestore (live health reports `firestore` / `mekasa-db`)
- [ ] **Redeploy Cloud Run** so `PUT /v1/households/{id}/name` (house name) is live — code is on `main`, revision is stale
- [x] Cloud Run runtime SA binding (deploy script)
- [ ] Real Firebase ID tokens from iOS (device / TestFlight)

## Finish in the console (if not done yet)

### 1. Enable APIs

```bash
gcloud config set project hackathon2025-472017
gcloud services enable run.googleapis.com cloudbuild.googleapis.com \
  artifactregistry.googleapis.com secretmanager.googleapis.com \
  firestore.googleapis.com identitytoolkit.googleapis.com
```

### 2. Firebase on the same project

1. [Firebase Console](https://console.firebase.google.com/) → add/select **hackathon2025-472017**
2. Authentication → Sign-in method → enable:
   - **Email/Password**
   - **Google**
   - **Apple** — *deferred*; not needed until Sign in with Apple returns (see §2b)
3. Firestore → Create database → region near `us-central1` (e.g. `nam5`)

### 2b. Enable Sign in with Apple (Firebase + Apple Developer) — deferred

> Not required right now: the iOS app no longer requests the Sign in with Apple
> capability (REQ-001 AC1 deferred, free Personal Team). Keep for later.

1. [Apple Developer](https://developer.apple.com/account) → Identifiers → App ID `com.fernandogator.mekasa` → enable **Sign In with Apple**
2. When re-enabling, add `com.apple.developer.applesignin` back to `Mekasa/Mekasa.entitlements`
3. Firebase Console → Authentication → Sign-in method → **Apple** → Enable
4. For Apple’s Services ID / key (if Firebase asks): create a Services ID + key in the Apple Developer portal and paste Team ID, Key ID, and private key into Firebase
5. Rebuild the iOS app after `cd ios && xcodegen generate` so the entitlement is on the signed binary

Device/TestFlight is the reliable path; Simulator Apple sign-in can be flaky.

### 3. Service account (local Admin SDK)

1. IAM → Service Accounts → create `mekasa-api`
2. Roles: Firebase Admin SDK Administrator Service Agent (or Cloud Datastore User) + Secret Manager Secret Accessor
3. Keys → JSON → save **outside** the repo
4. Local:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/mekasa-api.json
export GCP_PROJECT_ID=hackathon2025-472017
export FIREBASE_PROJECT_ID=hackathon2025-472017
export ALLOW_TEST_AUTH=false
```

### 3b. Private item photos bucket (REQ-INV-019)

Members can replace an item picture with their own photo. Photos are stored
in a **private** Cloud Storage bucket under `households/{hid}/item-photos/`
and streamed through the API only to members of that household. The deploy
script creates the bucket and grants the runtime service account access;
to do it by hand:

```bash
gcloud storage buckets create gs://mekasa-item-photos-prod \
  --project hackathon2025-472017 --location us-central1 \
  --uniform-bucket-level-access --public-access-prevention
gcloud storage buckets add-iam-policy-binding gs://mekasa-item-photos-prod \
  --member serviceAccount:mekasa-api@hackathon2025-472017.iam.gserviceaccount.com \
  --role roles/storage.objectUser
```

Cloud Run gets `ITEM_PHOTO_BUCKET=mekasa-item-photos-prod`. Leave it unset
locally and the API keeps photos in memory. Nothing in this bucket is public,
and object names never leave the API (clients only see
`/v1/households/{hid}/item-photos/{photo_id}`).

### 4. Deploy Cloud Run (from your Mac)

```bash
cd backend
chmod +x scripts/deploy-cloud-run.sh
./scripts/deploy-cloud-run.sh
```

Paste the printed **Service URL** back into chat.

### 5. iOS app (after deploy)

- Firebase → Project settings → Add iOS app → bundle id (e.g. `com.fernandogator.mekasa`)
- Download `GoogleService-Info.plist` for the Xcode project (do not commit unrestricted secrets; restrict API keys in GCP)

## Local API without Firebase (unit / UI wiring)

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --port 8080
# Authorization: Bearer test:demo
```
