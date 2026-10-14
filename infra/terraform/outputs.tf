output "hosting_urls" {
  description = "Default addresses of the web app."
  value = [
    "https://${google_firebase_hosting_site.default["default"].site_id}.web.app",
    "https://${google_firebase_hosting_site.default["default"].site_id}.firebaseapp.com",
  ]
}

output "api_direct_url" {
  description = "Cloud Run URL used for receipt scans."
  value       = data.google_cloud_run_v2_service.api.uri
}

output "github_variables" {
  description = "Actions variables written to the repository."
  value       = sort(keys(github_actions_variable.web))
}

output "deployer_service_account" {
  description = "Account CI deploys as."
  value       = google_service_account.deployer.email
}

output "workload_identity_provider" {
  description = "Value of the GCP_WORKLOAD_IDENTITY_PROVIDER variable."
  value       = google_iam_workload_identity_pool_provider.github.name
}
