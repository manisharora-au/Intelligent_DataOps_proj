#!/bin/bash
# Terraform Service Account Helper Script
# Use this script to run terraform commands with the dedicated service account

set -e

# Service account credentials path
SA_CREDENTIALS="$HOME/.gcp/credentials/terraform-dataops-key.json"

# Check if credentials file exists
if [ ! -f "$SA_CREDENTIALS" ]; then
    echo "❌ Error: Service account credentials not found at $SA_CREDENTIALS"
    echo "Please ensure the service account key file exists."
    exit 1
fi

# Export credentials for terraform
export GOOGLE_APPLICATION_CREDENTIALS="$SA_CREDENTIALS"

# Show which account we're using
echo "🔐 Using service account: terraform-dataops@manish-sandpit.iam.gserviceaccount.com"
echo "📁 Credentials: $SA_CREDENTIALS"
echo "📍 Project: manish-sandpit"
echo ""

# Run terraform command with arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 <terraform-command> [arguments]"
    echo ""
    echo "Examples:"
    echo "  $0 init"
    echo "  $0 plan"
    echo "  $0 apply"
    echo "  $0 destroy"
    exit 1
fi

echo "🚀 Running: terraform $*"
terraform "$@"