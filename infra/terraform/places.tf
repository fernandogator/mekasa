# Server key for store discovery (REQ-003 AC7–AC8): Places API (New) finds
# nearby grocery stores and the Geocoding API turns a typed home address into
# coordinates. The key never reaches a client; Cloud Run reads it from Secret
# Manager as GOOGLE_PLACES_API_KEY (backend/scripts/deploy-cloud-run.sh).
#
# The key string is stored in Terraform state, so the state bucket must stay
# private to project owners.

locals {
  places_apis = [
    "places.googleapis.com",
    "geocoding-backend.googleapis.com",
  ]
}

resource "google_project_service" "places" {
  for_each = toset(concat(local.places_apis, ["secretmanager.googleapis.com"]))

  service            = each.value
  disable_on_destroy = false
}

# Cloud Run has no fixed egress address, so the key is limited by API only.
resource "google_apikeys_key" "places" {
  project      = var.project_id
  name         = "mekasa-places-server"
  display_name = "Mekasa API: Places and Geocoding (server)"

  restrictions {
    dynamic "api_targets" {
      for_each = local.places_apis
      content {
        service = api_targets.value
      }
    }
  }

  depends_on = [google_project_service.web, google_project_service.places]
}

resource "google_secret_manager_secret" "places_key" {
  project   = var.project_id
  secret_id = var.places_key_secret

  replication {
    auto {}
  }

  depends_on = [google_project_service.places]
}

resource "google_secret_manager_secret_version" "places_key" {
  secret      = google_secret_manager_secret.places_key.id
  secret_data = google_apikeys_key.places.key_string
}

resource "google_secret_manager_secret_iam_member" "runtime_reads_places_key" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.places_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.runtime_service_account}"
}
