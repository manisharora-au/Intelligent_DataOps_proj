#!/bin/bash

# =============================================================================
# BigQuery Data Warehouse Deployment Script
# =============================================================================
# Purpose: Deploy all BigQuery tables in correct dependency order
# Usage: ./deploy_all_tables.sh [PROJECT_ID] [DATASET_NAME]
# =============================================================================

set -e  # Exit on any error

# Configuration
DEFAULT_PROJECT_ID="manish-sandpit"
DEFAULT_DATASET="intelligent_dataops_analytics"
PROJECT_ID="${1:-$DEFAULT_PROJECT_ID}"
DATASET="${2:-$DEFAULT_DATASET}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# GCP command logging (following CLAUDE.md guidelines)
LOG_DIR="../../../logs"
LOG_FILE="$LOG_DIR/bigquery-deployment-$(date +%Y-%m-%d).log"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Logging function for GCP commands
log_gcp_command() {
    local cmd_type="$1"
    local command="$2"
    local result="$3"
    local context="$4"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $cmd_type: $command" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] RESULT: $result" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] CONTEXT: $context" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

echo "=============================================="
echo "🏗️  BigQuery Data Warehouse Deployment"
echo "=============================================="
echo "Project: $PROJECT_ID"
echo "Dataset: $DATASET"
echo "Timestamp: $(date)"
echo "=============================================="
echo ""

# Check prerequisites
log_info "Checking prerequisites..."

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    log_error "gcloud CLI not found. Please install Google Cloud SDK."
    exit 1
fi

# Set up service account authentication
SERVICE_ACCOUNT_KEY="$HOME/.gcp/credentials/terraform-dataops-key.json"
if [[ ! -f "$SERVICE_ACCOUNT_KEY" ]]; then
    log_error "Service account key not found at: $SERVICE_ACCOUNT_KEY"
    log_error "Please ensure the service account key file exists."
    exit 1
fi

log_info "Authenticating with service account..."
gcloud auth activate-service-account --key-file="$SERVICE_ACCOUNT_KEY" --quiet
if [[ $? -ne 0 ]]; then
    log_error "Failed to authenticate with service account"
    exit 1
fi
log_success "Service account authentication successful"

# Check if bq command is available
if ! command -v bq &> /dev/null; then
    log_error "BigQuery CLI (bq) not found. Please install or update Google Cloud SDK."
    exit 1
fi

# Set the project
log_info "Setting GCP project to: $PROJECT_ID"
gcloud config set project "$PROJECT_ID" --quiet
log_gcp_command "GCLOUD" "gcloud config set project $PROJECT_ID" "SUCCESS" "deploy_all_tables.sh - project setup via service account"

# Check if dataset exists, create if not
log_info "Checking if dataset exists: $DATASET"
if ! bq ls -d --project_id="$PROJECT_ID" | grep -q "$DATASET"; then
    log_warning "Dataset $DATASET not found. Creating..."
    
    bq mk \
        --project_id="$PROJECT_ID" \
        --dataset \
        --description="Intelligent DataOps Analytics Data Warehouse" \
        --location="US" \
        --default_table_expiration=0 \
        --default_partition_expiration=220752000 \
        --labels=environment:production,purpose:analytics \
        "$PROJECT_ID:$DATASET"
    
    log_gcp_command "BQ" "bq mk --dataset $PROJECT_ID:$DATASET" "SUCCESS" "Dataset creation for data warehouse"
    log_success "Dataset created: $DATASET"
else
    log_success "Dataset exists: $DATASET"
fi

echo ""
log_info "Starting table deployment in dependency order..."
echo ""

# =============================================================================
# Step 1: Deploy Dimension Tables (No dependencies)
# =============================================================================

log_info "📋 Step 1: Deploying Dimension Tables..."
if bq query \
    --project_id="$PROJECT_ID" \
    --use_legacy_sql=false \
    --max_rows=0 \
    --quiet \
    < create_dimension_tables.sql; then
    
    log_gcp_command "BQ" "bq query < create_dimension_tables.sql" "SUCCESS" "Dimension tables deployment"
    log_success "✅ Dimension tables deployed successfully"
