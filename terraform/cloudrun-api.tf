# Cloud Run service for TAMS API

# Build and push TAMS API container
resource "null_resource" "build_tams_api" {
  triggers = {
    source_code_hash = sha256(join("", [for f in fileset("${path.module}/../tams-api", "**") : filesha256("${path.module}/../tams-api/${f}")]))
  }

  provisioner "local-exec" {
    command     = "gcloud builds submit --tag ${var.region}-docker.pkg.dev/${var.project_id}/tams/tams-api:latest"
    working_dir = "${path.module}/../tams-api"
  }

  depends_on = [
    google_artifact_registry_repository.tams_repo,
    google_project_service.cloudbuild
  ]
}

# TAMS API Cloud Run service
resource "google_cloud_run_v2_service" "tams_api" {
  name     = "tams-api"
  location = var.region
  project  = var.project_id

  labels = var.labels

  template {
    service_account = google_service_account.tams_api_sa.email

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.tams_db.connection_name]
      }
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/tams/tams-api:latest"

      ports {
        container_port = 8080
      }

      env {
        name  = "DB_NAME"
        value = var.db_name
      }

      env {
        name  = "DB_USER"
        value = google_sql_user.tams_user.name
      }

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }

      env {
        name  = "INSTANCE_CONNECTION_NAME"
        value = google_sql_database_instance.tams_db.connection_name
      }

      env {
        name  = "GCS_BUCKET"
        value = google_storage_bucket.media_bucket.name
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [
    null_resource.build_tams_api,
    google_secret_manager_secret_version.db_password_version,
    google_sql_database_instance.tams_db,
    google_project_service.run
  ]
}

# IAM policy - allow public access to API (for testing)
# TODO: Lock down behind IAP after testing
resource "google_cloud_run_service_iam_member" "api_public" {
  location = google_cloud_run_v2_service.tams_api.location
  service  = google_cloud_run_v2_service.tams_api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
  project  = var.project_id
}
