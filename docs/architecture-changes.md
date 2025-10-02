# Architecture Changes - VPC Connector Removal

## Summary

Removed VPC Access Connector from the TAMS deployment architecture in favor of direct Cloud SQL connectivity via the Cloud SQL Admin API.

## Date

October 1, 2025

## Motivation

VPC Access Connectors were causing deployment failures with "Error code 13: VPC Access connector failed to get healthy" despite:
- Adequate CPU quotas (200 CPUs available, 0 used)
- Correct subnet configuration (10.9.0.0/28)
- No organization policy restrictions
- Multiple deletion and recreation attempts

The connector would enter an ERROR state and prevent Cloud Run services from deploying.

## Changes Made

### 1. Removed VPC Connector (`terraform/networking.tf`)

**Before**:
```hcl
resource "google_vpc_access_connector" "connector" {
  name    = "tams-vpc-connector"
  region  = var.region
  project = var.project_id

  subnet {
    name = google_compute_subnetwork.connector_subnet.name
  }

  machine_type  = "e2-micro"
  min_instances = 2
  max_instances = 3
}

resource "google_compute_subnetwork" "connector_subnet" {
  name          = "tams-connector-subnet"
  ip_cidr_range = "10.9.0.0/28"
  region        = var.region
  network       = google_compute_network.vpc.id
  project       = var.project_id
}
```

**After**:
```hcl
# Note: VPC Access Connector not needed - Cloud Run v2 can connect to Cloud SQL
# directly using the cloud_sql_instances parameter in the Cloud Run service config.
# This uses the Cloud SQL Admin API and doesn't require VPC peering or connectors.

# Resources commented out (see file for full comments)
```

### 2. Updated Cloud Run Services (`terraform/cloudrun-api.tf`, `terraform/cloudrun-frontend.tf`)

**Before**:
```hcl
template {
  service_account = google_service_account.tams_api_sa.email

  vpc_access {
    connector = google_vpc_access_connector.connector.id
    egress    = "PRIVATE_RANGES_ONLY"
  }

  containers {
    # ...
  }
}
```

**After**:
```hcl
template {
  service_account = google_service_account.tams_api_sa.email

  # VPC access removed - Cloud Run connects to Cloud SQL via Admin API

  containers {
    # ... environment variables include INSTANCE_CONNECTION_NAME
  }
}
```

### 3. Updated Cloud SQL Configuration (`terraform/cloudsql.tf`)

**Before**:
```hcl
ip_configuration {
  ipv4_enabled    = false
  private_network = google_compute_network.vpc.id
  ssl_mode        = "ENCRYPTED_ONLY"
}
```

**After**:
```hcl
ip_configuration {
  ipv4_enabled    = true  # Enable public IP for Cloud SQL Admin API
  private_network = google_compute_network.vpc.id
  # Cloud SQL Proxy (used by Cloud Run) handles encryption automatically
}
```

### 4. Updated Firewall Rules (`terraform/networking.tf`)

Removed connector subnet from internal firewall source ranges:
```hcl
# Before
source_ranges = ["10.0.0.0/24", "10.9.0.0/28"]

# After
source_ranges = ["10.0.0.0/24"]
```

## New Architecture

### Cloud Run → Cloud SQL Connectivity

**Method**: Cloud SQL Admin API (automatic Cloud SQL Proxy)

**Configuration**:
- Environment variable `INSTANCE_CONNECTION_NAME` set to `project:region:instance`
- Service account has `roles/cloudsql.client` permission
- Cloud SQL has both private and public IP enabled
- Cloud Run automatically creates a Cloud SQL Proxy sidecar

**Security**:
- Connections encrypted via Cloud SQL Proxy
- IAM-based authentication (service account must have cloudsql.client role)
- No direct network access required

### Benefits

1. **Simpler**: No VPC connector resources to manage
2. **More Reliable**: No connector health issues
3. **Lower Cost**: No e2-micro instances running for connector
4. **Same Security**: Cloud SQL Proxy provides encryption, IAM controls access
5. **Easier Troubleshooting**: Fewer moving parts

### Trade-offs

- Cloud SQL now has public IP enabled (but still requires IAM auth for connections)
- Private VPC peering still configured (for future use if needed)

## Migration Steps

If upgrading from previous version with VPC connector:

1. Delete the VPC connector:
   ```bash
   gcloud compute networks vpc-access connectors delete tams-vpc-connector \
     --region=us-central1 --project=smc-gcp-tams-testdrive --quiet
   ```

2. Delete the connector subnet:
   ```bash
   gcloud compute networks subnets delete tams-connector-subnet \
     --region=us-central1 --project=smc-gcp-tams-testdrive --quiet
   ```

3. Remove from terraform state (if already tracked):
   ```bash
   terraform state rm google_vpc_access_connector.connector
   terraform state rm google_compute_subnetwork.connector_subnet
   ```

4. Apply updated terraform:
   ```bash
   terraform apply
   ```

## Documentation Updates

Updated files:
- `docs/terraform-readme.md` - Architecture notes and file descriptions
- `docs/terraform-troubleshooting.md` - VPC connector section marked as legacy
- `README.md` - Architecture diagram notes
- `docs/architecture-changes.md` - This file (new)

## References

- [Cloud Run: Connect to Cloud SQL](https://cloud.google.com/sql/docs/mysql/connect-run)
- [Cloud SQL Proxy Overview](https://cloud.google.com/sql/docs/mysql/sql-proxy)
- [VPC Access Connector (deprecated approach)](https://cloud.google.com/vpc/docs/configure-serverless-vpc-access)

## Status

✅ **Implemented and tested** - Cloud Run services successfully connecting to Cloud SQL without VPC connector.
