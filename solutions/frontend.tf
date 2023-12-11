locals {
  frontend_dir   = "${path.module}/../frontend_dist"
  frontend_files = fileset(local.frontend_dir, "**")

  mime_types = {
    ".js"   = "application/javascript"
    ".html" = "text/html"
  }
}


resource "google_storage_bucket" "frontend" {
  name     = "storage-bucket-${local.id}"
  location = "EUROPE-WEST1"
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

#resource "google_storage_default_object_access_control" "website_read" {
#  bucket = google_storage_bucket.frontend.id
#  role   = "READER"
#  entity = "allUsers"
#}

resource "google_storage_bucket_object" "frontend" {
  for_each = local.frontend_files
  bucket = google_storage_bucket.frontend.name
  source = "${local.frontend_dir}/${each.value}"
  content_type = lookup(local.mime_types, regex("\\.[^.]+$", each.value), null)
  name = each.value
  detect_md5hash = filemd5("${local.frontend_dir}/${each.value}")
  depends_on = [ google_storage_bucket.frontend ]
}
