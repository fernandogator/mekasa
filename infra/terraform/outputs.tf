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
