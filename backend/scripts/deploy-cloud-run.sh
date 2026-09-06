#!/usr/bin/env bash
# Deploy Mekasa thin API to Cloud Run.
# Run from a machine with gcloud authenticated to project hackathon2025-472017.
set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:-hackathon2025-472017}"
REGION="${GCP_REGION:-us-central1}"
SERVICE="${CLOUD_RUN_SERVICE:-mekasa-api}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Project:  $PROJECT_ID"
echo "Region:   $REGION"
echo "Service:  $SERVICE"
echo "Source:   $ROOT"

gcloud config set project "$PROJECT_ID"

gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  firestore.googleapis.com \
  identitytoolkit.googleapis.com \
  --project "$PROJECT_ID"

gcloud run deploy "$SERVICE" \
  --source "$ROOT" \
  --region "$REGION" \
  --project "$PROJECT_ID" \
  --allow-unauthenticated \
  --set-env-vars "ENVIRONMENT=prod,GCP_PROJECT_ID=${PROJECT_ID},FIREBASE_PROJECT_ID=${PROJECT_ID},FIRESTORE_DATABASE_ID=mekasa-db,ALLOW_TEST_AUTH=false"

echo
echo "Service URL:"
gcloud run services describe "$SERVICE" \
  --region "$REGION" \
  --project "$PROJECT_ID" \
  --format='value(status.url)'
