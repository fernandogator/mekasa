# GCP + Firebase setup — Mekasa

## Confirmed for this repo

| Setting | Value |
|---------|--------|
| GCP / Firebase project ID | `hackathon2025-472017` |
| Region | `us-central1` |
| Auth for v1 onboarding | **Google + Email/Password first** (Apple later) |

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
   - Skip **Apple** for now
3. Firestore → Create database → region near `us-central1` (e.g. `nam5`)

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
