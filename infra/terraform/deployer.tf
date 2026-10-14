# Keyless CI deploys (docs/gcp-firebase-setup.md §4b).
#
# GitHub Actions jobs in the deploy environment sign in through Workload
# Identity Federation and act as mekasa-deployer, so no service account key is
# stored anywhere. Jobs outside that environment (for example on pull request
# branches) cannot act as the deployer.

locals {
  deployer_roles = [
    # gcloud run deploy --source (DEPLOY_ONLY=1 in deploy-cloud-run.sh)
    "roles/run.sourceDeveloper",
    "roles/secretmanager.viewer",
    "roles/serviceusage.serviceUsageConsumer",
    # firebase deploy --only hosting with the Cloud Run rewrite (ADR-010)
    "roles/firebasehosting.admin",
    "roles/run.viewer",
  ]

  github_repository = "${var.github_owner}/${var.github_repository}"
}

resource "google_service_account" "deployer" {
  account_id   = "mekasa-deployer"
  display_name = "Mekasa CI deployer"
  description  = "Deploys mekasa-api and the web app from GitHub Actions through Workload Identity Federation."
}

resource "google_project_iam_member" "deployer" {
  for_each = toset(local.deployer_roles)

  project = var.project_id
  role    = each.value
  member  = google_service_account.deployer.member
}

# Cloud Run deploys set the runtime identity, which requires actAs on it.
resource "google_service_account_iam_member" "deployer_acts_as_runtime" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.runtime_service_account}"
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.deployer.member
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"

  depends_on = [google_project_service.web]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "mekasa"
  display_name                       = "fernandogator/mekasa"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }
  attribute_condition = "assertion.repository == '${local.github_repository}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# GitHub sets the token subject to repo:<owner>/<repo>:environment:<name> for
# jobs that run in an environment (default subject template).
resource "google_service_account_iam_member" "github_deploys_as_deployer" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/subject/repo:${local.github_repository}:environment:${var.deploy_environment}"
}

resource "github_actions_environment_variable" "deploy" {
  for_each = {
    GCP_WORKLOAD_IDENTITY_PROVIDER = google_iam_workload_identity_pool_provider.github.name
    GCP_DEPLOY_SERVICE_ACCOUNT     = google_service_account.deployer.email
  }

  repository    = var.github_repository
  environment   = var.deploy_environment
  variable_name = each.key
  value         = each.value
}
