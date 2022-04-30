provider "google" {
  project = var.project
  region  = var.region
  zone    = "${var.region}-a"
}
terraform {
  cloud {
    organization = "nakamuloud"

    workspaces {
      name = "my-podcast-station"
    }
  }
}

//------------------------
// podcast rss endpoint
//------------------------

resource "google_storage_bucket" "rss_endpoint" {
  name          = var.bucket_name
  storage_class = "STANDARD"
  location      = upper(var.region)
}

resource "google_storage_bucket_object" "rss_endpoint" {
  name   = "podcast-rss-endpoint-template"
  source = "../rss.xml"
  bucket = var.bucket_name
  depends_on = [
    google_storage_bucket.rss_endpoint
  ]
}

resource "google_service_account" "rss_endpoint" {
  account_id   = "rss-endpoint"
  display_name = "SA for accessing rss endpoint via signed url"
}

resource "google_service_account_key" "rss_endpoint" {
  service_account_id = google_service_account.rss_endpoint.name
}

resource "google_project_iam_binding" "rss_endpoint" {
  project = var.project
  role    = "roles/storage.objectViewer"
  members = [
    "serviceAccount:${google_service_account.rss_endpoint.email}",
  ]
  condition {
    expression = <<-EOT
    resource.name == "projects/_/buckets/${google_storage_bucket.rss_endpoint.name}" ||
    resource.name.startsWith("projects/_/buckets/${google_storage_bucket.rss_endpoint.name}/objects/")
    EOT
    title      = "restricted access to rss endpoint"
  }
}

resource "local_sensitive_file" "rss_endpoint_key" {
  content  = base64decode("${google_service_account_key.rss_endpoint.private_key}")
  filename = "../credentials/rss_endpoint.json"
}

# data "google_storage_object_signed_url" "rss_endpoint" {
#   bucket       = google_storage_bucket.rss_endpoint.name
#   path         = google_storage_bucket_object.rss_endpoint.name
#   content_type = "text/plain"
#   credentials  = base64decode("${google_service_account_key.rss_endpoint.private_key}")

#   extension_headers = {
#     x-goog-if-generation-match = 1
#   }
# }

# output "signed_url" {
#   value = data.google_storage_object_signed_url.rss_endpoint.signed_url
# }
//------------------------
// podcast file stack
//------------------------

resource "google_storage_bucket" "rss_stack" {
  name          = "podcast-rss-stack"
  storage_class = "NEARLINE"
  location      = "ASIA-NORTHEAST1"
}

//------------------------
// cloud function
//------------------------
