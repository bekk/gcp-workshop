# Add the bucket as a CDN backend
resource "google_compute_backend_bucket" "cdn_backend_bucket" {
  provider    = google
  name        = "cdn-bucket${local.id}"
  description = "Backend bucket for serving static content through CDN"
  bucket_name = google_storage_bucket.frontend.name
  enable_cdn  = true
}

# GCP URL MAP
resource "google_compute_url_map" "cdn_url_map" {
  provider        = google
  name            = "cdn-url-map${local.id}"
  default_service = google_compute_backend_bucket.cdn_backend_bucket.self_link
}

resource "google_compute_target_http_proxy" "default" {
  name    = "http-proxy${local.id}"
  url_map = google_compute_url_map.cdn_url_map.id
}

resource "google_compute_global_forwarding_rule" "default" {
  name       = "website-forwarding-rule${local.id}"
  target     = google_compute_target_http_proxy.default.id
  port_range = "80"
  load_balancing_scheme = "EXTERNAL"
  ip_address = google_compute_global_address.cdn_public_address.address
}

