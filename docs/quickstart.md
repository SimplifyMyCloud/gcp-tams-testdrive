# TAMS GCP Quick Start Guide

Get TAMS running on GCP in ~20 minutes.

## Prerequisites

- GCP account with billing enabled
- `gcloud` CLI installed
- Terraform >= 1.5 installed

## Deploy in 4 Commands

```bash
# 1. Run the deploy script
./deploy.sh

# 2. Get the frontend URL
cd terraform && terraform output tams_frontend_url

# 3. Open in browser and authenticate

# 4. Start creating sources and flows!
```

## What Gets Deployed

| Component | Service | Purpose |
|-----------|---------|---------|
| TAMS API | Cloud Run | REST API for media management |
| Frontend | Cloud Run | Web UI for timestamp tagging |
| Database | Cloud SQL | PostgreSQL metadata store |
| Storage | GCS | Media segment storage |
| Security | IAP | OAuth2 authentication |

## First Test

### Via Web UI

1. Go to **Sources** → Create:
   - ID: `test-source`
   - Label: "My First Source"

2. Go to **Flows** → Create:
   - ID: `test-flow`
   - Source: `test-source`
   - Label: "Test Stream"
   - Format: `video/mp4`

3. Go to **Upload**:
   - Flow: `test-flow`
   - Start: `2024-01-01T00:00:00Z`
   - End: `2024-01-01T00:01:00Z`
   - Upload any file

4. Go to **Segments** → View your timestamped media!

### Via API

```bash
cd terraform
API_URL=$(terraform output -raw tams_api_url)

# Create source
curl -X POST "$API_URL/sources" \
  -H "Content-Type: application/json" \
  -d '{"id":"api-test","label":"API Test Source"}'

# List sources
curl "$API_URL/sources"
```

## Key Concepts

### Sources
Top-level containers for media (e.g., "Camera 1", "Audio Recorder A")

### Flows
Continuous streams within a source (e.g., "Video Stream", "Audio Track")

### Segments
Time-addressable chunks of media with precise start/end timestamps

### Time Addressing
Every segment has an ISO 8601 timestamp range:
- Start: `2024-01-01T10:00:00Z`
- End: `2024-01-01T10:01:00Z`

Media is retrieved by Flow ID + Timestamp, not file paths!

## Common Commands

```bash
# View outputs
cd terraform && terraform output

# View API logs
gcloud run services logs read tams-api --region=us-central1

# View frontend logs
gcloud run services logs read tams-frontend --region=us-central1

# Connect to database (for debugging)
gcloud sql connect tams-db-instance --user=tams

# Destroy everything
cd terraform && terraform destroy
```

## Troubleshooting

**Can't access services?**
- Ensure your email is in `terraform.tfvars` under `iap_users`
- Run: `gcloud auth login`

**Deployment stuck?**
- Cloud SQL takes 10-15 minutes to create (normal)

**Container build failed?**
- Run: `gcloud services enable cloudbuild.googleapis.com`

**Need help?**
- See: `README.md` for detailed docs
- See: `docs/claude.md` for architecture details

## Costs

~$30-45/month for light testing usage.

## Clean Up

```bash
cd terraform
terraform destroy
```

⚠️ This deletes all media and data!

## Resources

- [BBC TAMS Spec](https://github.com/bbc/tams)
- [TAMS Docs](https://github.com/bbc/tams/tree/main/docs)
- [This Project's README](./README.md)
