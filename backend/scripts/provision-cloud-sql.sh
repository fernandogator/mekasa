#!/usr/bin/env bash
# One-time: create the Cloud SQL Postgres instance for data shared across all
# accounts (per-store item / UPC tables) and store its DATABASE_URL in Secret
# Manager for Cloud Run. Safe to re-run: existing resources are kept.
# The API creates its tables on startup (backend/app/store_catalog.sql).
set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:-hackathon2025-472017}"
REGION="${GCP_REGION:-us-central1}"
INSTANCE="${CLOUD_SQL_INSTANCE:-mekasa-pg}"
# Smallest shared-core tier; raise (e.g. db-custom-1-3840) when traffic grows.
TIER="${CLOUD_SQL_TIER:-db-f1-micro}"
DB_NAME="${CLOUD_SQL_DB:-mekasa}"
DB_USER="${CLOUD_SQL_USER:-mekasa_api}"
SECRET="${DATABASE_URL_SECRET:-mekasa-database-url}"
SERVICE_ACCOUNT="mekasa-api@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Project:  $PROJECT_ID"
echo "Region:   $REGION"
echo "Instance: $INSTANCE ($TIER)"

gcloud services enable sqladmin.googleapis.com secretmanager.googleapis.com \
  --project "$PROJECT_ID"

if ! gcloud sql instances describe "$INSTANCE" --project "$PROJECT_ID" >/dev/null 2>&1; then
  gcloud sql instances create "$INSTANCE" \
    --project "$PROJECT_ID" \
    --region "$REGION" \
    --database-version POSTGRES_16 \
    --edition enterprise \
    --tier "$TIER" \
    --storage-auto-increase \
    --backup-start-time 08:00
fi

if ! gcloud sql databases describe "$DB_NAME" --instance "$INSTANCE" --project "$PROJECT_ID" >/dev/null 2>&1; then
  gcloud sql databases create "$DB_NAME" --instance "$INSTANCE" --project "$PROJECT_ID"
fi

if ! gcloud secrets describe "$SECRET" --project "$PROJECT_ID" >/dev/null 2>&1; then
  PASSWORD="$(openssl rand -hex 24)"
  gcloud sql users create "$DB_USER" --instance "$INSTANCE" --project "$PROJECT_ID" \
    --password "$PASSWORD"
  CONNECTION_NAME="$(gcloud sql instances describe "$INSTANCE" --project "$PROJECT_ID" \
    --format='value(connectionName)')"
  printf 'postgresql://%s:%s@/%s?host=/cloudsql/%s' \
    "$DB_USER" "$PASSWORD" "$DB_NAME" "$CONNECTION_NAME" |
    gcloud secrets create "$SECRET" --project "$PROJECT_ID" --data-file=-
fi

for ROLE in roles/cloudsql.client roles/secretmanager.secretAccessor; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member "serviceAccount:${SERVICE_ACCOUNT}" \
    --role "$ROLE" \
    --condition=None \
    --quiet >/dev/null
done

echo
echo "Done. Next: backend/scripts/deploy-cloud-run.sh attaches $INSTANCE and $SECRET."
