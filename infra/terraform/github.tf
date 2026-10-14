# Build-time inputs for web/ (UI-007 AC17). The Firebase web config is public
# client config, so these are Actions variables, not secrets; they are read
# from Firebase here so nothing is copied by hand or committed.

locals {
  github_variables = {
    FIREBASE_WEB_API_KEY             = data.google_firebase_web_app_config.web.api_key
    FIREBASE_WEB_AUTH_DOMAIN         = data.google_firebase_web_app_config.web.auth_domain
    FIREBASE_WEB_PROJECT_ID          = var.project_id
    FIREBASE_WEB_APP_ID              = var.web_app_id
    FIREBASE_WEB_MESSAGING_SENDER_ID = data.google_firebase_web_app_config.web.messaging_sender_id
    FIREBASE_WEB_MEASUREMENT_ID      = data.google_firebase_web_app_config.web.measurement_id
    # Receipt scans call Cloud Run directly to avoid Hosting's 60 s rewrite limit (UI-007 AC11).
    WEB_API_DIRECT_URL = data.google_cloud_run_v2_service.api.uri
  }
}

resource "github_actions_variable" "web" {
  for_each = local.github_variables

  repository    = var.github_repository
  variable_name = each.key
  value         = each.value
}
