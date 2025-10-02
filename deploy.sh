#!/bin/bash
set -e

# GCP TAMS Test Drive - Deployment Script
# This script helps deploy the TAMS infrastructure to GCP

PROJECT_ID="${PROJECT_ID:-smc-gcp-tams-testdrive}"
REGION="${REGION:-us-central1}"

echo "================================================"
echo "GCP TAMS Test Drive - Deployment Script"
echo "================================================"
echo ""
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Check prerequisites
command -v gcloud >/dev/null 2>&1 || { echo "Error: gcloud CLI is required but not installed. Visit: https://cloud.google.com/sdk/docs/install"; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "Error: Terraform is required but not installed. Visit: https://www.terraform.io/downloads"; exit 1; }

echo "✓ Prerequisites check passed"
echo ""

# Authenticate with GCP
echo "Step 1: Authenticating with GCP..."
gcloud auth application-default login --quiet || true
gcloud config set project "$PROJECT_ID"
echo "✓ Authenticated"
echo ""

# Change to terraform directory
cd terraform || { echo "Error: terraform directory not found"; exit 1; }

# Check if terraform.tfvars exists
if [ ! -f terraform.tfvars ]; then
    echo "Step 2: Creating terraform.tfvars from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo ""
    echo "⚠️  IMPORTANT: Edit terraform/terraform.tfvars and add your email to iap_users"
    echo "   Example: iap_users = [\"user:your-email@example.com\"]"
    echo ""
    read -p "Press Enter after editing terraform/terraform.tfvars to continue..."
else
    echo "Step 2: Using existing terraform/terraform.tfvars"
fi
echo ""

# Enable required APIs
echo "Step 3: Enabling required GCP APIs..."
gcloud services enable \
    compute.googleapis.com \
    run.googleapis.com \
    sqladmin.googleapis.com \
    storage.googleapis.com \
    iap.googleapis.com \
    cloudresourcemanager.googleapis.com \
    servicenetworking.googleapis.com \
    vpcaccess.googleapis.com \
    secretmanager.googleapis.com \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    --project="$PROJECT_ID"
echo "✓ APIs enabled"
echo ""

# Initialize Terraform
echo "Step 4: Initializing Terraform..."
terraform init
echo "✓ Terraform initialized"
echo ""

# Validate Terraform configuration
echo "Step 5: Validating Terraform configuration..."
terraform validate
echo "✓ Configuration valid"
echo ""

# Show Terraform plan
echo "Step 6: Planning infrastructure changes..."
terraform plan
echo ""

# Confirm deployment
read -p "Do you want to proceed with deployment? (yes/no): " -r
echo ""
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Apply Terraform
echo "Step 7: Deploying infrastructure..."
echo "⏳ This will take 15-20 minutes (Cloud SQL creation is slow)..."
echo ""
terraform apply -auto-approve

# Show outputs
echo ""
echo "================================================"
echo "Deployment Complete! 🎉"
echo "================================================"
echo ""
terraform output
echo ""

echo "Next Steps:"
echo "1. Access the frontend: cd terraform && terraform output tams_frontend_url"
echo "2. Create a Source in the web UI"
echo "3. Create a Flow"
echo "4. Upload timestamped media segments"
echo ""
echo "For help, see: README.md or docs/claude.md"
echo ""
