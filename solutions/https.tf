# Create HTTPS certificate
resource "google_compute_managed_ssl_certificate" "frontend" {
  provider = google-beta
  name     = "website-certificate-${local.id}"
  managed {
    domains = [google_dns_record_set.frontend.name]
  }
}

# GCP target proxy
resource "google_compute_target_https_proxy" "frontend" {
  name             = "website-target-proxy-https-${local.id}"
  url_map          = google_compute_url_map.frontend_lb.self_link
  ssl_certificates = [google_compute_managed_ssl_certificate.frontend.self_link]
}

# GCP forwarding rule
resource "google_compute_global_forwarding_rule" "frontend_https" {
  name                  = "website-forwarding-rule-https-${local.id}"
  load_balancing_scheme = "EXTERNAL"
  ip_address            = google_compute_global_address.cdn_public_address.address
  ip_protocol           = "TCP"
  port_range            = "443"
  target                = google_compute_target_https_proxy.frontend.self_link
}
