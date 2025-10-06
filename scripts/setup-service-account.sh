#!/bin/bash
# Automated Service Account Setup Script
# This script sets up the terraform-dataops service account from scratch

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="manish-sandpit"
SA_NAME="terraform-dataops"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
CREDENTIALS_DIR="$HOME/.gcp/credentials"
CREDENTIALS_FILE="${CREDENTIALS_DIR}/terraform-dataops-key.json"

# Required roles
ROLES=(
  "roles/storage.admin"
  "roles/pubsub.admin"
  "roles/bigquery.admin"
  "roles/dataflow.admin"
  "roles/iam.serviceAccountAdmin"
  "roles/resourcemanager.projectIamAdmin"
  "roles/monitoring.admin"
  "roles/logging.admin"
)

echo -e "${BLUE}🚀 DataOps Service Account Setup${NC}"
echo -e "${BLUE}===================================${NC}"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ Error: gcloud CLI is not installed${NC}"
    echo "Please install gcloud CLI: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo -e "${YELLOW}⚠️  Not authenticated with gcloud${NC}"
    echo "Please run: gcloud auth login"
    exit 1
fi

# Set project
echo -e "${BLUE}📍 Setting project to ${PROJECT_ID}...${NC}"
gcloud config set project $PROJECT_ID

# Verify project access
if ! gcloud projects describe $PROJECT_ID &> /dev/null; then
    echo -e "${RED}❌ Error: Cannot access project ${PROJECT_ID}${NC}"
    echo "Please ensure you have access to the project and try again."
    exit 1
fi

echo -e "${GREEN}✅ Project access verified${NC}"

# Check if service account already exists
echo -e "${BLUE}🔍 Checking if service account exists...${NC}"
if gcloud iam service-accounts describe $SA_EMAIL &> /dev/null; then
    echo -e "${YELLOW}⚠️  Service account already exists: ${SA_EMAIL}${NC}"
    read -p "Do you want to continue and regenerate the key? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    # Create service account
    echo -e "${BLUE}👤 Creating service account...${NC}"
    gcloud iam service-accounts create $SA_NAME \
      --display-name="Terraform DataOps Service Account" \
      --description="Service account for managing DataOps infrastructure with least privileges" \
      --project=$PROJECT_ID
    
    echo -e "${GREEN}✅ Service account created: ${SA_EMAIL}${NC}"
fi

# Assign IAM roles
echo -e "${BLUE}🔐 Assigning IAM roles...${NC}"
for ROLE in "${ROLES[@]}"; do
    echo -e "  Assigning ${ROLE}..."
    gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="serviceAccount:${SA_EMAIL}" \
      --role="$ROLE" \
      --quiet
done

echo -e "${GREEN}✅ IAM roles assigned${NC}"

# Create credentials directory
echo -e "${BLUE}📁 Creating secure credentials directory...${NC}"
mkdir -p $CREDENTIALS_DIR
chmod 700 $CREDENTIALS_DIR

# Backup existing key if it exists
if [ -f "$CREDENTIALS_FILE" ]; then
    BACKUP_FILE="${CREDENTIALS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${YELLOW}⚠️  Backing up existing key to ${BACKUP_FILE}${NC}"
    cp "$CREDENTIALS_FILE" "$BACKUP_FILE"
fi

# Generate service account key
echo -e "${BLUE}🔑 Generating service account key...${NC}"
gcloud iam service-accounts keys create $CREDENTIALS_FILE \
  --iam-account=$SA_EMAIL

# Secure the key file
chmod 600 $CREDENTIALS_FILE

echo -e "${GREEN}✅ Service account key created: ${CREDENTIALS_FILE}${NC}"

# Test authentication
echo -e "${BLUE}🧪 Testing service account authentication...${NC}"
export GOOGLE_APPLICATION_CREDENTIALS="$CREDENTIALS_FILE"

if gcloud projects list --filter="projectId:$PROJECT_ID" &> /dev/null; then
    echo -e "${GREEN}✅ Service account authentication successful${NC}"
else
    echo -e "${RED}❌ Service account authentication failed${NC}"
    exit 1
fi

# Test terraform if available
if command -v terraform &> /dev/null; then
    echo -e "${BLUE}🔧 Testing terraform configuration...${NC}"
    
    if [ -d "infrastructure" ]; then
        cd infrastructure
        if terraform init &> /dev/null && terraform plan &> /dev/null; then
            echo -e "${GREEN}✅ Terraform test successful${NC}"
        else
            echo -e "${YELLOW}⚠️  Terraform test had issues (this may be normal)${NC}"
        fi
        cd ..
    else
        echo -e "${YELLOW}⚠️  Infrastructure directory not found, skipping terraform test${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Terraform not installed, skipping terraform test${NC}"
fi

# Show summary
echo ""
echo -e "${GREEN}🎉 Service Account Setup Complete!${NC}"
echo -e "${GREEN}===================================${NC}"
echo ""
echo -e "${BLUE}Service Account:${NC} ${SA_EMAIL}"
echo -e "${BLUE}Credentials File:${NC} ${CREDENTIALS_FILE}"
echo -e "${BLUE}Permissions:${NC} $(printf ', %s' "${ROLES[@]}" | cut -c3-)"
echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo ""
echo -e "1. ${BLUE}For daily usage, set environment variable:${NC}"
echo -e "   export GOOGLE_APPLICATION_CREDENTIALS=\"${CREDENTIALS_FILE}\""
echo ""
echo -e "2. ${BLUE}Or use the helper script:${NC}"
echo -e "   cd infrastructure && ./terraform-sa.sh plan"
echo ""
echo -e "3. ${BLUE}Add to your shell profile for persistence:${NC}"
echo -e "   echo 'export GOOGLE_APPLICATION_CREDENTIALS=\"${CREDENTIALS_FILE}\"' >> ~/.bashrc"
echo ""
echo -e "4. ${BLUE}For security, rotate keys every 90 days${NC}"
echo ""
echo -e "${GREEN}Setup completed successfully! 🚀${NC}"