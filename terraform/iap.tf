# Identity-Aware Proxy (IAP) configuration for TAMS services

data "google_project" "project" {
  project_id = var.project_id
}

# IAP OAuth Client for services
resource "google_iap_client" "tams_iap_client" {
  display_name = "TAMS IAP Client"
  brand        = "projects/${data.google_project.project.number}/brands/${data.google_project.project.number}"

  depends_on = [google_project_service.iap]
}

# Backend service for IAP
resource "google_compute_backend_service" "iap_backend" {
  name        = "tams-iap-backend"
  project     = var.project_id
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30

  iap {
    oauth2_client_id     = google_iap_client.tams_iap_client.client_id
    oauth2_client_secret = google_iap_client.tams_iap_client.secret
  }

  depends_on = [google_project_service.compute]
}

# IAM bindings for authorized users
resource "google_iap_web_iam_binding" "iap_users" {
  count = length(var.iap_users) > 0 ? 1 : 0

  project = var.project_id
  role    = "roles/iap.httpsResourceAccessor"
  members = var.iap_users
}
