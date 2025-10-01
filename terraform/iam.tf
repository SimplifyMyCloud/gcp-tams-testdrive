# IAM Service Accounts and permissions for TAMS services

# Service account for TAMS API
resource "google_service_account" "tams_api_sa" {
  account_id   = "tams-api-sa"
  display_name = "TAMS API Service Account"
  project      = var.project_id
}

# Grant Cloud SQL client role to API service account
resource "google_project_iam_member" "api_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.tams_api_sa.email}"
}

# Grant Storage admin for media bucket to API service account
resource "google_storage_bucket_iam_member" "api_media_access" {
  bucket = google_storage_bucket.media_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.tams_api_sa.email}"
}

# Grant secret accessor role to API service account
resource "google_secret_manager_secret_iam_member" "api_secret_access" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.tams_api_sa.email}"
}

# Service account for TAMS Frontend
resource "google_service_account" "tams_frontend_sa" {
  account_id   = "tams-frontend-sa"
  display_name = "TAMS Frontend Service Account"
  project      = var.project_id
}
