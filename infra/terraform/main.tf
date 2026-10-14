# One-time cloud setup for the desktop web app (UI-007, ADR-010) and keyless
# CI deploys (deployer.tf).
#
# Manages the APIs these need, the Hosting site, the browser API key
# restrictions and the GitHub Actions variables CI reads. The Cloud Run
# service, buckets and the runtime account's own roles stay with
# backend/scripts/deploy-cloud-run.sh.

locals {
  apis = [
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
    "identitytoolkit.googleapis.com",
    "firebaseinstallations.googleapis.com",
    "apikeys.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ]

  hosting_site_import = var.import_hosting_site ? { default = var.project_id } : {}
  browser_key_import  = var.browser_api_key_id == "" ? {} : { browser = var.browser_api_key_id }
}

resource "google_project_service" "web" {
  for_each = toset(local.apis)

  service            = each.value
  disable_on_destroy = false
}

import {
  for_each = local.hosting_site_import
  to       = google_firebase_hosting_site.default[each.key]
  id       = "projects/${var.project_id}/sites/${each.value}"
}

# Serves https://<project>.web.app and https://<project>.firebaseapp.com.
# Not linked to the web app: that link only feeds /__/firebase/init.json,
# which the app does not use, and the app is already linked to the `mekasa`
# site.
resource "google_firebase_hosting_site" "default" {
  for_each = { default = var.project_id }
  provider = google-beta

  project = var.project_id
  site_id = each.value

  lifecycle {
    prevent_destroy = true
  }

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
