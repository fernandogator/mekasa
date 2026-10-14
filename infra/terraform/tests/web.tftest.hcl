mock_provider "google" {
  mock_data "google_cloud_run_v2_service" {
    defaults = { uri = "https://mekasa-api-abc-uc.a.run.app" }
  }
}

mock_provider "google-beta" {
  mock_data "google_firebase_web_app_config" {
    defaults = {
      api_key             = "test-api-key"
      auth_domain         = "hackathon2025-472017.firebaseapp.com"
      messaging_sender_id = "123"
      measurement_id      = "G-TEST"
    }
  }
}

mock_provider "github" {}

variables {
  web_app_id               = "1:123:web:abc123"
  deployer_service_account = "deployer@hackathon2025-472017.iam.gserviceaccount.com"
}

run "grants_hosting_deploy_roles" {
  command = plan

  assert {
    condition = toset([for m in google_project_iam_member.deployer : m.role]) == toset([
      "roles/firebasehosting.admin",
      "roles/run.viewer",
      "roles/serviceusage.serviceUsageConsumer",
    ])
    error_message = "Deployer must get exactly the Hosting deploy roles."
  }

  assert {
    condition     = alltrue([for m in google_project_iam_member.deployer : m.member == "serviceAccount:deployer@hackathon2025-472017.iam.gserviceaccount.com"])
    error_message = "Roles must go to the deploy service account."
  }
}

run "writes_web_build_variables_from_firebase" {
  command = plan

  assert {
    condition     = length(github_actions_variable.web) == 7
    error_message = "Expected the six Firebase web values plus the direct API URL."
  }

  assert {
    condition     = github_actions_variable.web["FIREBASE_WEB_MEASUREMENT_ID"].value == "G-TEST"
    error_message = "Measurement ID must come from the Firebase web app config."
  }

  assert {
    condition     = github_actions_variable.web["WEB_API_DIRECT_URL"].value == "https://mekasa-api-abc-uc.a.run.app"
    error_message = "Direct API URL must be the Cloud Run service URL."
  }

  assert {
    condition     = google_firebase_hosting_site.default["default"].site_id == "hackathon2025-472017"
    error_message = "Hosting site must be the project's default site."
  }
}

run "leaves_browser_key_alone_without_an_id" {
  command = plan

  assert {
    condition     = length(google_apikeys_key.browser) == 0
    error_message = "The browser key is only managed once its ID is supplied."
  }
}

run "rejects_a_malformed_web_app_id" {
  command = plan

  variables {
    web_app_id = "not-an-app-id"
  }

  expect_failures = [var.web_app_id]
}
