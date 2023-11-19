# Google Cloud Platform workshop

An introductory workshop in GCP with Terraform

## Getting started

### Required tools

For this workshop you'll need:

* Git (terminal or GUI)
* [gcloud, from the Google Cloud SDK](https://cloud.google.com/sdk/docs/install-sdk)
* [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

* Your preferred terminal to run commands
* Your IDE of choice to edit Terraform files, e.g., VS Code with the Terraform plugin


On macOS, with `brew`, you can run `brew install google-cloud-sdk terraform`.

### Authenticating in the browser

<!-- TODO: Verify -->
You will receive access through a google account connected to your (work) email address.

1. Go to [console.cloud.google.com](https://console.cloud.google.com).

2. If you're not logged in:

    1. Log in with your (work) email address.

3. If you're logged in:

    1. Verify that your work account is selected in the top-right corner. If not, click "Add account" and log in.

4. When you're logged in and have selected the correct account, verify that you have the `cloud-labs-workshop-project` selected in the top navigation bar (left hand side).

5. You should now be good to go!

### Authenticating in the terminal

We will use the `gcloud` CLI tool to log in..

1. Run `gcloud init` from the command line.

    1. If you've previously logged in with the CLI, select the same email you used in the browser, or "Log in with a new account".

2. Select the correct account in the browser, and authorize access to "Google Cloud SDK" when prompted.

3. In the terminal, select the project with ID `cloud-labs-workshop-42clws`.

4. Check that the new account is set as active, by running `gcloud auth list`.

    1. If you have a previously used configuration set as active, run `gcloud config set account <account>`.

5. Run `gcloud auth application-default login` and complete the steps in the browser to create a credentials file that can be used by the `google` Terraform provider.

## Terraform

## Database
We'll create a PostgreSQL database for our application. Cloud SQL can be used for MySQL, SQL Server, PostgresSQL and more. It is fully managed and based on open standards, providing well-known interfaces. In this workshop we'll simplify the setup by allowing traffic from the public internet. This is generally not recommended, but is ok for this workshop.

1. Create a new file `database.tf` in the `infra/` directory.
2. Create the database and the database instance by adding the following code:

   ```terraform
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
          ip_configuration {
            authorized_networks {
                value = "0.0.0.0/0"
          }
        }
      }
      deletion_protection = "false"
      }
   ```
   `deletion_policy` is set to `ABANDON`. This is useful for Postgres, where databases cannot be deleted from the API if there are users other than cloudsqlsuperuser with access. The `tier` property is related to the speed at const of the database. `db-f1-micro` is the cheapest option, but is fine for this workshop. The `ip_configuration` allows access from any IP-address on the public Internet. This should not be done in production. The `deletion_protection` property is set to false, to allow us to delete the database instance through Terraform later on.


3. We need to create a root user for our database. We'll start creating a password. Add the [Random provider](https://registry.terraform.io/providers/hashicorp/random/latest/docs) to the `required_providers` block in `terraform.tf`, followed by `terraform init` to initialize the provider.

    ```terraform
    random = {
      source = "hashicorp/random"
      version = "3.5.1"
    }
    ```

   Now, we can create a `random_password` resource to generate our password. Add the following code to `database.tf`:

    ```terraform
    resource "random_password" "postgres_password" {
      length  = 24
      special = false
    }
    ```

   This will create a random, 24-character password, which by default will contain uppercase, lowercase and numbers. We can reference the password by using the `result` attribute: `random_password.sql_server_admin_password.result`. This password will be stored in the terraform state file, and will not be regenerated every time `terraform apply` is run.


4. Lastly we will create the actual user. Add the following code to `database.tf`:

    ```terraform
      resource "google_sql_user" "root" {
         name     = "root"
         instance = google_sql_database_instance.postgres.name
         password = random_password.root_password.result
         deletion_policy = "ABANDON" 
      }
    ```
   `deletion_policy` is set to `ABANDON`. This is useful for Postgres, where users cannot be deleted from the API if they have been granted SQL roles.


5. Run `terraform apply` to create the database and the database instance. This takes several minutes. Verify that the database is created in the GCP console.

## Backend
The backend is a pre-built Docker image uploaded in the GCP Artifact Registry. We'll run it using Cloud Run which pulls the image and runs it as a container.

GCP Cloud run is a fully managed platform for containerized applications. It allows you to run your frontend and backend services, batch jobs, and queue processing workloads. Cloud Run aims to provide the flexiblity of containers with the simplicity of serverless. Cloud Run can automate how you get to production. You can use buildpacks to enable you to deploy directly from source code, or you can upload an image. Cloud Run supports pull images from the Docker image Registry and GCP Artifact Registry. 

1. Create a new file, `backend.tf` (still in `infra/`)

2. We'll create a new resource of type `google_cloud_run_v2_service`, named `cloudrun-service-<yourid42>`.  Like this:
   ```terraform
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
            name  = "DATABASE_URL"
            value = "postgresql://${google_sql_user.root.name}:${random_string.root_password.result}@${google_sql_database_instance.postgres.public_ip_address}:5432/${google_sql_database_instance.postgres.name}"
          }
        }
      }
   }
   ```

3. Run `terraform apply`. By doing this the Cloud Run resource will be created and pull the image specified in the `image`. Cloud Run resources are autoscaling, by setting `max_instance_count` to 1 we limit the service to only have one instance running. 

4. Verify that the Cloud Run resource is created correctly in the GCP console.

5. By default, users are not allowed to run code on a Cloud Run services. To allow all users to run code, and access the endpoints in our backend, we will give all users the invoker role on our backend service. Add the following to `backend.tf`:

   ```terraform
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
   ```

6. Find the Cloud Run URL in the console, or by adding an `backend_url` `output` block printing `google_cloud_run_v2_service.backend.uri`. Navigate to `<url>/healtcheck` in your browser (or by using `curl` or equivalent) and verify that you get a message stating that the database connection is ok. The app is then running ok, and has correctly connected to the database.

## Frontend

## DNS

We will use `cloudlabs-gcp.no` for this workshop. It is already configured in a manged DNS zone. You can find it by searching for Cloud DNS in the GCP console. We will configure two records, `api.<yourid42>.cloudlabs-gcp.no` for the backend, and `<yourid42>.cloudlabs-gcp.no` for the frontend CDN. 

1. To define subdomains, we'll need a reference to the managed DNS zone in our Terraform configuration. We will use the Terraform `data` block. A dta block is very useful to refer to resources created externally, includinng resources created by other teams or common platform resources in an organization (such as a DNS zone). Most resources have a corresponding data block.

    Create `dns.tf` and add the following datablock:

    ```terraform
    data "google_dns_managed_zone" "cloudlabs_gcp_no" {
      name = "cloudlabs-gcp-no-dns"
    }
    ```

## Extras

