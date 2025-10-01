# GCP TAMS Test Drive

Test drive environment for BBC R&D's TAMS (Time Addressable Media Store) API on Google Cloud Platform.

## Overview

This project deploys a complete TAMS infrastructure on GCP, enabling the BBC RD teams to test and evaluate TAMS in a Cloud Native Agile Production (CNAP) environment. The deployment includes:

- **TAMS API**: Python FastAPI implementation of the TAMS specification
- **Web Frontend**: Go-based UI for timestamp tagging and media management
- **Cloud SQL**: PostgreSQL database for metadata storage
- **Cloud Storage**: GCS buckets for media segments
- **IAP Security**: All services behind Identity-Aware Proxy (no public access)

## Quick Start

### Prerequisites

1. GCP project: `smc-gcp-tams-testdrive` (or modify in `terraform.tfvars`)
2. Billing enabled on the project
3. Tools installed:
   - `gcloud` CLI (authenticated)
   - Terraform >= 1.5
   - Docker (for local development)

### Deploy

```bash
# 1. Authenticate with GCP
gcloud auth application-default login
gcloud config set project smc-gcp-tams-testdrive

# 2. Configure deployment
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and add your email for IAP access

# 3. Deploy infrastructure
terraform init
terraform plan
terraform apply

# 4. Get service URLs
terraform output
```

Initial deployment takes ~15-20 minutes.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Identity-Aware Proxy               │
│                  (OAuth2 Authentication)             │
└────────────────┬────────────────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
┌───────▼──────┐   ┌──────▼──────┐
│   Frontend   │   │  TAMS API   │
│  (Go/HTML)   │──▶│  (Python)   │
│  Cloud Run   │   │  Cloud Run  │
└──────────────┘   └──────┬──────┘
                          │
                   ┌──────┴──────┐
                   │             │
            ┌──────▼──────┐ ┌───▼────────┐
            │  Cloud SQL  │ │    GCS     │
            │ PostgreSQL  │ │  (Media)   │
            │ (Metadata)  │ │            │
            └─────────────┘ └────────────┘
```

## Features

### TAMS API Implementation
- **Sources**: Top-level media sources
- **Flows**: Continuous media streams with format/codec metadata
- **Segments**: Time-addressable media chunks with ISO 8601 timestamps
- **Storage**: Automatic GCS integration for media files
- **Metadata**: PostgreSQL storage for all TAMS entities

### Web Frontend
- Create and manage sources
- Create and manage flows
- Upload timestamped media segments
- View all segments with time ranges
- Built-in timestamp helper (ISO 8601 format)

### Security
- All services behind IAP (no public internet access)
- OAuth2 authentication
- Service accounts with least-privilege permissions
- Database passwords in Secret Manager
- Private VPC networking

## Usage

### Access the Frontend

```bash
# Get the frontend URL
cd terraform
terraform output tams_frontend_url

# Open in browser (requires authentication)
```

### Create Your First Flow

1. **Create a Source**:
   - ID: `source-1`
   - Label: "Test Camera"

2. **Create a Flow**:
   - ID: `flow-1`
   - Source: `source-1`
   - Label: "Video Stream"
   - Format: `video/mp4`
   - Codec: `h264`

3. **Upload Segments**:
   - Select flow: `flow-1`
   - Start time: `2024-01-01T00:00:00Z`
   - End time: `2024-01-01T00:01:00Z`
   - Upload media file

### API Access

```bash
# Get API URL
cd terraform
API_URL=$(terraform output -raw tams_api_url)

# Create a source (requires IAP authentication)
curl -X POST "$API_URL/sources" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "source-1",
    "label": "Test Source",
    "description": "My first source"
  }'

# List sources
curl "$API_URL/sources"
```

## Development

### Local API Development

```bash
cd tams-api

# Install dependencies
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Configure environment
export DB_HOST=localhost
export DB_NAME=tams
export DB_USER=tams
export DB_PASSWORD=password
export GCS_BUCKET=test-bucket

