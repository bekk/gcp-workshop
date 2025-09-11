terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.26.0"
    }
  }
}


variable "location" {
  description = "The location for the underlying storage bucket"
  type        = string
  default     = "EUROPE-WEST1"
}

variable "website_id" {
  description = "Unique identifier for the website"
  type        = string
}

variable "website_files_dir" {
  description = "Path to the directory containing frontend files"
  type        = string
}

variable "enable_cdn" {
  description = "Whether to enable CDN"
  type        = bool
  default     = false
}

variable "enable_https" {
  description = "Whether to enable HTTPS for the CDN"
  type        = bool
  default     = false

  validation {
    condition     = var.enable_https == false || (var.enable_https == true && var.enable_cdn == true)
    error_message = "enable_cdn must be true if enable_https is true"
  }
}

variable "domain_name" {
  description = "The domain name to use for the website (e.g., example.com)"
  type        = string
  default     = ""

  validation {
    condition     = var.enable_https == false || (var.enable_https == true && length(var.domain_name) > 0)
    error_message = "domain_name must be provided if enable_https is true"
  }
}

locals {
  mime_types = {
    ".js"   = "application/javascript"
    ".html" = "text/html"
  }
  frontend_file_names = fileset(var.website_files_dir, "**")
  frontend_file_paths = toset([for file_name in local.frontend_file_names : "${var.website_files_dir}/${file_name}"])

}

resource "google_storage_bucket" "frontend" {
  name     = var.website_id
  location = var.location
  website {
    main_page_suffix = "index.html"
  }
  force_destroy = true
}

resource "google_storage_bucket_iam_member" "frontend_read" {
  bucket = google_storage_bucket.frontend.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}


resource "google_storage_bucket_object" "frontend" {
  for_each = local.frontend_file_paths
  bucket = google_storage_bucket.frontend.name
  source = each.value
  content_type = lookup(local.mime_types, regex("\\.[^.]+$", each.value), null)
  name = element(split("/", each.value), -1)
  detect_md5hash = filemd5(each.value)
}

// CDN
resource "google_compute_backend_bucket" "cdn_bucket" {
  count       = var.enable_cdn ? 1 : 0
  name        = "cdn-${var.website_id}"
  description = "Backend bucket for serving static content through CDN"
  bucket_name = google_storage_bucket.frontend.name
  enable_cdn  = true
}

# Reserve an external IP
resource "google_compute_global_address" "cdn_public_address" {
  count       = var.enable_cdn ? 1 : 0
name     = "cdn-${var.website_id}-ip"
}

output "public_ip" {
  description = "The public IP address of the CDN (if enabled)"
  value = var.enable_cdn ? google_compute_global_address.cdn_public_address[0].address : null
}


resource "google_compute_url_map" "lb" {
  count       = var.enable_cdn ? 1 : 0
name            = "cdn-${var.website_id}-url-map"
  default_service = google_compute_backend_bucket.cdn_bucket[0].self_link
}

resource "google_compute_target_http_proxy" "frontend" {
  count       = var.enable_cdn ? 1 : 0
  name    = "http-proxy-${var.website_id}"
  url_map = google_compute_url_map.lb[0].id
}

resource "google_compute_global_forwarding_rule" "frontend" {
  count       = var.enable_cdn ? 1 : 0
  name       = "frontend-forwarding-rule-${var.website_id}"
  target     = google_compute_target_http_proxy.frontend[0].id
  port_range = "80"
  load_balancing_scheme = "EXTERNAL"
  ip_address = google_compute_global_address.cdn_public_address[0].address
}

output "bucket_name" {
  value = google_storage_bucket.frontend.name
}

# Create HTTPS certificate
resource "google_compute_managed_ssl_certificate" "frontend" {
  count = var.enable_https ? 1 : 0
  name     = "frontend-certificate-${var.website_id}"
  managed {
    domains = [var.domain_name]
  }
}

# GCP target proxy
resource "google_compute_target_https_proxy" "frontend" {
  count = var.enable_https ? 1 : 0
  name             = "frontend-target-proxy-https-${var.website_id}"
  url_map          = google_compute_url_map.lb[0].self_link
  ssl_certificates = [google_compute_managed_ssl_certificate.frontend[0].self_link]
}

# GCP forwarding rule
resource "google_compute_global_forwarding_rule" "frontend_https" {
  count = var.enable_https ? 1 : 0
  name                  = "frontend-forwarding-rule-https-${var.website_id}"
  load_balancing_scheme = "EXTERNAL"
  ip_address            = google_compute_global_address.cdn_public_address[0].address
  ip_protocol           = "TCP"
  port_range            = "443"
  target                = google_compute_target_https_proxy.frontend[0].self_link
}


