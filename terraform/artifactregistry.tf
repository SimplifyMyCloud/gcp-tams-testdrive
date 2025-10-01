# Artifact Registry repository for TAMS container images

resource "google_artifact_registry_repository" "tams_repo" {
  location      = var.region
  repository_id = "tams"
  description   = "TAMS Docker repository"
  format        = "DOCKER"
  project       = var.project_id

  depends_on = [google_project_service.artifactregistry]
}
