module "website" {
  source            = "../modules/gcs_static_website"
  website_id        = "storage-bucket-${local.id}"
  website_files_dir = "${path.module}/../frontend_dist"
  enable_cdn        = true
  enable_https      = true
  domain_name       = local.frontend_domain
}

output "website_public_ip" {
  value = module.website.public_ip
}

