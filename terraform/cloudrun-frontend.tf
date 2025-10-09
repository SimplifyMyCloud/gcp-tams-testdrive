# Cloud Run service for TAMS Frontend

# Build and push TAMS Frontend container
resource "null_resource" "build_tams_frontend" {
  triggers = {
    source_code_hash = sha256(join("", [for f in fileset("${path.module}/../tams-frontend", "**") : filesha256("${path.module}/../tams-frontend/${f}")]))
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

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
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

# IAM policy - allow public access to frontend
resource "google_cloud_run_service_iam_member" "frontend_public" {
  location = google_cloud_run_v2_service.tams_frontend.location
  service  = google_cloud_run_v2_service.tams_frontend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
  project  = var.project_id
}
