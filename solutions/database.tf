resource "google_sql_database" "database" {
  name     = "db-todo-${local.id}"
  instance = google_sql_database_instance.postgres.name
  deletion_policy = "ABANDON"
}

resource "google_sql_database_instance" "postgres" {
  name             = "db-todo-${local.id}"
  region           = "europe-west1"
  database_version = "POSTGRES_14"
  settings {
    tier = "db-f1-micro"
    # Allow access for all IP addresses
    ip_configuration {
      authorized_networks {
        value = "0.0.0.0/0"
      }
    }
  }
  deletion_protection = "false"
}

resource "random_password" "root_password" {
  length  = 24
  special = false
}

resource "google_sql_user" "root" {
  name     = "root"
  instance = google_sql_database_instance.postgres.name
  password = random_password.root_password.result
  deletion_policy = "ABANDON" #Special case for PSQL https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_user
}
