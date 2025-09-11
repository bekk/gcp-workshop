data "google_dns_managed_zone" "cloudlabs_gcp_no" {
  name = "cloudlabs-gcp-no-dns"
}

// For debugging
output "cloudlabs_gcp_no_dns" {
  value = data.google_dns_managed_zone.cloudlabs_gcp_no.dns_name
}

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

resource "google_dns_record_set" "backend" {
  name         = "api.${local.id}.${data.google_dns_managed_zone.cloudlabs_gcp_no.dns_name}"
  type         = "A"
  ttl          = 60
  managed_zone = data.google_dns_managed_zone.cloudlabs_gcp_no.name
  rrdatas      = [google_compute_global_address.backend_public_address.address]
}

locals {
  backend_subdomain = trimsuffix(google_dns_record_set.backend.name, ".")
}
