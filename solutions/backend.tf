resource "google_cloud_run_v2_service" "backend" {
  name     = "cloudrun-service-${local.id}"
  location = "europe-west1"
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    scaling {
      max_instance_count = 1
    }

    containers {
      image = "europe-west1-docker.pkg.dev/cloud-labs-workshop-42clws/bekk-cloudlabs/backend:latest"
      ports {
        container_port = 3000
      }
      env {
        name = "DATABASE_URL"
        value = "postgresql://${google_sql_user.root.name}:${random_password.root_password.result}@${google_sql_database_instance.postgres.public_ip_address}:5432/${google_sql_database_instance.postgres.name}"
      }
    }
  }

  deletion_protection = false
}

data "google_iam_policy" "noauth" {
  binding {
    role    = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location    = google_cloud_run_v2_service.backend.location
  project     = google_cloud_run_v2_service.backend.project
  service     = google_cloud_run_v2_service.backend.name
  policy_data = data.google_iam_policy.noauth.policy_data
}

output "backend_url" {
  value = google_cloud_run_v2_service.backend.uri
}

resource "google_compute_region_network_endpoint_group" "backend" {
  name                  = "backend-${local.id}-neg"
  region                = "europe-west1"
  network_endpoint_type = "SERVERLESS"
  cloud_run {
    service = google_cloud_run_v2_service.backend.name
  }
}

module "lb-http" {
  source  = "GoogleCloudPlatform/lb-http/google"
  version = "13.1.0"

  name               = "http-lb-${local.id}-backend"
  project            = data.google_project.current.project_id
  address            = google_compute_global_address.backend_public_address.address
  create_address     = false
  ssl = true
  managed_ssl_certificate_domains = [google_dns_record_set.backend.name]
  https_redirect = true

  backends = {
    default = {
      description             = null
      groups                  = [
        {
          group = google_compute_region_network_endpoint_group.backend.id
        }
      ]
      enable_cdn              = false

      iap_config = {
        enable = false
      }
      log_config = {
        enable = false
      }
    }
  }

  firewall_networks = []
}

resource "google_compute_global_address" "backend_public_address" {
  name     = "backend-public-address-${local.id}"
}
