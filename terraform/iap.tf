# Identity-Aware Proxy (IAP) configuration for TAMS services

data "google_project" "project" {
  project_id = var.project_id
}

# IAM bindings for authorized users to access Cloud Run services
# Cloud Run has built-in IAP support when authentication is required
resource "google_project_iam_member" "iap_users" {
  for_each = toset(var.iap_users)

  project = var.project_id
  role    = "roles/iap.httpsResourceAccessor"
  member  = each.value

  depends_on = [google_project_service.iap]
}
