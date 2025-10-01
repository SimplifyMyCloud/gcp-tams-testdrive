# TAMS Terraform Infrastructure

This directory contains all Terraform infrastructure-as-code for the TAMS deployment on GCP.

## File Organization

Each file manages a specific aspect of the infrastructure following the "do one thing well" philosophy:

| File | Purpose |
|------|---------|
| `provider.tf` | Terraform and provider configuration |
| `variables.tf` | Input variables and defaults |
| `outputs.tf` | Output values (URLs, connection strings, etc.) |
| `apis.tf` | Enable required GCP APIs |
| `networking.tf` | VPC, subnets, VPC connector, firewall rules |
| `cloudsql.tf` | Cloud SQL PostgreSQL instance and database |
| `storage.tf` | GCS buckets for media and backups |
| `artifactregistry.tf` | Artifact Registry for Docker images |
| `secrets.tf` | Secret Manager for sensitive data |
| `iam.tf` | Service accounts and IAM permissions |
| `iap.tf` | Identity-Aware Proxy configuration |
| `cloudrun-api.tf` | TAMS API Cloud Run service |
| `cloudrun-frontend.tf` | TAMS Frontend Cloud Run service |

## Quick Start

```bash
# 1. Copy example config
cp terraform.tfvars.example terraform.tfvars

# 2. Edit terraform.tfvars - add your email for IAP access
# Example: iap_users = ["user:your-email@example.com"]

# 3. Initialize
terraform init

# 4. Preview changes
terraform plan

# 5. Deploy
terraform apply
```

## Configuration

Edit `terraform.tfvars` to customize:

```hcl
project_id = "smc-gcp-tams-testdrive"
region     = "us-central1"
zone       = "us-central1-a"

# Add users who can access TAMS via IAP
iap_users = [
  "user:your-email@example.com",
]

# Cloud SQL tier (use larger for production)
db_tier = "db-f1-micro"
```

## Common Operations

```bash
# View all outputs
terraform output

# View specific output
terraform output tams_api_url

# Format all files
terraform fmt

# Validate configuration
terraform validate

# Show current state
terraform show

# List all resources
terraform state list

# Destroy everything
terraform destroy
```

## Resource Dependencies

The infrastructure is deployed in this order:

1. **APIs** - Enable required GCP services
2. **Networking** - VPC, subnets, VPC connector
3. **Storage** - GCS buckets
4. **Secrets** - Secret Manager for DB password
5. **Cloud SQL** - PostgreSQL database
6. **IAM** - Service accounts and permissions
7. **Artifact Registry** - Container image repository
8. **Cloud Run API** - TAMS API service
9. **Cloud Run Frontend** - Web UI
10. **IAP** - Identity-Aware Proxy

Terraform automatically handles dependencies based on resource references.

## Modifying Infrastructure

### Change Cloud SQL Tier

Edit `terraform.tfvars`:
```hcl
db_tier = "db-g1-small"  # or db-custom-2-7680
```

Then apply:
```bash
terraform apply
```

### Add IAP Users

Edit `terraform.tfvars`:
```hcl
iap_users = [
  "user:alice@example.com",
  "user:bob@example.com",
  "group:team@example.com",
]
```

Apply:
```bash
terraform apply
```

### Change Region

⚠️ **Warning**: Changing region requires recreating most resources.

Edit `terraform.tfvars`:
```hcl
region = "europe-west1"
zone   = "europe-west1-b"
```

Apply (will destroy and recreate):
```bash
terraform apply
```

## Troubleshooting

### State Lock Issues

If Terraform state is locked:
```bash
# Only use if you're certain no other Terraform is running
terraform force-unlock <LOCK_ID>
```

### API Not Enabled Errors

If you get API not enabled errors:
```bash
# Manually enable the API
gcloud services enable <api-name>.googleapis.com

# Then retry
terraform apply
```

### Import Existing Resources

If resources already exist:
```bash
terraform import <resource_type>.<name> <resource_id>
```

Example:
```bash
terraform import google_storage_bucket.media_bucket smc-gcp-tams-testdrive-tams-media
```

## State Management

Current state is stored locally in `terraform.tfstate`. For production:

1. **Use remote backend** (GCS):
   ```hcl
   terraform {
     backend "gcs" {
       bucket = "my-terraform-state"
       prefix = "tams"
     }
   }
   ```

2. **Enable state locking**
3. **Use workspaces** for multiple environments

## Security Notes

- `terraform.tfvars` is gitignored (contains sensitive data)
- Database passwords are auto-generated and stored in Secret Manager
- All services use private IPs where possible
- IAP provides OAuth2 authentication
- Service accounts follow least-privilege principle

## Cost Optimization

Test environment (~$30-45/month):
- Cloud SQL: db-f1-micro (minimal)
- Cloud Run: Scale to zero when idle
- Storage: Lifecycle policies for old data

Production recommendations:
- Cloud SQL: db-custom-2-7680 or larger
- Cloud Run: Set min instances > 0
- Enable regional replication for Cloud SQL
- Use Cloud CDN for frontend