# Run server
python -m uvicorn app.main:app --reload --port 8080
```

### Local Frontend Development

```bash
cd tams-frontend

# Install dependencies
go mod download

# Run server
TAMS_API_URL=http://localhost:8080 go run main.go
```

## Project Structure

```
.
├── terraform/                    # All Terraform infrastructure code
│   ├── provider.tf              # Terraform and provider setup
│   ├── variables.tf             # Input variables
│   ├── outputs.tf               # Output definitions
│   ├── apis.tf                  # GCP API enablement
│   ├── networking.tf            # VPC and networking
│   ├── cloudsql.tf              # Cloud SQL PostgreSQL
│   ├── storage.tf               # GCS buckets
│   ├── artifactregistry.tf      # Container registry
│   ├── secrets.tf               # Secret Manager
│   ├── iam.tf                   # Service accounts
│   ├── iap.tf                   # Identity-Aware Proxy
│   ├── cloudrun-api.tf          # TAMS API Cloud Run
│   ├── cloudrun-frontend.tf     # Frontend Cloud Run
│   └── terraform.tfvars.example # Example configuration
│
├── tams-api/                    # Python TAMS API
│   ├── app/
│   │   ├── main.py           # FastAPI application
│   │   ├── database.py       # SQLAlchemy models
│   │   ├── models.py         # Pydantic schemas
│   │   ├── storage.py        # GCS operations
│   │   └── config.py         # Configuration
│   ├── requirements.txt
│   ├── Dockerfile
│   └── README.md
│
└── tams-frontend/             # Go web frontend
    ├── main.go               # HTTP server
    ├── templates/            # HTML templates
    ├── go.mod
    ├── Dockerfile
    └── README.md
```

## TAMS Specification

This implementation follows the [BBC TAMS specification](https://github.com/bbc/tams) with these key concepts:

- **Time-Based Addressing**: Every media segment has a precise timestamp range
- **Immutability**: Once written, segments cannot be changed
- **Content-Centric**: Media is referenced by ID and timestamp, not file paths
- **Cloud-Native**: Built for object storage and horizontal scaling

## Troubleshooting

### IAP Access Issues
- Ensure your email is in `iap_users` in `terraform.tfvars`
- Run `gcloud auth login` to authenticate
- Check IAM permissions in GCP Console

### Cloud SQL Connection Errors
- Verify VPC connector is created: `gcloud compute networks vpc-access connectors list`
- Check Service Networking API is enabled
- View logs: `gcloud run services logs read tams-api`

### Container Build Failures
- Enable Cloud Build API: `gcloud services enable cloudbuild.googleapis.com`
- Check Artifact Registry exists
- Verify service account permissions

## Cleanup

```bash
# Destroy all infrastructure
cd terraform
terraform destroy
```

⚠️ **Warning**: This deletes all data including media files and database contents.

## Cost Estimation

Approximate monthly costs (assuming light usage):
- Cloud Run: ~$5-10 (mostly idle)
- Cloud SQL (db-f1-micro): ~$15-20
- Cloud Storage: ~$1-5 (depends on data volume)
- VPC Connector: ~$10
- **Total**: ~$30-45/month for test environment

## Resources

- [BBC TAMS Specification](https://github.com/bbc/tams)
- [TAMS API Documentation](https://github.com/bbc/tams/tree/main/docs)
- [Cloud Native Agile Production (CNAP)](https://aws.amazon.com/blogs/media/aws-bbc-adobe-and-others-introduce-open-source-framework-for-fast-turnaround-media-workflows-at-ibc-2024/)
- [AWS TAMS Implementation](https://github.com/awslabs/time-addressable-media-store)

## License

This project is for testing purposes. See individual component licenses:
- TAMS Specification: [Apache 2.0](https://github.com/bbc/tams/blob/main/LICENSE)
- This Implementation: Apache 2.0
