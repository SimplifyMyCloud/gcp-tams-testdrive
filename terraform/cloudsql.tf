# Cloud SQL PostgreSQL instance and database for TAMS metadata

# Random password for database
resource "random_password" "db_password" {
  length  = 32
  special = true
}

# Cloud SQL PostgreSQL instance
resource "google_sql_database_instance" "tams_db" {
  name             = "tams-db-instance"
  database_version = "POSTGRES_15"
  region           = var.region
  project          = var.project_id

  deletion_protection = false # Set to true for production

  settings {
    tier              = var.db_tier
    availability_type = "ZONAL" # Use "REGIONAL" for production
    disk_size         = 10
    disk_type         = "PD_SSD"

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
      require_ssl     = true
    }

    database_flags {
      name  = "max_connections"
      value = "100"
    }

    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
    }
  }

  depends_on = [
    google_service_networking_connection.private_vpc_connection,
    google_project_service.sql_admin
  ]
}

# Create database
resource "google_sql_database" "tams_database" {
  name     = var.db_name
  instance = google_sql_database_instance.tams_db.name
  project  = var.project_id
}

# Create database user
resource "google_sql_user" "tams_user" {
  name     = "tams"
  instance = google_sql_database_instance.tams_db.name
  password = random_password.db_password.result
  project  = var.project_id
}
