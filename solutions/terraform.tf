terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "6.24.0"
    }
    random = {
      source = "hashicorp/random"
      version = "3.6.3"
    }
  }
}

provider "google" {
  project     = "cloud-labs-workshop-42clws"
  region      = "europe-west1"
  zone        = "europe-west1-b"
}

data "google_client_openid_userinfo" "current" {}

output "current_user_email" {
  value = data.google_client_openid_userinfo.current.email
}

data "google_project" "current" {}

# This check will display a warning to the participants if they forget to set
# the id local variable in main.tf
check "id_is_set" {
  assert {
    error_message = "Id must be set in main.tf"
    condition     = length(local.id) > 0
  }
}

