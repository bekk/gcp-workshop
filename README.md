# Google Cloud Platform workshop

An introductory workshop in GCP with Terraform

## Getting started

### Required tools

For this workshop you'll need:

* Git (terminal or GUI)
* [gcloud, from the Google Cloud SDK](https://cloud.google.com/sdk/docs/install-sdk)
* [Terraform](https://developer.hashicorp.com/terraform/install)

* Your preferred terminal to run commands
* Your IDE of choice to edit Terraform files, e.g., VS Code with the Terraform plugin

On macOS, with `brew`, you can run `brew install google-cloud-sdk terraform`.

### Authenticating in the browser

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

This repository has two folders for this workshop: `frontend_dist/` contains some pre-built frontend files that we'll upload and `infra/` will contain our terraform code. All files should be created here, and all terraform commands assume you're in this folder, unless something else is explicitly specified.

The `infra/` folder, does not contain many files yet:

* `terraform.tf` contains *provider* configuration. A provider is a plugin or library used by the terraform core to provide functionality. The `aws` we will use in this workshop provides the definition of AWS resources and translates to correct API requests when you apply your configuration.

Let's move on to running some actual commands 🚀

1. Before you can provision infrastructure, you have to initialize the providers from `terraform.tf`. You can do this by running `terraform init` (from the `infra/` folder!).

    This command will not do any infrastructure changes, but will create a `.terraform/` folder, a `.terraform.lock.hcl` lock file. The lock file can (and should) be committed. :warning: The `.terraform/` folder should not be committed, because it can contain secrets.

2. Create a `main.tf` file (in `infra/`) and add the following code, replacing `<yourid42>` with a random string containing only lowercase letters and numbers, no longer than 8 characters. The `id` is used to create unique resource names and subdomains, so ideally at least 6 characters should be used to avoid collisions.

    ```terraform
    locals {
      id = "<yourid42>"
    }
    ```

3. Take a look at at `terraform.tf`.

    * The `terraform` block is used to declare providers and their versions. In this case, we use the `hashicorp/google`, the default provider for Google Cloud Platform.
    * The `provider` block defines the project, region and zone we'll work in. You should not need to touch this. A *project* is a billing unit, used to isolate environments and apps. *Regions* and *zones* decided where our resources will be located by default (see [the docs](https://cloud.google.com/compute/docs/regions-zones/) for more information).
    * A [`google_client_openid_userinfo`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_openid_userinfo) data block, giving us read access to the client used to invoke Terraform, and a corresponding output block which outputs the email of the client.
    * A `check` block to validate the id set in the previous step. Checks are a [part of the Terraform language](https://developer.hashicorp.com/terraform/tutorials/configuration-language/checks) to validate infrastructure, and will output warnings if the `assert` fail.

4. Run `terraform apply`. Confirm that you don't get a warning from the `check`, and take a look at the `current_user_email` output.

## Database

We'll create a PostgreSQL database for our application. Cloud SQL can be used for MySQL, SQL Server, PostgreSQL and more. It is fully managed and based on open standards, providing well-known interfaces. In this workshop we'll simplify the setup by allowing traffic from the public internet. This is generally not recommended, but is ok for this workshop.

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
          # Allow access for all IP addresses
          ip_configuration {
            authorized_networks {
                value = "0.0.0.0/0"
          }
        }
      }
      deletion_protection = "false"
    }
    ```

    `deletion_policy` is set to `ABANDON`. This is useful for Cloud SQL Postgres, where databases cannot be deleted from the API if there are users other than the default `postgres` user with access. The `tier` property decides the pricing tier. `db-f1-micro` is the cheapest option, giving the database 0.6 GB of RAM and shared CPU. The `ip_configuration` allows access from any IP-address on the public internet. This should not be done in production. The `deletion_protection` property is set to false, to allow us to delete the database instance through Terraform later on.


3. We need to create a root user for our database. We'll start creating a password. Add the [Random provider](https://registry.terraform.io/providers/hashicorp/random/latest/docs) to the `required_providers` block in `terraform.tf`, followed by `terraform init` to initialize the provider.

    ```terraform
    random = {
      source = "hashicorp/random"
      version = "3.5.1"
    }
    ```

    Now, we can create a `random_password` resource to generate our password. Add the following code to `database.tf`:

    ```terraform
    resource "random_password" "root_password" {
      length  = 24
      special = false
    }
    ```

    This will create a random, 24-character password, which by default will contain uppercase, lowercase and numbers. We can reference the password by using the `result` attribute: `random_password.root_password.result`. This password will be stored in the terraform state file, and will not be regenerated every time `terraform apply` is run.


4. Lastly we will create the actual user. Add the following code to `database.tf`:

    ```terraform
    resource "google_sql_user" "root" {
       name     = "root"
       instance = google_sql_database_instance.postgres.name
       password = random_password.root_password.result
       deletion_policy = "ABANDON"
    }
    ```

    `deletion_policy` is set to `ABANDON`. This is useful for Postgres Cloud SQL, where users cannot be deleted from the API if they have been granted SQL roles.


5. Run `terraform apply` to create the database and the database instance. This will take several minutes. While you wait, you can read the next task,  Verify that the database is created in the GCP console. The simplest way to find it, is to search for "SQL" or for `<yourid42>`.

## Backend

The backend is a pre-built Docker image uploaded in the GCP Artifact Registry. We'll run it using Cloud Run which pulls the image and runs it as a container.

GCP Cloud run is a fully managed platform for containerized applications. It allows you to run your frontend and backend services, batch jobs, and queue processing workloads. Cloud Run aims to provide the flexibility of containers with the simplicity of serverless. You can use buildpacks to enable you to deploy directly from source code, or you can upload an image. Cloud Run supports pull images from the Docker image Registry and GCP Artifact Registry.

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

5. By default, users are not allowed to run code on a Cloud Run services. To allow all users to run code, and access the endpoints in our backend, we will give all users the invoker role on our backend service. Add the following to `backend.tf` and run `terraform apply`:

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

6. Find the Cloud Run URL in the console, or by adding an `backend_url` output block printing `google_cloud_run_v2_service.backend.uri`. Navigate to `<url>/healthcheck` in your browser (or by using `curl` or equivalent) and verify that you get a message stating that the database connection is ok. The app is then running ok, and has successfully connected to the database.

## Frontend

We will use Google cloud storage service to store the web site. A cloud storage bucket can store any type of data object. An object can be a text file (HTML, javascript, txt), an image, a video or any other file, and can also be used to host static websites. We will also use terraform to upload the files in the `frontend_dist/` folder.

In order to serve the website content a custom domain, we will also need a CDN with a load balancer. The CDN will use a backend bucket with a storage bucket as the origin server for sourcing our content. The key part here is enabling CDN by setting the “enable_cdn=true” attribute on the backend bucket.

1. Create the bucket. Add this to a new file, `frontend.tf`

    ```terraform
    resource "google_storage_bucket" "frontend" {
      name     = "storage-bucket-${local.id}"
      location = "EU"
      website {
        main_page_suffix = "index.html"
      }
      force_destroy = true
    }
    ```

    The `force_destroy` property is set to `true` to allow us to delete the bucket later on. We also use the `website` block to enable the website feature on the bucket. This will allow us to serve the content in the bucket as a static website.

    If we now go to the GCP console and click in the menu for "Cloud Storage", we should see the bucket we just created.

2. To upload files to the bucket, Terraform must track the files in the `frontend_dist/` directory. We also need some MIME type information that is not readily available, so we will create a map that we can use to look up the types later. We will create local helper variables to help us out:

    ```terraform
    locals {
      frontend_dir   = "${path.module}/../frontend_dist"
      frontend_files = fileset(local.frontend_dir, "**")

      mime_types = {
        ".js"   = "application/javascript"
        ".html" = "text/html"
      }
    }
    ```

    `path.module` is the path to the `infra/` directory. `fileset(directory, pattern)` returns a list of all files in directory matching pattern.

3. Now we want to store all of these files as a object in our bucket. In order to create multiple resources, terraform provides a `for_each` meta-argument as a looping mechanism. We assign the `frontend_files` list to it, and can use `each.value` to refer to an element in the list.

    ```terraform
    resource "google_storage_bucket_object" "frontend" {
      for_each = local.frontend_files
      bucket = google_storage_bucket.frontend.name
      source = "${local.frontend_dir}/${each.value}"
      content_type = lookup(local.mime_types, regex("\\.[^.]+$", each.value), null)
      name = each.value
      detect_md5hash = filemd5("${local.frontend_dir}/${each.value}")
    }
    ```

    The code snippet performs a regex search to look up the correct content type. The `filemd5` calculates a hash of the file content, which is used to determined whether a file need to be re-uploaded. Without the hash, terraform would not be able to detect a file change (only new/deleted/renamed files).

    After we now run `terraform apply`, we should be able to see the cloud storage bucket with it's files in the GCP console.

    But we are not able to browse the website yet. We need to set up access to the bucket, in our case enable public access to the bucket. We'll create a new IAM policy for the bucket. There are three of these, you can read more about them [here](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam). We will use the `google_storage_bucket_iam_member`. Add the following to `frontend.tf`:

    ```terraform
    resource "google_storage_bucket_iam_member" "member" {
      bucket = google_storage_bucket.frontend.name
      role   = "roles/storage.objectViewer"
      member = "allUsers"
    }
    ```

    If you navigate to `index.html` file in the bucket, we should see the contents of the file has a "Public URL". And you should be able to navigate to the website. The URL should be similar to `https://storage.googleapis.com/storage-bucket-<yourid42>/index.html`.

## CDN

In order to get a custom domain up and running, we'll create a CDN with a load balancer in front. The load balancer will be assigned a public IP which we can point a DNS record towards.

1. Create a new file `cdn.tf` and add the CDN:

    ```terraform
    resource "google_compute_backend_bucket" "cdn_backend_bucket" {
      name        = "cdn-bucket-${local.id}"
      description = "Backend bucket for serving static content through CDN"
      bucket_name = google_storage_bucket.frontend.name
      enable_cdn  = true
    }
    ```

    The CDN acts as a load balancing backend service that serves content a cloud storage bucket. The key part here is enabling CDN by setting the `enable_cdn=true` attribute on the backend bucket. Provisioning the CDN doesn't do much, but find your CDN instance in the GCP console anyway.

1. Reserve an external IP for the load balancer in front of the CDN. Add the following to `cdn.tf`:

    ```terraform
    resource "google_compute_global_address" "cdn_public_address" {
      name     = "cdn-public-address-${local.id}"
    }
    ```

    You can find your IP by finding it in the GCP console, or adding an output:

    ```terraform
    output "cdn_public_ip" {
      value = google_compute_global_address.cdn_public_address.address
    }
    ```

2. Time to set up the load balancer:

    ```terraform
    resource "google_compute_url_map" "frontend_lb" {
      name            = "cdn-url-map-${local.id}"
      default_service = google_compute_backend_bucket.cdn_backend_bucket.self_link
    }

    resource "google_compute_target_http_proxy" "frontend" {
      name    = "http-proxy-${local.id}"
      url_map = google_compute_url_map.frontend_lb.id
    }

    resource "google_compute_global_forwarding_rule" "default" {
      name       = "website-forwarding-rule-${local.id}"
      target     = google_compute_target_http_proxy.frontend.id
      port_range = "80"
      load_balancing_scheme = "EXTERNAL"
      ip_address = google_compute_global_address.cdn_public_address.address
    }
    ```

    In our case, a HTTP(S) load balancer requires a backend service to serve requests. Cloud CDN requires a *global* load balancer, either a "global external application load balancer" or a premium tier "classic application load balancer" (see [the docs](https://cloud.google.com/load-balancing/docs/https#backend-service)). The `load_balancing_scheme` is set to `EXTERNAL`, giving us a classic application load balancer (changing to `EXTERNAL_MANAGED` will provision a global external application load balancer instead, see the [docs](https://cloud.google.com/load-balancing/docs/forwarding-rule-concepts#protocol-specifications)).

## DNS

We will use `cloudlabs-gcp.no` for this workshop. It is already configured in a manged DNS zone. You can find it by searching for Cloud DNS in the GCP console. We will configure two records, `api.<yourid42>.cloudlabs-gcp.no` for the backend, and `<yourid42>.cloudlabs-gcp.no` for the frontend CDN.

1. To define subdomains, we'll need a reference to the managed DNS zone in our Terraform configuration. We will use the Terraform `data` block. A dta block is very useful to refer to resources created externally, including resources created by other teams or common platform resources in an organization (such as a DNS zone). Most resources have a corresponding data block.

    Create `dns.tf` and add the following data block:

    ```terraform
    data "google_dns_managed_zone" "cloudlabs_gcp_no_dns" {
      name = "cloudlabs-gcp-no-dns"
    }
    ```


2. Add the IP to the DNS zone:

    ```terraform
    resource "google_dns_record_set" "website" {
      provider     = google
      name         = "${local.id}.${data.google_dns_managed_zone.cloudlabs_gcp_no_dns.dns_name}"
      type         = "A"
      ttl          = 60
      managed_zone = data.google_dns_managed_zone.cloudlabs_gcp_no_dns.name
      rrdatas      = [google_compute_global_address.cdn_public_address.address]
    }
    ```

    Verify that the CDN is created in the GCP console. And go to the newly created address `http://<your-id>-gcp.cloudlabs-gcp.no`. The propagation of the address can take some time. Try using `dig @8.8.8.8 <your-id>-gcp.cloudlabs-gcp.no` to see if the address is ready. Look for `;; ANSWER SECTION:`, and find a line that looks like `<your-id>-gcp.cloudlabs-gcp.no.  60 IN      A       34.160.83.207`. If you can't find the answer section, the DNS record might not be propagate yet (should not take more than a couple of minutes), or an error happened.

    <!-- TODO: Backend DNS, Backend HTTPS? -->

## Extras

### Frontend HTTPS

To enable HTTPS for the CDN we need to create a certificate. Managed SSL certificates are only available using the `google-beta` provider. Luckily, it's included by default in the `google` provider, so iwe'll just add another provider block and add `provider = google-beta` to our resource blocks, but [additional configuration](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_versions#using-the-google-beta-provider) is possible.

1. Add the `provider` block to `terraform.tf`:

    ```terraform
    provider "google-beta" {
      project     = "cloud-labs-workshop-42clws"
      region      = "europe-west1"
      zone        = "europe-west1-b"
    }
    ```

2. Make a new file called `https.tf` and add the following to create a certificate:

    ```terraform
    resource "google_compute_managed_ssl_certificate" "website" {
      provider = google-beta
      name     = "website-cert"
      managed {
        domains = [google_dns_record_set.website.name]
      }
    }
    ```

3. Now we need to add it to the https proxy.

    ```terraform
    resource "google_compute_target_https_proxy" "website" {
      provider         = google
      name             = "website-target-proxy"
      url_map          = google_compute_url_map.website.self_link
      ssl_certificates = [google_compute_managed_ssl_certificate.website.self_link]
    }
    ```

4. And then add it to the forwarding rule

    ```terraform
    resource "google_compute_global_forwarding_rule" "default" {
      provider              = google
      name                  = "website-forwarding-rule"
      load_balancing_scheme = "EXTERNAL"
      ip_address            = google_compute_global_address.website.address
      ip_protocol           = "TCP"
      port_range            = "443"
      target                = google_compute_target_https_proxy.website.self_link
    }
    ```

5. Run `terraform apply` and to start the _provisioning_ of the certificate. Provisioning a Google-managed certificate might take up to 60 minutes from the moment your DNS and load balancer configuration changes have propagated across the internet. If you have updated your DNS configuration recently, it can take a significant amount of time for the changes to fully propagate. Sometimes propagation takes up to 72 hours worldwide, although it typically takes a few hours. But if you go to the "Load balancing" and in to your load balancing in the GCP console you should see that HTTPS in the list of the frontend tab.