else
    log_gcp_command "BQ" "bq query < create_dimension_tables.sql" "FAILED" "Dimension tables deployment"
    log_error "❌ Failed to deploy dimension tables"
    exit 1
fi

# =============================================================================
# Step 2: Deploy Fact Tables (Depend on dimension tables)
# =============================================================================

log_info "📊 Step 2: Deploying Fact Tables..."
if bq query \
    --project_id="$PROJECT_ID" \
    --use_legacy_sql=false \
    --max_rows=0 \
    --quiet \
    < create_fact_tables.sql; then
    
    log_gcp_command "BQ" "bq query < create_fact_tables.sql" "SUCCESS" "Fact tables deployment"
    log_success "✅ Fact tables deployed successfully"
else
    log_gcp_command "BQ" "bq query < create_fact_tables.sql" "FAILED" "Fact tables deployment"
    log_error "❌ Failed to deploy fact tables"
    exit 1
fi

# =============================================================================
# Step 3: Deploy Aggregation Tables (Depend on fact tables)
# =============================================================================

log_info "📈 Step 3: Deploying Aggregation Tables..."
if bq query \
    --project_id="$PROJECT_ID" \
    --use_legacy_sql=false \
    --max_rows=0 \
    --quiet \
    < create_aggregation_tables.sql; then
    
    log_gcp_command "BQ" "bq query < create_aggregation_tables.sql" "SUCCESS" "Aggregation tables deployment"
    log_success "✅ Aggregation tables deployed successfully"
else
    log_gcp_command "BQ" "bq query < create_aggregation_tables.sql" "FAILED" "Aggregation tables deployment"
    log_error "❌ Failed to deploy aggregation tables"
    exit 1
fi

# =============================================================================
# Step 4: Deploy ML Feature Tables (Depend on fact and dimension tables)
# =============================================================================

log_info "🤖 Step 4: Deploying ML Feature Tables..."
if bq query \
    --project_id="$PROJECT_ID" \
    --use_legacy_sql=false \
    --max_rows=0 \
    --quiet \
    < create_ml_feature_tables.sql; then
    
    log_gcp_command "BQ" "bq query < create_ml_feature_tables.sql" "SUCCESS" "ML feature tables deployment"
    log_success "✅ ML Feature tables deployed successfully"
else
    log_gcp_command "BQ" "bq query < create_ml_feature_tables.sql" "FAILED" "ML feature tables deployment"
    log_error "❌ Failed to deploy ML feature tables"
    exit 1
fi

# =============================================================================
# Verification and Summary
# =============================================================================

log_info "🔍 Verifying deployment..."
echo ""

# Count total tables created
TABLE_COUNT=$(bq ls --project_id="$PROJECT_ID" "$DATASET" | grep -c "TABLE" || echo "0")
VIEW_COUNT=$(bq ls --project_id="$PROJECT_ID" "$DATASET" | grep -c "VIEW" || echo "0")

log_gcp_command "BQ" "bq ls $PROJECT_ID:$DATASET" "SUCCESS - $TABLE_COUNT tables, $VIEW_COUNT views" "Deployment verification"

# List all created tables
log_info "Tables created in dataset $DATASET:"
bq ls --project_id="$PROJECT_ID" "$DATASET" | grep -E "(TABLE|VIEW)" | while read -r line; do
    table_name=$(echo "$line" | awk '{print $1}')
    table_type=$(echo "$line" | awk '{print $2}')
    echo "  ✓ $table_name ($table_type)"
done

echo ""
echo "=============================================="
log_success "🎉 BigQuery Data Warehouse Deployment Complete!"
echo "=============================================="
echo "📊 Tables deployed: $TABLE_COUNT"
echo "📋 Views created: $VIEW_COUNT"
echo "🏗️  Dataset: $PROJECT_ID:$DATASET"
echo "📅 Deployment time: $(date)"
echo "📝 Logs written to: $LOG_FILE"
echo ""
echo "🔗 Access your data warehouse:"
echo "   https://console.cloud.google.com/bigquery?project=$PROJECT_ID"
echo ""
echo "📈 Next steps:"
echo "   1. Set up data ingestion pipelines"
echo "   2. Create initial dimension data"
echo "   3. Configure aggregation jobs"
echo "   4. Build ML feature pipelines"
echo "=============================================="