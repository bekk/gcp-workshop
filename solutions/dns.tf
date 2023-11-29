data "google_dns_managed_zone" "cloudlabs_gcp_no" {
  name = "cloudlabs-gcp-no-dns"
}

// For debugging
output "cloudlabs_gcp_no_dns" {
  value = data.google_dns_managed_zone.cloudlabs_gcp_no.dns_name
}

resource "google_dns_record_set" "frontend" {
  provider     = google
  name         = "${local.id}.${data.google_dns_managed_zone.cloudlabs_gcp_no.dns_name}"
  type         = "A"
  ttl          = 60
  managed_zone = data.google_dns_managed_zone.cloudlabs_gcp_no.name
  rrdatas      = [google_compute_global_address.cdn_public_address.address]
}
