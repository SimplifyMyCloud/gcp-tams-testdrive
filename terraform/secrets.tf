# Secret Manager for sensitive configuration

# Secret for database password
resource "google_secret_manager_secret" "db_password" {
  secret_id = "tams-db-password"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

# Secret version with the actual password
resource "google_secret_manager_secret_version" "db_password_version" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}
