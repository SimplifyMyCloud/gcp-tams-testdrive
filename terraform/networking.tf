# VPC Network and networking configuration for TAMS

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "tams-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id

  depends_on = [google_project_service.compute]
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "tams-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
  project       = var.project_id

  private_ip_google_access = true
}

# Private VPC Connection for Cloud SQL
resource "google_compute_global_address" "private_ip_address" {
  name          = "tams-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
  project       = var.project_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]

  depends_on = [google_project_service.servicenetworking]
}

# Serverless VPC Access Connector for Cloud Run
resource "google_vpc_access_connector" "connector" {
  name          = "tams-vpc-connector"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.8.0.0/28"
  project       = var.project_id

  depends_on = [
    google_compute_network.vpc,
    google_project_service.vpcaccess
  ]
}

# Firewall rule to allow health checks
resource "google_compute_firewall" "allow_health_check" {
  name    = "tams-allow-health-check"
  network = google_compute_network.vpc.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["8080", "8090"]
  }

  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22"
  ]

  target_tags = ["tams-service"]
}

# Firewall rule to allow internal communication
resource "google_compute_firewall" "allow_internal" {
  name    = "tams-allow-internal"
  network = google_compute_network.vpc.name
  project = var.project_id

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/24", "10.8.0.0/28"]
}
