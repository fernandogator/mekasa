# Cloud setup for the web app and keyless deploys (Terraform)

One-time setup in project `hackathon2025-472017` for the desktop web app
(UI-007, ADR-010) and for CI deploys without a service account key
(`docs/gcp-firebase-setup.md` §4b).

| What | Why |
|---|---|
| Enables the Firebase, Hosting, Identity Toolkit, Installations, API Keys, IAM, IAM Credentials and STS APIs | Hosting, web sign-in and keyless sign-in |
| Hosting site `mekasa` (imported; already linked to the web app) | Serves `https://mekasa.web.app` and `https://mekasa.firebaseapp.com` |
| Auth authorized domains | Google sign-in uses a popup, which Auth refuses outside this list. Only the list is managed; sign-in methods stay in the console |
| `mekasa-deployer` service account | The only account CI deploys as; it has no key |
| Deployer roles: `run.sourceDeveloper`, `secretmanager.viewer`, `serviceusage.serviceUsageConsumer`, `firebasehosting.admin`, `run.viewer`, plus `iam.serviceAccountUser` on `mekasa-api` only | `deploy-cloud-run.sh` with `DEPLOY_ONLY=1`, and `firebase deploy --only hosting` with the Cloud Run rewrite |
| Workload Identity pool `github`, provider `mekasa` | GitHub Actions signs in with short-lived tokens. Only this repository's tokens are accepted, and only jobs in the `mekasa-prod` environment may act as the deployer |
| `mekasa-prod` environment variables `GCP_WORKLOAD_IDENTITY_PROVIDER` and `GCP_DEPLOY_SERVICE_ACCOUNT` | Already read by `ci.yml` (deploy-prod) and `deploy-backend.yml` |
| Repository variables `FIREBASE_WEB_*` and `WEB_API_DIRECT_URL` | Read by the web build (UI-007 AC17); values come from Firebase and Cloud Run |
| Referrer and API restrictions on the Firebase browser key (optional) | The key ships in the page by design; this limits where it works |
| Places API (New), Geocoding API and Secret Manager; server key `mekasa-places-server` limited to Places and Geocoding; secret `mekasa-places-api-key` holding it; `secretAccessor` on that secret for `mekasa-api` | Store discovery (REQ-003 AC7–AC8). `deploy-cloud-run.sh` passes the secret to Cloud Run as `GOOGLE_PLACES_API_KEY` |

The Cloud Run service, the photo buckets and the runtime account's own
roles (including its signing role for REQ-023) stay with
`backend/scripts/deploy-cloud-run.sh`. The project's default site
(`hackathon2025-472017.web.app`) still exists, because Firebase can't delete
it, but nothing is deployed there.

## Prerequisites

- Terraform 1.7 or newer (`brew install hashicorp/tap/terraform`; plain
  `brew install terraform` is stuck at 1.5.7).
- `gcloud auth application-default login` as a project owner.
- A GitHub token allowed to write Actions variables on the repository
  (fine-grained: *Variables: read and write*), exported as `GITHUB_TOKEN`.
- The GitHub environment `mekasa-prod` exists (Settings > Environments).
  It is created by the first run that uses it; create it by hand if no
  deploy has run yet.
- A state bucket (once):

  ```bash
  gcloud storage buckets create gs://hackathon2025-472017-tfstate \
    --project hackathon2025-472017 --location us-central1 --uniform-bucket-level-access
  gcloud storage buckets update gs://hackathon2025-472017-tfstate --versioning
  ```

## Run

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # untracked; fill in the values
terraform init -backend-config=bucket=hackathon2025-472017-tfstate
terraform plan
terraform apply
```

Values for `terraform.tfvars`:

- `web_app_id`: the web app's `appId` from Firebase console > Project
  settings > Your apps.
- `browser_api_key_id`: optional. Get it with
  `gcloud services api-keys list --project hackathon2025-472017
  --filter='displayName:"Browser key"' --format='value(uid)'`. Before
  setting it, confirm the iOS and Android apps use their own keys (their
  `GoogleService-Info.plist` / `google-services.json` show a different
  key), because the restriction blocks every other caller.

`auth_authorized_domains` replaces the list in the Firebase console, so
`terraform plan` shows any domain added there by hand as being removed. Add
it to the variable before applying.

The browser key allows only the `mekasa` addresses and `localhost:5173`.
Sign-in on PR preview channels (`mekasa--<channel>.web.app`) needs those
hosts added to `browser_key_referrers` and to `auth_authorized_domains`.

The Places key string ends up in Terraform state, which is one more reason
the state bucket stays private to project owners. After the first apply that
creates the key, redeploy the backend (**Actions > Deploy backend (Cloud
Run)** or `backend/scripts/deploy-cloud-run.sh`) so Cloud Run picks up the
secret; until then store search finds no stores in production.

## After apply: retire the old key

CI prefers the keyless variables as soon as they exist. Once a deploy
has worked without the key:

1. Run **Actions > Deploy backend (Cloud Run)**. The log should say it
   authenticated through Workload Identity as `mekasa-deployer`, and the
   `/health` check should pass.
2. Delete the `GCP_SA_KEY` secret (repository and `mekasa-prod`
   environment, wherever it is set).
3. Delete the downloaded `mekasa-api` keys:

   ```bash
   gcloud iam service-accounts keys list \
     --iam-account mekasa-api@hackathon2025-472017.iam.gserviceaccount.com --managed-by=user
   gcloud iam service-accounts keys delete <KEY_ID> \
     --iam-account mekasa-api@hackathon2025-472017.iam.gserviceaccount.com
   ```

4. Review the project roles `mekasa-api` holds and remove any it only had
   for deploying (for example `roles/run.admin` or Cloud Build roles):

   ```bash
   gcloud projects get-iam-policy hackathon2025-472017 \
     --flatten='bindings[].members' \
     --filter='bindings.members:serviceAccount:mekasa-api@' \
     --format='value(bindings.role)'
   ```

   At runtime the API needs Firestore, Secret Manager access, Cloud SQL
   client, `aiplatform.user`, its bucket access and signing as itself.

If a keyless deploy fails with `PERMISSION_DENIED`, the log names the
missing permission. Add that role to `deployer_roles` in `deployer.tf`, not
to the runtime account.

## Tests

```bash
terraform test   # mocked providers; no credentials needed
```
