# One-time cloud setup for the desktop web app (UI-007, ADR-010) and keyless
# CI deploys (deployer.tf).
#
# Manages the APIs these need, the Hosting site, Auth's authorized domains,
# the browser API key restrictions and the GitHub Actions variables CI reads. The Cloud Run
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

  browser_key_import = var.browser_api_key_id == "" ? {} : { browser = var.browser_api_key_id }
}

resource "google_project_service" "web" {
  for_each = toset(local.apis)

  service            = each.value
  disable_on_destroy = false
}

import {
  to = google_firebase_hosting_site.web
  id = "projects/${var.project_id}/sites/${var.hosting_site_id}"
}

# Serves https://<site>.web.app and https://<site>.firebaseapp.com. The site
# already exists and is linked to the web app, so it is always imported.
resource "google_firebase_hosting_site" "web" {
  provider = google-beta

  project = var.project_id
  site_id = var.hosting_site_id
  app_id  = var.web_app_id

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.web]
}

# The project's default site can't be deleted; stop managing it, keep it.
removed {
  from = google_firebase_hosting_site.default

  lifecycle {
    destroy = false
  }
}

import {
  to = google_identity_platform_config.auth
  id = "projects/${var.project_id}/config"
}

# Only the authorized domains are managed here: Google sign-in uses a popup,
# which Auth refuses on pages outside this list. Sign-in methods and every
# other Auth setting stay with the Firebase console.
resource "google_identity_platform_config" "auth" {
  project            = var.project_id
  authorized_domains = var.auth_authorized_domains

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      autodelete_anonymous_users,
      blocking_functions,
      client,
      mfa,
      monitoring,
      multi_tenant,
      quota,
      sign_in,
      sms_region_config,
    ]
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
