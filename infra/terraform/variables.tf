variable "project_id" {
  description = "GCP / Firebase project."
  type        = string
  default     = "hackathon2025-472017"
}

variable "region" {
  description = "Region of the Cloud Run API."
  type        = string
  default     = "us-central1"
}

variable "api_service" {
  description = "Cloud Run service the Hosting /v1/** rewrite points at."
  type        = string
  default     = "mekasa-api"
}

variable "web_app_id" {
  description = "Firebase web app ID (Project settings > Your apps). Kept in the untracked terraform.tfvars."
  type        = string

  validation {
    condition     = can(regex("^1:[0-9]+:web:[0-9a-f]+$", var.web_app_id))
    error_message = "Expected a Firebase web app ID like 1:<project number>:web:<hex>."
  }
}

variable "runtime_service_account" {
  description = "Cloud Run runtime identity the deployer deploys as (managed by deploy-cloud-run.sh)."
  type        = string
  default     = "mekasa-api@hackathon2025-472017.iam.gserviceaccount.com"
}

variable "deploy_environment" {
  description = "GitHub environment whose jobs may act as the deployer."
  type        = string
  default     = "mekasa-prod"
}

variable "hosting_site_id" {
  description = "Hosting site that serves the web app at https://<site>.web.app. Must already exist and be linked to web_app_id."
  type        = string
  default     = "mekasa"
}

variable "auth_authorized_domains" {
  description = "Every domain Firebase Auth accepts sign-in from. Replaces the console list, so keep the defaults and add to them."
  type        = list(string)
  default = [
    "localhost",
    "hackathon2025-472017.firebaseapp.com",
    "hackathon2025-472017.web.app",
    "mekasa.web.app",
    "mekasa.firebaseapp.com",
  ]
}

variable "browser_api_key_id" {
  description = "UID of the 'Browser key (auto created by Firebase)'. Leave empty to leave the key unmanaged."
  type        = string
  default     = ""
}

variable "browser_key_referrers" {
  description = "Pages allowed to use the browser API key."
  type        = list(string)
  default = [
    "https://mekasa.web.app/*",
    "https://mekasa.firebaseapp.com/*",
    "http://localhost:5173/*",
  ]
}

variable "browser_key_apis" {
  description = "APIs the browser key may call: Auth sign-in and token refresh, plus what Analytics needs."
  type        = list(string)
  default = [
    "identitytoolkit.googleapis.com",
    "securetoken.googleapis.com",
    "firebaseinstallations.googleapis.com",
    "firebase.googleapis.com",
  ]
}

variable "places_key_secret" {
  description = "Secret Manager secret holding the Places/Geocoding server key. deploy-cloud-run.sh reads the same name (PLACES_KEY_SECRET)."
  type        = string
  default     = "mekasa-places-api-key"
}

variable "github_owner" {
  description = "GitHub user or organisation that owns the repository."
  type        = string
  default     = "fernandogator"
}

variable "github_repository" {
  description = "Repository whose Actions variables are set."
  type        = string
  default     = "mekasa"
}
