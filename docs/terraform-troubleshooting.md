# Terraform Deployment Troubleshooting

Common issues and solutions when deploying TAMS on GCP.

## VPC Access Connector Issues

### Note: VPC Connector No Longer Required (Updated)

**As of the latest version**, the TAMS deployment **no longer uses VPC Access Connectors**.

Cloud Run services connect to Cloud SQL using the **Cloud SQL Admin API** directly via the `INSTANCE_CONNECTION_NAME` environment variable. This approach:
- Is simpler and more reliable
- Doesn't require VPC connectors
- Still maintains security via IAM and Cloud SQL Proxy encryption
- Cloud SQL has both private and public IP enabled (connections via Cloud SQL Proxy are encrypted)

If you see VPC connector errors, ensure you're using the latest terraform configuration where the connector resources are commented out in `terraform/networking.tf`.

### Legacy: Error "VPC Access connector failed to get healthy" (No longer applicable)

This error occurred in earlier versions that used VPC connectors. The current implementation doesn't use VPC connectors, so this error should not occur.

<details>
<summary>Click to see legacy VPC connector troubleshooting (for reference only)</summary>

**Cause**: Quota limits or API permissions

**Solutions**:

1. **Check Compute Engine API quota**:
   ```bash
   gcloud compute project-info describe --project=smc-gcp-tams-testdrive
   ```

2. **Ensure you have Compute Engine instances quota**:
   - Need at least 2 e2-micro instances for VPC connector
   - Check quotas in GCP Console: IAM & Admin > Quotas
   - Filter for "Compute Engine API" and "CPUs"

3. **Request quota increase if needed**:
   - Go to GCP Console > IAM & Admin > Quotas
   - Select "Compute Engine API" > "CPUs (all regions)"
   - Click "Edit Quotas" and request increase

4. **Wait for connector to stabilize**:
   - VPC connectors can take 5-10 minutes to become healthy
   - Be patient during first deployment

5. **Check organization policies**:
   ```bash
   gcloud resource-manager org-policies list \
     --project=smc-gcp-tams-testdrive
   ```
</details>

## IAP Configuration Issues

### Error: "Requested entity was not found" (IAP Brand)

**Cause**: IAP OAuth consent screen doesn't exist

**Solution**: The IAP configuration has been simplified to use Cloud Run's built-in authentication:
- Users in `iap_users` list get `roles/run.invoker` permission
- Cloud Run requires authentication by default
- No separate IAP brand needed

### Can't Access Cloud Run Services

**Solution**:

1. **Ensure you're authenticated**:
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

2. **Check you're in the iap_users list** in `terraform.tfvars`:
   ```hcl
   iap_users = [
     "user:your-email@example.com",
   ]
   ```

3. **Verify IAM permissions**:
   ```bash
   gcloud run services get-iam-policy tams-api \
     --region=us-central1 \
     --project=smc-gcp-tams-testdrive
   ```

4. **Access with gcloud proxy**:
   ```bash
   gcloud run services proxy tams-frontend \
     --region=us-central1 \
     --project=smc-gcp-tams-testdrive
   ```

## Cloud SQL Issues

### Deprecation Warning: require_ssl

**Status**: Fixed - now uses `ssl_mode = "ENCRYPTED_ONLY"`

### Connection Timeouts

**Solutions**:

1. **Check VPC connector is healthy**:
   ```bash
   gcloud compute networks vpc-access connectors describe tams-vpc-connector \
     --region=us-central1
   ```

2. **Verify Cloud Run can reach Cloud SQL**:
   - Check Cloud Run logs for connection errors
   ```bash
   gcloud run services logs read tams-api --region=us-central1
   ```

3. **Check Service Networking connection**:
   ```bash
   gcloud services vpc-peerings list \
     --service=servicenetworking.googleapis.com \
     --network=tams-vpc
   ```

## API Enablement Issues

### Error: "API [xyz.googleapis.com] not enabled"

**Solution**:

