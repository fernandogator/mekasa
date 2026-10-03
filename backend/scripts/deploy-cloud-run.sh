#!/usr/bin/env bash
# Deploy Mekasa thin API to Cloud Run.
# Run from a machine with gcloud authenticated to project hackathon2025-472017.
set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:-hackathon2025-472017}"
REGION="${GCP_REGION:-us-central1}"
SERVICE="${CLOUD_RUN_SERVICE:-mekasa-api}"
# Cold starts add ~6 s to the first barcode lookup after idle. Set
# CLOUD_RUN_MIN_INSTANCES=1 to keep one warm instance (billed while idle).
MIN_INSTANCES="${CLOUD_RUN_MIN_INSTANCES:-0}"
# Shared Postgres (store item / UPC tables); create with provision-cloud-sql.sh.
SQL_INSTANCE="${CLOUD_SQL_INSTANCE:-mekasa-pg}"
DATABASE_URL_SECRET="${DATABASE_URL_SECRET:-mekasa-database-url}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Project:  $PROJECT_ID"
echo "Region:   $REGION"
echo "Service:  $SERVICE"
echo "Source:   $ROOT"
echo "Min inst: $MIN_INSTANCES"

gcloud config set project "$PROJECT_ID"

gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  firestore.googleapis.com \
  identitytoolkit.googleapis.com \
  vision.googleapis.com \
  aiplatform.googleapis.com \
  sqladmin.googleapis.com \
  --project "$PROJECT_ID"

# Receipt scanning calls Gemini on Vertex AI as the runtime service account.
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:mekasa-api@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role "roles/aiplatform.user" \
  --condition=None \
  --quiet >/dev/null

SQL_FLAGS=()
if gcloud secrets describe "$DATABASE_URL_SECRET" --project "$PROJECT_ID" >/dev/null 2>&1; then
  SQL_FLAGS=(
    --add-cloudsql-instances "${PROJECT_ID}:${REGION}:${SQL_INSTANCE}"
    --set-secrets "DATABASE_URL=${DATABASE_URL_SECRET}:latest"
  )
else
  echo "WARNING: secret $DATABASE_URL_SECRET missing; store tables will be in memory."
  echo "         Run backend/scripts/provision-cloud-sql.sh first."
fi

gcloud run deploy "$SERVICE" \
  --source "$ROOT" \
  --region "$REGION" \
  --project "$PROJECT_ID" \
  --allow-unauthenticated \
  --min-instances "$MIN_INSTANCES" \
  --set-env-vars "ENVIRONMENT=prod,GCP_PROJECT_ID=${PROJECT_ID},FIREBASE_PROJECT_ID=${PROJECT_ID},FIRESTORE_DATABASE_ID=mekasa-db,HOUSEHOLD_PERSISTENCE=firestore,ALLOW_TEST_AUTH=false" \
  --service-account "mekasa-api@${PROJECT_ID}.iam.gserviceaccount.com" \
  ${SQL_FLAGS[@]+"${SQL_FLAGS[@]}"}

echo
echo "Service URL:"
gcloud run services describe "$SERVICE" \
  --region "$REGION" \
  --project "$PROJECT_ID" \
  --format='value(status.url)'
