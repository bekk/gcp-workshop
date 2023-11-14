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

## Backend

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