1. **Enable manually**:
   ```bash
   gcloud services enable [api-name].googleapis.com \
     --project=smc-gcp-tams-testdrive
   ```

2. **Enable all required APIs**:
   ```bash
   gcloud services enable \
     compute.googleapis.com \
     run.googleapis.com \
     sqladmin.googleapis.com \
     storage.googleapis.com \
     vpcaccess.googleapis.com \
     servicenetworking.googleapis.com \
     secretmanager.googleapis.com \
     cloudbuild.googleapis.com \
     artifactregistry.googleapis.com
   ```

3. **Retry terraform apply**:
   ```bash
   terraform apply
   ```

## Container Build Issues

### Error: Cloud Build permission denied

**Solution**:

1. **Enable Cloud Build API**:
   ```bash
   gcloud services enable cloudbuild.googleapis.com
   ```

2. **Grant Cloud Build permissions**:
   ```bash
   PROJECT_NUMBER=$(gcloud projects describe smc-gcp-tams-testdrive \
     --format='value(projectNumber)')

   gcloud projects add-iam-policy-binding smc-gcp-tams-testdrive \
     --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
     --role="roles/storage.admin"
   ```

### Error: Artifact Registry repository not found

**Solution**:

The repository is created by Terraform. If it fails:
```bash
gcloud artifacts repositories create tams \
  --repository-format=docker \
  --location=us-central1 \
  --description="TAMS Docker repository"
```

## Quota Issues

### Not enough resources available

**Common quotas to check**:

1. **CPUs**: Need ~4 CPUs total
   - 2 for VPC connector
   - 1 for Cloud Run API
   - 1 for Cloud Run Frontend

2. **In-use IP addresses**: Need subnet space
   - 10.0.0.0/24 for main subnet
   - 10.8.0.0/28 for connector subnet

3. **Cloud SQL instances**: Need 1 instance quota

**Check all quotas**:
```bash
gcloud compute project-info describe \
  --project=smc-gcp-tams-testdrive \
  --format="table(quotas.metric,quotas.usage,quotas.limit)"
```

## Billing Issues

### Error: "Project has billing disabled"

**Solution**:

1. **Check billing account**:
   ```bash
   gcloud beta billing projects describe smc-gcp-tams-testdrive
   ```

2. **Link billing account**:
   ```bash
   gcloud beta billing projects link smc-gcp-tams-testdrive \
     --billing-account=BILLING_ACCOUNT_ID
   ```

## State Issues

### State lock timeout

**Solution**:
```bash
# Only if you're SURE no other terraform is running
terraform force-unlock <LOCK_ID>
```

### Corrupted state

**Solution**:
```bash
# Backup state
cp terraform.tfstate terraform.tfstate.backup

# Try to refresh
terraform refresh

# If that fails, import resources manually
terraform import google_compute_network.vpc projects/PROJECT_ID/global/networks/tams-vpc
```

## Getting Help

1. **Check Terraform output**:
   ```bash
   terraform apply -no-color 2>&1 | tee terraform.log
   ```

2. **Check GCP logs**:
   - Cloud Console > Logging > Logs Explorer
   - Filter by resource type (Cloud Run, VPC, etc.)

3. **Validate configuration**:
   ```bash
   terraform validate
   terraform fmt -check
   ```

4. **Detailed plan**:
   ```bash
   terraform plan -out=tfplan
   terraform show tfplan
   ```

## Quick Fixes

### Nuclear Option: Start Fresh

If everything is broken:
```bash
# Destroy everything
terraform destroy -auto-approve

# Remove state
rm -rf .terraform terraform.tfstate*

# Re-initialize
terraform init
terraform apply
```

### Partial Apply

Apply specific resources only:
```bash
# Just networking
terraform apply -target=google_compute_network.vpc

# Just Cloud SQL
terraform apply -target=google_sql_database_instance.tams_db

# Just Cloud Run
terraform apply -target=google_cloud_run_v2_service.tams_api
```
