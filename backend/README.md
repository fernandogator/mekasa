# Mekasa API (thin onboarding slice)

Python FastAPI service for Cloud Run. This slice covers:

- Firebase Auth JWT verification (`Authorization: Bearer <idToken>`)
- Create / fetch household (`REQ-001`, `REQ-002`)
- Confirm home address (`REQ-003`)
- Nearby store list + selection (`REQ-003`; Places stub until API key is wired)

## Local run

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export ALLOW_TEST_AUTH=true
export ENVIRONMENT=local
uvicorn app.main:app --reload --port 8080
```

OpenAPI docs: http://localhost:8080/docs

### Test auth (local only)

```bash
curl -s http://localhost:8080/health
curl -s -H 'Authorization: Bearer test:demo' http://localhost:8080/v1/me
```

### Unit tests

```bash
cd backend
PYTHONPATH=. ALLOW_TEST_AUTH=true pytest ../tests/backend -q
```

## Endpoints

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/health` | no | Liveness |
| GET | `/v1/me` | yes | Caller profile from token |
| POST | `/v1/households` | yes | Create household |
| GET | `/v1/households/current` | yes | Current user's household |
| PUT | `/v1/households/{id}/address` | yes | Confirm address |
| GET | `/v1/households/{id}/stores/nearby` | yes | Stub/Places nearby stores |
| PUT | `/v1/households/{id}/stores` | yes | Persist selected store ids |

## Environment

| Variable | Required | Notes |
|----------|----------|-------|
| `ALLOW_TEST_AUTH` | local | `true` enables `Bearer test:<uid>` |
| `ENVIRONMENT` | no | `local` / `test` / `prod` |
| `GCP_PROJECT_ID` | prod | GCP project id |
| `FIREBASE_PROJECT_ID` | prod | Usually same as GCP project |
| `GOOGLE_APPLICATION_CREDENTIALS` | local+Firebase | Path to service-account JSON (never commit) |
| `GOOGLE_PLACES_API_KEY` | later | When leaving stub store search |

Production secrets belong in **GCP Secret Manager**, not in git.

## GCP / Firebase console checklist

See [`docs/gcp-firebase-setup.md`](../docs/gcp-firebase-setup.md).

## Deploy

Project: `hackathon2025-472017` · Region: `us-central1` · Auth: Google + email first

```bash
chmod +x scripts/deploy-cloud-run.sh
./scripts/deploy-cloud-run.sh
```

Clients send Firebase ID tokens; the API verifies them. Keep `ALLOW_TEST_AUTH=false` in prod.
Full checklist: [`docs/gcp-firebase-setup.md`](../docs/gcp-firebase-setup.md).
