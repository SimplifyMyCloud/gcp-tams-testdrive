output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP Region"
  value       = var.region
}

output "tams_api_url" {
  description = "TAMS API Cloud Run URL (requires IAP authentication)"
  value       = google_cloud_run_v2_service.tams_api.uri
}

output "tams_frontend_url" {
  description = "TAMS Frontend Cloud Run URL (requires IAP authentication)"
  value       = google_cloud_run_v2_service.tams_frontend.uri
}

output "media_bucket" {
  description = "GCS bucket for TAMS media storage"
  value       = google_storage_bucket.media_bucket.name
}

output "db_instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.tams_db.name
}

output "db_connection_name" {
  description = "Cloud SQL connection name"
  value       = google_sql_database_instance.tams_db.connection_name
}

output "iap_instructions" {
  description = "Instructions for accessing TAMS via IAP"
  value       = <<-EOT
    To access TAMS services:
    1. Ensure you're authenticated: gcloud auth login
    2. Access via IAP proxy:
       - API: ${google_cloud_run_v2_service.tams_api.uri}
       - Frontend: ${google_cloud_run_v2_service.tams_frontend.uri}
    3. Your user must be in the IAP users list
  EOT
}
