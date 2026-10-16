terraform {
  # 1.7+ for `for_each` on import blocks.
  required_version = ">= 1.7"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  # State bucket is passed at init time: see README.md.
  backend "gcs" {
    prefix = "mekasa/web"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  # Firebase and API Keys calls made with user credentials need a quota project.
  user_project_override = true
  billing_project       = var.project_id
}

provider "google-beta" {
  project = var.project_id
  region  = var.region

  # Firebase and API Keys calls made with user credentials need a quota project.
  user_project_override = true
  billing_project       = var.project_id
}

# Token comes from the GITHUB_TOKEN environment variable.
provider "github" {
  owner = var.github_owner
}
