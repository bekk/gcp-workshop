terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "5.5.0"
    }
    random = {
      source = "hashicorp/random"
      version = "3.5.1"
    }
  }
}

provider "google" {
  project     = "cloud-labs-workshop-42clws"
  region      = "europe-west1"
  zone        = "europe-west1-b"
}
