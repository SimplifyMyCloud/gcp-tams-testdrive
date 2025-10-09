# Google Cloud Storage buckets for TAMS media and backups

# GCS Bucket for TAMS media storage
resource "google_storage_bucket" "media_bucket" {
  name          = "${var.project_id}-tams-media"
  location      = var.region
  project       = var.project_id
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  # CORS configuration for browser video playback
  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD"]
    response_header = ["Content-Type", "Content-Length", "Content-Range", "Accept-Ranges"]
    max_age_seconds = 3600
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  labels = var.labels

  depends_on = [google_project_service.storage]
}

# GCS Bucket for TAMS metadata/backups
resource "google_storage_bucket" "backup_bucket" {
  name          = "${var.project_id}-tams-backups"
  location      = var.region
  project       = var.project_id
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  labels = var.labels

  depends_on = [google_project_service.storage]
}

# Make media bucket publicly readable for demo/POC
# TODO: Remove this and implement IAP when moving to production
resource "google_storage_bucket_iam_member" "media_bucket_public_access" {
  bucket = google_storage_bucket.media_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}
