# One-time cloud setup for the desktop web app (UI-007, ADR-010).
#
# Manages only what the web app adds: the APIs it needs, the Hosting site,
# the deploy account's Hosting roles, the browser API key restrictions and
# the GitHub Actions variables the web build reads. Cloud Run, buckets and
# the runtime account stay with backend/scripts/deploy-cloud-run.sh.

locals {
  apis = [
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
    "identitytoolkit.googleapis.com",
    "firebaseinstallations.googleapis.com",
    "apikeys.googleapis.com",
  ]

  # firebase deploy --only hosting with a Cloud Run rewrite (ADR-010).
  deployer_roles = [
    "roles/firebasehosting.admin",
    "roles/run.viewer",
    "roles/serviceusage.serviceUsageConsumer",
  ]

  hosting_site_import = var.import_hosting_site ? { default = var.project_id } : {}
  browser_key_import  = var.browser_api_key_id == "" ? {} : { browser = var.browser_api_key_id }
}

resource "google_project_service" "web" {
  for_each = toset(local.apis)

  service            = each.value
  disable_on_destroy = false
}

resource "google_project_iam_member" "deployer" {
  for_each = toset(local.deployer_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${var.deployer_service_account}"
}

import {
  for_each = local.hosting_site_import
  to       = google_firebase_hosting_site.default[each.key]
  id       = "projects/${var.project_id}/sites/${each.value}"
}

# Serves https://<project>.web.app and https://<project>.firebaseapp.com.
resource "google_firebase_hosting_site" "default" {
  for_each = { default = var.project_id }
  provider = google-beta

  project = var.project_id
  site_id = each.value
  app_id  = var.web_app_id

  depends_on = [google_project_service.web]
}

import {
  for_each = local.browser_key_import
  to       = google_apikeys_key.browser[each.key]
  id       = "projects/${var.project_id}/locations/global/keys/${each.value}"
}

# The key Firebase created for the web app. It ships in the page by design,
# so it is locked to our pages and to the APIs the app calls.
resource "google_apikeys_key" "browser" {
  for_each = local.browser_key_import

  project      = var.project_id
  name         = each.value
  display_name = "Browser key (auto created by Firebase)"

  restrictions {
    browser_key_restrictions {
      allowed_referrers = var.browser_key_referrers
    }

    dynamic "api_targets" {
      for_each = var.browser_key_apis
      content {
        service = api_targets.value
      }
    }
  }

  depends_on = [google_project_service.web]
}

data "google_firebase_web_app_config" "web" {
  provider   = google-beta
  project    = var.project_id
  web_app_id = var.web_app_id
}

data "google_cloud_run_v2_service" "api" {
  name     = var.api_service
  location = var.region
}
