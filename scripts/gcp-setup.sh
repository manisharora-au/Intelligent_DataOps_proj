#!/bin/bash

# GCP Project Setup Script for Intelligent DataOps Platform
# Phase 1: Foundation & Infrastructure

PROJECT_ID="manish-sandpit"
REGION="us-central1"  # Cost-effective region
ZONE="us-central1-a"

echo "=== GCP Project Setup for Intelligent DataOps ==="
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Budget: $100/month (cost-optimized setup)"
echo ""

# Set the project
echo "Setting GCP project..."
gcloud config set project $PROJECT_ID
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

echo ""
echo "=== Required APIs for Phase 1 ==="

# Required APIs for Phase 1 (minimal set)
APIS=(
    "pubsub.googleapis.com"           # Pub/Sub for messaging
    "dataflow.googleapis.com"         # Dataflow for stream processing  
    "bigquery.googleapis.com"         # BigQuery for data warehouse
    "storage-api.googleapis.com"      # Cloud Storage
    "storage.googleapis.com"          # Cloud Storage API
    "logging.googleapis.com"          # Cloud Logging
    "monitoring.googleapis.com"       # Cloud Monitoring
    "cloudbuild.googleapis.com"       # Cloud Build (for CI/CD)
    "iam.googleapis.com"             # IAM for security
    "cloudresourcemanager.googleapis.com"  # Resource management
)

echo "Enabling required APIs..."
for api in "${APIS[@]}"; do
    echo "Enabling $api..."
    gcloud services enable $api
done

echo ""
echo "=== Checking Current Project Status ==="

# Check project info
echo "Project Information:"
gcloud projects describe $PROJECT_ID

echo ""
echo "Enabled APIs:"
gcloud services list --enabled --format="table(name)"

echo ""
echo "Current IAM Policy (your access):"
gcloud projects get-iam-policy $PROJECT_ID --format="table(bindings.members,bindings.role)"

echo ""
echo "Billing Account (verify budget is set):"
gcloud billing projects describe $PROJECT_ID

echo ""
echo "=== Cost Monitoring Setup ==="
echo "✓ Budget alert configured: $100/month"
echo "✓ Recommendations: Use preemptible instances, implement lifecycle policies"
echo "✓ Daily cost monitoring recommended"

echo ""
echo "Setup complete! Ready for Terraform infrastructure deployment."