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
CATALOG_SALT_SECRET="${CATALOG_SALT_SECRET:-mekasa-catalog-salt}"
# Household-private item photos (REQ-INV-019). Private bucket, uniform access,
# readable only by the runtime service account; created here if missing.
ITEM_PHOTO_BUCKET="${ITEM_PHOTO_BUCKET:-mekasa-item-photos-prod}"
# Shared product photos from the capture flow (REQ-RCP-021). Same private
# bucket setup; reads go through 15-minute signed URLs, so the runtime service
# account also needs to sign blobs as itself.
PRODUCT_PHOTO_BUCKET="${PRODUCT_PHOTO_BUCKET:-mekasa-product-photos-prod}"
RUNTIME_SA="mekasa-api@${PROJECT_ID}.iam.gserviceaccount.com"

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
  iamcredentials.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  firestore.googleapis.com \
  identitytoolkit.googleapis.com \
  vision.googleapis.com \
  aiplatform.googleapis.com \
  sqladmin.googleapis.com \
  storage.googleapis.com \
  --project "$PROJECT_ID"

# Private item photos: one bucket, no public access, service account only.
if ! gcloud storage buckets describe "gs://${ITEM_PHOTO_BUCKET}" --project "$PROJECT_ID" >/dev/null 2>&1; then
  gcloud storage buckets create "gs://${ITEM_PHOTO_BUCKET}" \
    --project "$PROJECT_ID" \
    --location "$REGION" \
    --uniform-bucket-level-access \
    --public-access-prevention
fi
gcloud storage buckets add-iam-policy-binding "gs://${ITEM_PHOTO_BUCKET}" \
  --member "serviceAccount:mekasa-api@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role "roles/storage.objectUser" \
  --quiet >/dev/null

if ! gcloud storage buckets describe "gs://${PRODUCT_PHOTO_BUCKET}" --project "$PROJECT_ID" >/dev/null 2>&1; then
  gcloud storage buckets create "gs://${PRODUCT_PHOTO_BUCKET}" \
    --project "$PROJECT_ID" \
    --location "$REGION" \
    --uniform-bucket-level-access \
    --public-access-prevention
fi
gcloud storage buckets add-iam-policy-binding "gs://${PRODUCT_PHOTO_BUCKET}" \
  --member "serviceAccount:${RUNTIME_SA}" \
  --role "roles/storage.objectUser" \
  --quiet >/dev/null
# V4 signed URLs on Cloud Run are signed via IAM signBlob as the runtime account.
gcloud iam service-accounts add-iam-policy-binding "$RUNTIME_SA" \
  --project "$PROJECT_ID" \
  --member "serviceAccount:${RUNTIME_SA}" \
  --role "roles/iam.serviceAccountTokenCreator" \
  --quiet >/dev/null

# Receipt scanning calls Gemini on Vertex AI as the runtime service account.
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:mekasa-api@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role "roles/aiplatform.user" \
  --condition=None \
  --quiet >/dev/null

SQL_FLAGS=()
SECRETS=()
if gcloud secrets describe "$DATABASE_URL_SECRET" --project "$PROJECT_ID" >/dev/null 2>&1; then
  SQL_FLAGS=(--add-cloudsql-instances "${PROJECT_ID}:${REGION}:${SQL_INSTANCE}")
  SECRETS+=("DATABASE_URL=${DATABASE_URL_SECRET}:latest")
else
  echo "WARNING: secret $DATABASE_URL_SECRET missing; the catalog will be in memory."
  echo "         Run backend/scripts/provision-cloud-sql.sh first."
fi
# Without the salt, prod refuses catalog writes (503 catalog_unavailable) rather
# than hashing households with the public development salt (REQ-RCP-009 AC5).
if gcloud secrets describe "$CATALOG_SALT_SECRET" --project "$PROJECT_ID" >/dev/null 2>&1; then
  SECRETS+=("CATALOG_HOUSEHOLD_SALT=${CATALOG_SALT_SECRET}:latest")
else
  echo "WARNING: secret $CATALOG_SALT_SECRET missing; catalog writes will return 503."
  echo "         Run backend/scripts/provision-cloud-sql.sh first."
fi
if [ ${#SECRETS[@]} -gt 0 ]; then
  SQL_FLAGS+=(--set-secrets "$(IFS=,; echo "${SECRETS[*]}")")
fi

gcloud run deploy "$SERVICE" \
  --source "$ROOT" \
  --region "$REGION" \
  --project "$PROJECT_ID" \
  --allow-unauthenticated \
  --min-instances "$MIN_INSTANCES" \
  --set-env-vars "ENVIRONMENT=prod,GCP_PROJECT_ID=${PROJECT_ID},FIREBASE_PROJECT_ID=${PROJECT_ID},FIRESTORE_DATABASE_ID=mekasa-db,HOUSEHOLD_PERSISTENCE=firestore,ALLOW_TEST_AUTH=false,ITEM_PHOTO_BUCKET=${ITEM_PHOTO_BUCKET},PRODUCT_PHOTO_BUCKET=${PRODUCT_PHOTO_BUCKET}" \
  --service-account "mekasa-api@${PROJECT_ID}.iam.gserviceaccount.com" \
  ${SQL_FLAGS[@]+"${SQL_FLAGS[@]}"}

echo
echo "Service URL:"
gcloud run services describe "$SERVICE" \
  --region "$REGION" \
  --project "$PROJECT_ID" \
  --format='value(status.url)'
