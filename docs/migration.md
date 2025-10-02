# Terraform Structure Migration

## Changes Made

The Terraform infrastructure has been restructured from a module-based approach to a flat file structure following the "do one thing well" philosophy.

## What Changed

### Before (Module-Based)
```
.
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars.example
└── modules/
    ├── networking/
    ├── database/
    ├── storage/
    ├── iap/
    ├── tams-api/
    └── tams-frontend/
```

### After (Flat File Structure)
```
.
└── terraform/
    ├── provider.tf              # Terraform/provider config
    ├── variables.tf             # Variables
    ├── outputs.tf               # Outputs
    ├── apis.tf                  # GCP API enablement
    ├── networking.tf            # All networking
    ├── cloudsql.tf              # Cloud SQL
    ├── storage.tf               # GCS buckets
    ├── artifactregistry.tf      # Container registry
    ├── secrets.tf               # Secret Manager
    ├── iam.tf                   # Service accounts
    ├── iap.tf                   # IAP config
    ├── cloudrun-api.tf          # API service
    ├── cloudrun-frontend.tf     # Frontend service
    └── terraform.tfvars.example # Example config
```

## Benefits

1. **Simpler** - No module complexity, easier to understand
2. **Focused** - Each file does one thing well
3. **Discoverable** - Easy to find what you need
4. **Maintainable** - Modify specific components without navigating modules
5. **Standard** - Follows common Terraform project patterns

## File Mapping

| Old Module | New File | Purpose |
|------------|----------|---------|
| `modules/networking/` | `networking.tf` | VPC, subnets, firewall |
| `modules/database/` | `cloudsql.tf` | Cloud SQL PostgreSQL |
| `modules/storage/` | `storage.tf` | GCS buckets |
| `modules/iap/` | `iap.tf` | Identity-Aware Proxy |
| `modules/tams-api/` | `cloudrun-api.tf` | TAMS API deployment |
| `modules/tams-frontend/` | `cloudrun-frontend.tf` | Frontend deployment |
| (new) | `apis.tf` | Enable GCP APIs |
| (new) | `artifactregistry.tf` | Container registry |
| (new) | `secrets.tf` | Secret Manager |
| (new) | `iam.tf` | Service accounts & IAM |

## Migration Steps

If you have existing infrastructure deployed with the old structure:

### Option 1: Fresh Deploy (Recommended for Test)

```bash
# Destroy old infrastructure
terraform destroy

# Remove old Terraform state
rm -rf .terraform terraform.tfstate*

# Deploy new structure
cd terraform
terraform init
terraform apply
```

### Option 2: Import Existing Resources (Production)

```bash
# Initialize new structure
cd terraform
terraform init

# Import each resource
terraform import google_compute_network.vpc projects/PROJECT_ID/global/networks/tams-vpc
terraform import google_sql_database_instance.tams_db PROJECT_ID:tams-db-instance
# ... continue for all resources

# Verify
terraform plan  # Should show no changes
```

## Command Updates

All Terraform commands now run from the `terraform/` directory:

### Old Commands
```bash
terraform init
terraform apply
terraform output
```

### New Commands
```bash
cd terraform
terraform init
terraform apply
terraform output
```

Or use the `deploy.sh` script which handles this automatically:
```bash
./deploy.sh
```

## No Functional Changes

⚠️ **Important**: The infrastructure deployed is **identical**. Only the file organization changed.

- Same resources
- Same configuration
- Same behavior
- Same costs

## Updated Documentation

All documentation has been updated:

- ✅ `README.md` - Main project docs
- ✅ `docs/claude.md` - Architecture guide
- ✅ `docs/quickstart.md` - Quick start guide
- ✅ `docs/terraform-readme.md` - Terraform-specific docs
- ✅ `deploy.sh` - Deployment script

## Questions?

See `docs/terraform-readme.md` for detailed Terraform documentation.
