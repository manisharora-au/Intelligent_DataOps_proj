# Infrastructure Setup Guide

## Prerequisites

### 1. Install Google Cloud CLI
```bash
# macOS (using Homebrew)
brew install --cask google-cloud-sdk

# Alternative: Download from https://cloud.google.com/sdk/docs/install
```

### 2. Install Terraform
```bash
# macOS (using Homebrew)
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

### 3. Authenticate with GCP
```bash
# Login to GCP
gcloud auth login

# Set application default credentials
gcloud auth application-default login

# Verify your project
gcloud config set project manish-sandpit
gcloud config list
```

## Phase 1 Setup Steps

### Step 1: Enable Required APIs
```bash
cd scripts/
./gcp-setup.sh
```

### Step 2: Deploy Infrastructure with Terraform
```bash
cd infrastructure/
terraform init
terraform plan
terraform apply
```

### Step 3: Verify Setup
```bash
# Check Pub/Sub topics
gcloud pubsub topics list

# Check Cloud Storage buckets
gcloud storage buckets list

# Check BigQuery datasets
bq ls
```

## Cost Management

- **Budget**: $100/month configured
- **Monitoring**: Use `gcloud billing budgets list` to verify
- **Cost Tracking**: Check GCP Console daily during development
- **Auto-cleanup**: Lifecycle policies configured for storage

## Troubleshooting

If you encounter permission errors:
1. Ensure you're the project owner or have Editor role
2. Check billing is enabled: `gcloud billing projects describe manish-sandpit`
3. Verify APIs are enabled: `gcloud services list --enabled`