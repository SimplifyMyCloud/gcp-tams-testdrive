variable "project_id" {
  description = "GCP Project ID for TAMS deployment"
  type        = string
  default     = "smc-gcp-tams-testdrive"
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for resources"
  type        = string
  default     = "us-central1-a"
}

variable "iap_users" {
  description = "List of users/groups allowed to access via IAP (format: user:email or group:email)"
  type        = list(string)
  default     = []
}

variable "db_tier" {
  description = "Cloud SQL instance tier"
  type        = string
  default     = "db-f1-micro"
}

variable "db_name" {
  description = "TAMS database name"
  type        = string
  default     = "tams"
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default = {
    project     = "tams-testdrive"
    environment = "test"
    managed_by  = "terraform"
  }
}
