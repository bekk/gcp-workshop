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

