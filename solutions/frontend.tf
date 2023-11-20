locals {
  frontend_dir   = "${path.module}/../frontend_dist"
  frontend_files = fileset(local.frontend_dir, "**")

  mime_types = {
    ".js"   = "application/javascript"
    ".html" = "text/html"
  }
}


resource "google_storage_bucket" "frontend" {
  name     = "storage-bucket${local.id}"
  location = "EU"
  website {
    main_page_suffix = "index.html"
  }
  force_destroy = true
}

// http er ikke satt opp ennå, trengs ikke du får owner uansett
resource "google_storage_bucket_iam_member" "member" {
  bucket = google_storage_bucket.frontend.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# // dette er så alle kan se objektene i bucketen
# resource "google_storage_default_object_access_control" "website_read" {
#   bucket = google_storage_bucket.frontend.id
#   role   = "READER"
#   entity = "allUsers"
# }

resource "google_storage_bucket_object" "frontend" {
  for_each = local.frontend_files
  bucket = google_storage_bucket.frontend.name
  source = "${local.frontend_dir}/${each.value}"
  content_type = lookup(local.mime_types, regex("\\.[^.]+$", each.value), null)
  name = each.value
  detect_md5hash = filemd5("${local.frontend_dir}/${each.value}")
  depends_on = [ google_storage_bucket.frontend ]
}

# # Reserve an external IP
resource "google_compute_global_address" "cdn_public_address" {
  name     = "cdn-public-address${local.id}"
}

# # Add the IP to the DNS
resource "google_dns_record_set" "website" {
  provider     = google
  name         = "i${local.id}.${data.google_dns_managed_zone.cloudlabs_gcp_no.dns_name}"
  type         = "A"
  ttl          = 60
  managed_zone = data.google_dns_managed_zone.cloudlabs_gcp_no.name
  rrdatas      = [google_compute_global_address.cdn_public_address.address]
}

# propagering av DNS kan være treig bruk dig :D 