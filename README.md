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

We will use the `gcloud` CLI tool to log in:

1. Run `gcloud init` from the command line.

    1. If you've previously logged in with the CLI, select the same email you used in the browser, or "Create a new configuration" if you have another account already setup in `gcloud` CLI. (You can delete this account from the `gcloud` configuration after(!) the workshop using the `gcloud auth revoke` command.)

2. Select the correct account in the browser, and authorize access to "Google Cloud SDK" when prompted.

3. In the terminal, select the project with ID `cloud-labs-workshop-42clws`.

4. Check that the new account is set as active, by running `gcloud auth list`.

    1. If you have a previously used configuration set as active, run `gcloud config set account <account>`.

5. Run `gcloud auth application-default login` and complete the steps in the browser to create a credentials file that can be used by the `google` Terraform provider. **Note:** Remember to check the boxes to give "Google Auth Library" access to your account.

## Terraform

Start by cloning this repository if you haven't already done so, either using your preferred way using a GUI or any of the commands below:

* Using the [GitHub CLI](https://cli.github.com): `gh repo clone bekk/gcp-workshop`
* Using SSH keys: `git clone git@github.com:bekk/gcp-workshop`
* Using HTTPS: `git clone https://github.com/bekk/gcp-workshop`

This repository has a couple a folders:

* `frontend_dist/` contains some pre-built frontend files that we'll upload.
* `infra/` will contain our terraform code.
* If you're stuck you can peek in the `solutions` folder.

The `infra/` folder should only contain the `terraform.tf`. All files should be created in this folder, and all terraform commands assume you're in this folder, unless something else is explicitly specified.

> [!TIP]
> Resources can be declared in any file inside a module (directory). For small projects, everything can declared in a single file (conventionally named `main.tf`). There are some [file naming conventions in the terraform style guide](https://developer.hashicorp.com/terraform/language/style#file-names).

> [!NOTE]
> `terraform.tf` contains *provider* configuration. A provider is a plugin or library used by the terraform core to provide functionality. The `google` provider we will use in this workshop provides the definition of Google Cloud Platform (GCP) resources and translates resource blocks to correct API requests when you apply your configuration.

Let's move on to running some actual commands 🚀

1. Before you can provision infrastructure, you have to initialize the providers from `terraform.tf`. You can do this by running `terraform init` (from the `infra/` folder!).

    This command will not do any infrastructure changes, but will create a `.terraform/` folder, a `.terraform.lock.hcl` lock file. The lock file can (and should) be committed. :warning: The `.terraform/` folder should not be committed, because it can contain secrets.

2. Create a `main.tf` file (in `infra/`) and add the following code, replacing `<yourid42>` with a random string containing only lowercase letters and numbers, no longer than 8 characters. The `id` is used to create unique resource names and subdomains, so ideally at least 6 characters should be used to avoid collisions.

    ```terraform
    locals {
      id = "<yourid42>"
    }
    ```

> [!NOTE]
> The `locals` block defines a local variable. You can reference a variable by prefixing it with `local`, e.g. `local.id`. Local variables, like other blocks, can be defined and used anywhere in a terraform module, meaning `local.id` can be referenced in other files you create in the same directory.

3. Take a look at at `terraform.tf`.

    * The `terraform` block is used to declare providers and their versions. In this case, we use the `hashicorp/google`, the default provider for Google Cloud Platform.
    * The `provider` block defines the project, region and zone we'll work in. You should not need to touch this. A *project* is a billing unit, used to isolate environments and apps. *Regions* and *zones* decided where our resources will be located by default (see [the docs](https://cloud.google.com/compute/docs/regions-zones/) for more information).
    * A [`google_client_openid_userinfo`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_openid_userinfo) data block, giving us read access to the client used to invoke Terraform, and a corresponding output block which outputs the email of the client.
    * A `check` block to validate the id set in the previous step. Checks are a [part of the Terraform language](https://developer.hashicorp.com/terraform/tutorials/configuration-language/checks) to validate infrastructure, and will output warnings if the `assert` fail.

4. Run `terraform apply`. Confirm that you don't get a warning from the `check`, and take a look at the `current_user_email` output.

## Database

We'll create a PostgreSQL database for our application. Cloud SQL can be used for MySQL, SQL Server, PostgreSQL and more. It is fully managed and based on open standards, providing well-known interfaces.

> [!CAUTION]
> In this workshop we'll simplify the setup by allowing traffic from the public internet. This is not recommended for production use cases.


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

    * `deletion_policy` is set to `ABANDON`. This is useful for Cloud SQL Postgres, where databases cannot be deleted from the API if there are users other than the default `postgres` user with access.
    * The `tier` property decides the pricing tier.
    * `db-f1-micro` is the cheapest option, giving the database 0.6 GB of RAM and shared CPU.
    * The `ip_configuration` allows access from any IP-address on the public internet. (Mind the caution above!)
    * The `deletion_protection` property is set to false, to allow us to delete the database instance through Terraform later on. This is a safety mechanism in Terraform only, it is still possible to delete the database in the cloud console.


3. We need to create a root user for our database. We'll start creating a password. Add the [Random provider](https://registry.terraform.io/providers/hashicorp/random/latest/docs) to the `required_providers` block in `terraform.tf`, followed by `terraform init` to initialize the provider.

    ```terraform
    random = {
      source = "hashicorp/random"
      version = "3.6.3"
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

> [!TIP]
> Running `terraform apply` implicitly both plans and applies the configuration. You can save the plan, and apply it in separate steps if you want to. E.g., `tf plan -out=plan.tfplan` followed by `tf apply plan.tfplan`.


## Terraform plans and state file

`terraform apply` created a *state file*, `terraform.tfstate` in the `infra/` directory. This file contains terraform's view of the state. Resources you've declared will show up here.

1. Take a look at the state file. Look for the different resources you've created so far: a database, a password and a user for the database. Note how the password is in plain text in the state file.

> [!CAUTION]
> Terraform state files are generally considered very sensitive and should have strict access controls to avoid leaking privileged information.

> [!TIP]
> The terraform state file can be different from both the *desired state* (what's declared in the code) and the *actual state* (the resources that's actually there). The desired state is different from the terraform state before you apply your changes. The terraform state is different from the *actual state* when some configuration change has been done manually (i.e., modifying or deleting a resource).


## Backend

The backend is a pre-built Docker image uploaded in the GCP Artifact Registry. We'll run it using Google Cloud Run which pulls the image and runs it as a container.

Cloud Run is a fully managed platform for containerized applications. It allows you to run your frontend and backend services, batch jobs, and queue processing workloads. Cloud Run aims to provide the flexibility of containers with the simplicity of serverless. You can use buildpacks to enable you to deploy directly from source code, or you can upload an image. Cloud Run supports pull images from the Docker image Registry and GCP Artifact Registry.

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
            value = "postgresql://${google_sql_user.root.name}:${random_password.root_password.result}@${google_sql_database_instance.postgres.public_ip_address}:5432/${google_sql_database_instance.postgres.name}"
          }
        }
      }

      # Allow deleting using terraform destroy
      deletion_protection = false
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

We will use Google Cloud Storage to store the web site. A cloud storage bucket can store any type of data object, similarly to AWS S3 and Azure Blob Storage. An object can be a text file (HTML, javascript, txt), an image, a video or any other file, and can also be used to host static websites. We will instruct Terraform to upload the files in the `frontend_dist/` folder.

In order to serve the website content on a custom domain, we will also need a CDN with a load balancer. The CDN will use a storage bucket as the origin server for sourcing our content.

The setup can be quite complex, so a module has been created for this workshop. Terraform modules are abstractions that can contain multiple resources, input variables, output values, and even other modules. They help organize and reuse code. You can read more about modules in the [Terraform module documentation](https://developer.hashicorp.com/terraform/language/modules).

1. We will use the module in the `modules/gcs_static_website` folder. Add the following to `frontend.tf`:

    ```terraform
    module "website" {
      // This is a relative path to the module
      source            = "../modules/gcs_static_website"
      website_id        = "website-${local.id}"
      website_files_dir = "${path.module}/../frontend_dist"
    }
    ```

2. Run `terraform apply` and inspect the plan. This module invocation creates a Google Storage bucket, with an IAM policy and upload the objects.

3. After applying the play, go to the GCP console. Find "Cloud Storage", and your bucket.

    If you navigate to `index.html` file in the bucket, we should see the contents of the file has a "Public URL" that you can copy in order to navigate to the website. The URL should be similar to `https://storage.googleapis.com/website-<yourid42>/index.html`. The site might show an error, but everything is right if you're able to navigate to the site.

## CDN

We want a custom domain for our CDN. Luckily the `gcs_static_website` module handles this too.


1. Add `enable_cdn = true` to the module invocation in `frontend.tf`, and run `terraform apply`.

2. The module will expose a public IP. Create an `output` block to print the IP address:

    ```terraform
    output "website_public_ip" {
      value = module.website.public_ip
    }
    ```

    Apply the changes, and verify that the IP output is displayed after running Terraform.

    Outputs let's you easily expose useful information from a module, or display it after running `terraform apply`. You can also find the IP in the GCP console, by navigating to "Network services" > "Load balancing".


3. Try navigating to the IP address in your browser. You should see the frontend website - it will likely display a different error, but it still loads.


## DNS

We want a custom domain for our frontend CDN instead of using the IP address. We will use `cloudlabs-gcp.no` domain for this workshop. It is already configured in a manged DNS zone. You can find it by searching for "Cloud DNS" in the GCP console.

We will create a DNS A record to use `<yourid42>.cloudlabs-gcp.no`  the frontend CDN.

1. To define subdomains, we'll need a reference to the managed DNS zone in our Terraform configuration.

    We will use the Terraform `data` block. A data block is very useful to refer to resources created externally, including resources created by other teams or common platform resources in an organization (such as a DNS zone or a Kubernetes VPC network). Most resources have a corresponding data block.

    Create `dns.tf` and add the following data block:

    ```terraform
    data "google_dns_managed_zone" "cloudlabs_gcp_no" {
      name = "cloudlabs-gcp-no-dns"
    }
    ```


2. Add the IP to the DNS zone:

    ```terraform
    locals {
      frontend_domain = "${local.id}.${data.google_dns_managed_zone.cloudlabs_gcp_no.dns_name}"
    }

    resource "google_dns_record_set" "frontend" {
      name         = local.frontend_domain
      type         = "A"
      ttl          = 60
      managed_zone = data.google_dns_managed_zone.cloudlabs_gcp_no.name
      rrdatas      = [module.website.public_ip]
    }
    ```

    Provision the record and verify that the DNS record is created in the GCP console.

3. Go to the newly created address `http://<your-id>.cloudlabs-gcp.no`. The propagation of the address can take some time. Try using `dig @8.8.8.8 <your-id>.cloudlabs-gcp.no` to see if the address is ready. Look for `;; ANSWER SECTION:`, and find a line that looks like `<your-id>.cloudlabs-gcp.no.  60 IN      A       34.160.83.207`. If you can't find the answer section, the DNS record might not be propagate yet (should not take more than a couple of minutes), or an error happened.

## Extras

### Cleaning up

`terraform destroy` will delete all resources created by Terraform. When you're done with the workshop, please delete all resources created by Terraform by running `terraform destroy`. This will read the state file, and delete all resources listed in it. You will be prompted to confirm the action. You do not need to delete the resources yet, but please remember to do so after the workshop.

### Frontend HTTPS

To enable HTTPS for the CDN we need to create a certificate. The `gcs_static_website` module handles this for us. If you're curious about how it's done, take a look at the files in `modules/gcs_static_website`.

1. Add `enable_https = true` to the module invocation in `frontend.tf`. Also set the input `domain_name` to the `frontend_domain` local variable we defined in `dns.tf`.

2. Run Terraform appy to start the _provisioning_ of the certificate. The underlying certificate resource is quite complex, and even comes with [a warning in the documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_managed_ssl_certificate).

    Provisioning a Google-managed certificate might take up to 60 minutes from the moment your DNS and load balancer configuration changes have propagated across the internet. If you have updated your DNS configuration recently, it can take a significant amount of time for the changes to fully propagate. Sometimes propagation takes up to 72 hours worldwide, although it typically takes up to a few hours.

3. Go to the "Load balancing" section in the GCP console and find the frontend load balancer with your unique id. The load balancer should have both HTTP and HTTPS enabled.

### Backend custom domain name and HTTPS

To get a custom domain for the GCR instance, the [recommended way](https://cloud.google.com/run/docs/mapping-custom-domains) is to use a global external Application Load Balancer, setting up a regional network endpoint group a backend service, IP address and DNS records. This is quite a lot, so we will use a module to do the heavy lifting for us.

The [Terraform registry](https://registry.terraform.io/) not only contains providers, but also modules that wraps functionality into easy-to-use abstractions.

> [!CAUTION]
> Both modules and providers can be provided by third-parties. Make sure to only use modules provided by trusted vendors. Google provides it's own modules, that sets up services the right way, and without malware.

1. We will use the `lb-http` module from Google. Use the registry search to find it.

2. You'll need to create a [`google_compute_region_network_endpoint_group`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_network_endpoint_group) that contains the Google Cloud Run service previously created. Use the example in the Terraform documenation to create the network endpoint group. Apply and verify that it's created.

3. Create a new public IP using the [`google_compute_global_address` resource](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address). (Again, use the examples to figure out how to provision it.)

4. Create a new DNS A record, pointing to the new backend IP. Verify, like before, that the DNS record is provisioned correctly.

5. The `lb-http` module is quite complex, so the configuration here is given modify the configuration to reference resources you've previously created(IP address, network endpoint, DNS record). Also note that provisioning a managed SSL cert might take up to 24 hours.

    ```terraform
    module "lb-http" {
      source  = "GoogleCloudPlatform/lb-http/google"
      version = "13.1.0"

      name               = "http-lb-${local.id}-backend"
      project            = data.google_project.current.project_id
      address            = <your public IP address>
      create_address     = false
      ssl = true
      managed_ssl_certificate_domains = [<A record name>]
      https_redirect = true

      backends = {
        default = {
          description             = null
          groups                  = [
            {
              # Hint: This is a reference to the id attribute of the NEG resource
              group = <your network endpoint group>.id
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
    ```
