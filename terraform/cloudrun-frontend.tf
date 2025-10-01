# Cloud Run service for TAMS Frontend

# Build and push TAMS Frontend container
resource "null_resource" "build_tams_frontend" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command     = "gcloud builds submit --tag ${var.region}-docker.pkg.dev/${var.project_id}/tams/tams-frontend:latest"
    working_dir = "${path.module}/../tams-frontend"
  }

  depends_on = [
    google_artifact_registry_repository.tams_repo,
    google_project_service.cloudbuild
  ]
}

# TAMS Frontend Cloud Run service
resource "google_cloud_run_v2_service" "tams_frontend" {
  name     = "tams-frontend"
  location = var.region
  project  = var.project_id

  labels = var.labels

  template {
    service_account = google_service_account.tams_frontend_sa.email

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/tams/tams-frontend:latest"

      ports {
        container_port = 8090
      }

      env {
        name  = "TAMS_API_URL"
        value = google_cloud_run_v2_service.tams_api.uri
      }

      env {
        name  = "PORT"
        value = "8090"
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "256Mi"
        }
      }
    }

    vpc_access {
      connector = google_vpc_access_connector.connector.id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 5
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [
    null_resource.build_tams_frontend,
    google_cloud_run_v2_service.tams_api,
    google_project_service.run
  ]
}

# IAM policy for IAP access to Frontend
resource "google_cloud_run_service_iam_member" "frontend_iap_invoker" {
  location = google_cloud_run_v2_service.tams_frontend.location
  service  = google_cloud_run_v2_service.tams_frontend.name
  role     = "roles/run.invoker"
  member   = "allUsers" # IAP will handle authentication
  project  = var.project_id
}
