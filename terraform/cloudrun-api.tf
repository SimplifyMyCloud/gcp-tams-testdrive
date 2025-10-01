# Cloud Run service for TAMS API

# Build and push TAMS API container
resource "null_resource" "build_tams_api" {
  triggers = {
    always_run = timestamp()
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

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }

    vpc_access {
      connector = google_vpc_access_connector.connector.id
      egress    = "PRIVATE_RANGES_ONLY"
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
    google_project_service.run
  ]
}

# IAM policy for IAP access to API
resource "google_cloud_run_service_iam_member" "api_iap_invoker" {
  location = google_cloud_run_v2_service.tams_api.location
  service  = google_cloud_run_v2_service.tams_api.name
  role     = "roles/run.invoker"
  member   = "allUsers" # IAP will handle authentication
  project  = var.project_id
}
