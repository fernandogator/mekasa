# Web app cloud setup (Terraform)

One-time setup for the desktop web app (UI-007, ADR-010) in project
`hackathon2025-472017`. It manages only what the web app adds:

| What | Why |
|---|---|
| Enables Firebase, Hosting, Identity Toolkit, Installations and API Keys APIs | Hosting and web sign-in |
| Default Hosting site `hackathon2025-472017` | Serves `*.web.app` / `*.firebaseapp.com` |
| `roles/firebasehosting.admin`, `roles/run.viewer`, `roles/serviceusage.serviceUsageConsumer` for the deploy account | `firebase deploy --only hosting` with the `/v1/**` Cloud Run rewrite |
| Referrer and API restrictions on the Firebase browser key (optional) | The key ships in the page by design; this limits where it works |
| GitHub Actions variables `FIREBASE_WEB_*` and `WEB_API_DIRECT_URL` | Read by the web build (UI-007 AC17); values come from Firebase and Cloud Run, nothing is copied by hand |

Cloud Run, the photo buckets and the runtime account (including its
signing role for REQ-023) stay with `backend/scripts/deploy-cloud-run.sh`.
Auth's authorized domains already include the default `web.app` and
`firebaseapp.com` addresses, so they are not managed here.

## Prerequisites

- Terraform 1.7 or newer, and `gcloud auth application-default login` as a
  project owner.
- A GitHub token allowed to write Actions variables on the repository
  (fine-grained: *Variables: read and write*), exported as `GITHUB_TOKEN`.
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
- `deployer_service_account`: the `client_email` of the key in the
  `GCP_SA_KEY` GitHub secret. Use a dedicated deploy account rather than
  the `mekasa-api` runtime account, so the API itself cannot change Hosting.
- `import_hosting_site`: run `firebase hosting:sites:list --project
  hackathon2025-472017`. Set `true` if the default site is listed. If you
  guess wrong, apply fails with "already exists" (set `true`) or "cannot
  import non-existent remote object" (set `false`).
- `browser_api_key_id`: optional. Get it with
  `gcloud services api-keys list --project hackathon2025-472017
  --filter='displayName:"Browser key"' --format='value(uid)'`. Before
  setting it, confirm the iOS and Android apps use their own keys (their
  `GoogleService-Info.plist` / `google-services.json` show a different
  key), because the restriction blocks every other caller.

The browser key allows only the default addresses and `localhost:5173`.
Sign-in on PR preview channels (`<project>--<channel>.web.app`) needs
those hosts added to `browser_key_referrers` and to Auth's authorized
domains.

## Tests

```bash
terraform test   # mocked providers; no credentials needed
```
