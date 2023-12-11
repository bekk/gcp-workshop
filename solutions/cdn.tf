resource "google_compute_backend_bucket" "cdn_bucket" {
  name        = "cdn-bucket-${local.id}"
  description = "Backend bucket for serving static content through CDN"
  bucket_name = google_storage_bucket.frontend.name
  enable_cdn  = true
}

# Reserve an external IP
resource "google_compute_global_address" "cdn_public_address" {
  name     = "cdn-public-address-${local.id}"
}

output "cdn_public_ip" {
  value = google_compute_global_address.cdn_public_address.address
}

resource "google_compute_url_map" "lb" {
  name            = "cdn-url-map-${local.id}"
  default_service = google_compute_backend_bucket.cdn_bucket.self_link

  # Modifications to LB are from extra tasks
  host_rule {
    hosts = [ local.frontend_subdomain ]
    path_matcher = "allpaths-frontend"
  }

  path_matcher {
    name = "allpaths-frontend"
    default_service = google_compute_backend_bucket.cdn_bucket.self_link
  }

  host_rule {
    hosts = [ local.backend_subdomain ]
    path_matcher = "allpaths-backend"
  }

  path_matcher {
    name = "allpaths-backend"
    default_service = google_compute_backend_service.backend.self_link
  }

  test {
    host = local.backend_subdomain
    service = google_compute_backend_service.backend.self_link
    path = "/todos"
  }
}

resource "google_compute_target_http_proxy" "frontend" {
  name    = "http-proxy-${local.id}"
  url_map = google_compute_url_map.lb.id
}

resource "google_compute_global_forwarding_rule" "frontend" {
  name       = "frontend-forwarding-rule-${local.id}"
  target     = google_compute_target_http_proxy.frontend.id
  port_range = "80"
  load_balancing_scheme = "EXTERNAL"
  ip_address = google_compute_global_address.cdn_public_address.address
}

