data "google_dns_managed_zone" "cloudlabs_gcp_no" {
  name = "cloudlabs-gcp-no-dns"
}

// For debugging
output "cloudlabs_gcp_no_dns" {
  value = data.google_dns_managed_zone.cloudlabs_gcp_no.dns_name
}
