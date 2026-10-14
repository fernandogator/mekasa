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

override_resource {
  target = google_service_account.deployer
  values = {
    email  = "mekasa-deployer@hackathon2025-472017.iam.gserviceaccount.com"
    member = "serviceAccount:mekasa-deployer@hackathon2025-472017.iam.gserviceaccount.com"
    name   = "projects/hackathon2025-472017/serviceAccounts/mekasa-deployer@hackathon2025-472017.iam.gserviceaccount.com"
  }
}

override_resource {
  target = google_iam_workload_identity_pool.github
  values = {
    name = "projects/123/locations/global/workloadIdentityPools/github"
  }
}

override_resource {
  target = google_iam_workload_identity_pool_provider.github
  values = {
    name = "projects/123/locations/global/workloadIdentityPools/github/providers/mekasa"
  }
}

variables {
  web_app_id = "1:123:web:abc123"
}

run "deployer_gets_only_deploy_roles" {
  command = apply

  # Apply fills in the overridden values; the protected Hosting site stays out
  # so teardown can destroy everything it created.
  plan_options {
    target = [
      google_project_iam_member.deployer,
      google_service_account_iam_member.deployer_acts_as_runtime,
      google_service_account_iam_member.github_deploys_as_deployer,
      github_actions_environment_variable.deploy,
    ]
  }

  assert {
    condition = toset([for m in google_project_iam_member.deployer : m.role]) == toset([
      "roles/run.sourceDeveloper",
      "roles/secretmanager.viewer",
      "roles/serviceusage.serviceUsageConsumer",
      "roles/firebasehosting.admin",
      "roles/run.viewer",
    ])
    error_message = "Deployer must get exactly the Cloud Run and Hosting deploy roles."
  }

  assert {
    condition     = alltrue([for m in google_project_iam_member.deployer : m.member == "serviceAccount:mekasa-deployer@hackathon2025-472017.iam.gserviceaccount.com"])
    error_message = "Roles must go to the dedicated deployer, not the runtime account."
  }

  assert {
    condition     = google_service_account_iam_member.deployer_acts_as_runtime.service_account_id == "projects/hackathon2025-472017/serviceAccounts/mekasa-api@hackathon2025-472017.iam.gserviceaccount.com" && google_service_account_iam_member.deployer_acts_as_runtime.role == "roles/iam.serviceAccountUser"
    error_message = "Deployer must be able to deploy as the runtime account."
  }
}

run "only_the_prod_environment_can_act_as_deployer" {
  command = apply

  # Apply fills in the overridden values; the protected Hosting site stays out
  # so teardown can destroy everything it created.
  plan_options {
    target = [
      google_project_iam_member.deployer,
      google_service_account_iam_member.deployer_acts_as_runtime,
      google_service_account_iam_member.github_deploys_as_deployer,
      github_actions_environment_variable.deploy,
    ]
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github.attribute_condition == "assertion.repository == 'fernandogator/mekasa'"
    error_message = "Only tokens from this repository may sign in."
  }

  assert {
    condition     = google_service_account_iam_member.github_deploys_as_deployer.member == "principal://iam.googleapis.com/projects/123/locations/global/workloadIdentityPools/github/subject/repo:fernandogator/mekasa:environment:mekasa-prod"
    error_message = "Only jobs in the mekasa-prod environment may act as the deployer."
  }

  assert {
    condition     = github_actions_environment_variable.deploy["GCP_DEPLOY_SERVICE_ACCOUNT"].value == "mekasa-deployer@hackathon2025-472017.iam.gserviceaccount.com" && github_actions_environment_variable.deploy["GCP_DEPLOY_SERVICE_ACCOUNT"].environment == "mekasa-prod"
    error_message = "CI must be told to deploy as mekasa-deployer in mekasa-prod."
  }

  assert {
    condition     = github_actions_environment_variable.deploy["GCP_WORKLOAD_IDENTITY_PROVIDER"].value == "projects/123/locations/global/workloadIdentityPools/github/providers/mekasa"
    error_message = "CI must be given the provider's full name."
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
