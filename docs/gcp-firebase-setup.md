# GCP + Firebase setup (Mekasa thin API)

Do these in your browser. Billing account is already available (per your note).
Paste the **project ID** back into chat when done so we can wire env vars / deploy.

## 1. Create the GCP project

1. Open [Google Cloud Console](https://console.cloud.google.com/)
2. Project picker → **New Project**
3. Name suggestion: `mekasa` (or `mekasa-dev`)
4. Select your billing account
5. Create, then note the **Project ID** (not just the name)

Enable APIs (APIs & Services → Enable):

- Cloud Run API
- Cloud Build API
- Artifact Registry API
- Secret Manager API
- Cloud Firestore API
- Identity Toolkit API (Firebase Auth)

```bash
gcloud config set project YOUR_PROJECT_ID
gcloud services enable run.googleapis.com cloudbuild.googleapis.com \
  artifactregistry.googleapis.com secretmanager.googleapis.com \
  firestore.googleapis.com identitytoolkit.googleapis.com
```

## 2. Add Firebase to the same project

1. Open [Firebase Console](https://console.firebase.google.com/)
2. **Add project** → select the GCP project you just created
3. Disable Google Analytics for now (optional; can enable later)
4. Continue

### Auth providers

Build → Authentication → Sign-in method → enable:

1. **Email/Password**
2. **Apple** (needs Apple Developer Team ID, Key ID, private key, Services ID)
3. **Google**

For iOS later: Project settings → Add app → iOS → bundle id (e.g. `com.yourname.mekasa`) → download `GoogleService-Info.plist` (do **not** commit secrets that don’t belong in git; plist is usually OK but keep API keys restricted).

### Firestore

Build → Firestore Database → Create database → **production mode** (or test mode only for a short sandbox) → region close to Cloud Run (e.g. `nam5` / `us-central1`).

Rules can stay locked to authenticated users; the API uses the Admin SDK.

## 3. Service account for the API

1. GCP Console → IAM & Admin → Service Accounts
2. Create `mekasa-api` with roles:
   - Cloud Datastore User (or Firebase Admin SDK Administrator Service Agent)
   - Secret Manager Secret Accessor
3. Keys → Add key → JSON → download **once** to a local path outside the repo
4. Local only:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/mekasa-api.json
export GCP_PROJECT_ID=YOUR_PROJECT_ID
export FIREBASE_PROJECT_ID=YOUR_PROJECT_ID
export ALLOW_TEST_AUTH=false
```

Never commit the JSON key. Prefer Workload Identity on Cloud Run (no key file) for deploy.

## 4. Reply here with

- Project ID: `…`
- Region preference: e.g. `us-central1`
- Whether Apple Sign In is ready now or should wait (Google + email first is fine)

Then we can deploy the scaffolded `backend/` to Cloud Run and start the iOS onboarding client against it.
