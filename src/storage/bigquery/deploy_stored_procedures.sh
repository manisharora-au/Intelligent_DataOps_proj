#!/bin/bash

# =============================================================================
# BigQuery Stored Procedures Deployment Script
# =============================================================================
# Purpose: Deploy all BigQuery stored procedures in correct dependency order
# Usage: ./deploy_stored_procedures.sh [PROJECT_ID] [DATASET_NAME]
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
LOG_FILE="$LOG_DIR/bigquery-procedures-$(date +%Y-%m-%d).log"

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
echo "🔧 BigQuery Stored Procedures Deployment"
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
log_gcp_command "GCLOUD" "gcloud config set project $PROJECT_ID" "SUCCESS" "deploy_stored_procedures.sh - project setup via service account"

# Check if dataset exists
log_info "Checking if dataset exists: $DATASET"
if ! bq ls -d --project_id="$PROJECT_ID" | grep -q "$DATASET"; then
    log_error "Dataset $DATASET not found. Please run deploy_all_tables.sh first."
    exit 1
else
    log_success "Dataset exists: $DATASET"
fi

echo ""
log_info "Starting stored procedures deployment in dependency order..."
echo ""

# =============================================================================
# Step 1: Create ETL Logging Infrastructure
# =============================================================================

log_info "🔍 Step 1: Creating ETL Logging Infrastructure..."
if bq query \
    --project_id="$PROJECT_ID" \
    --use_legacy_sql=false \
    --max_rows=0 \
    --quiet \
    < create_etl_log_table.sql; then
    
    log_gcp_command "BQ" "bq query < create_etl_log_table.sql" "SUCCESS" "ETL logging infrastructure creation"
    log_success "✅ ETL logging infrastructure created successfully"
else
    log_gcp_command "BQ" "bq query < create_etl_log_table.sql" "FAILED" "ETL logging infrastructure creation"
    log_error "❌ Failed to create ETL logging infrastructure"
    exit 1
fi

# =============================================================================
# Step 2: Deploy Dimension Loading Procedure
# =============================================================================

log_info "📋 Step 2: Deploying Dimension Loading Procedure..."
if bq query \
    --project_id="$PROJECT_ID" \
    --use_legacy_sql=false \
    --max_rows=0 \
    --quiet \
    < sp_load_dimensions.sql; then
    
    log_gcp_command "BQ" "bq query < sp_load_dimensions.sql" "SUCCESS" "Dimension loading procedure deployment"
    log_success "✅ Dimension loading procedure deployed successfully"
else
    log_gcp_command "BQ" "bq query < sp_load_dimensions.sql" "FAILED" "Dimension loading procedure deployment"
    log_error "❌ Failed to deploy dimension loading procedure"
    exit 1
fi

# =============================================================================
# Step 3: Deploy IoT Telemetry Loading Procedure
# =============================================================================

log_info "📡 Step 3: Deploying IoT Telemetry Loading Procedure..."
if bq query \
    --project_id="$PROJECT_ID" \
    --use_legacy_sql=false \
    --max_rows=0 \
    --quiet \
    < sp_load_iot_telemetry.sql; then
    
    log_gcp_command "BQ" "bq query < sp_load_iot_telemetry.sql" "SUCCESS" "IoT telemetry loading procedure deployment"
    log_success "✅ IoT telemetry loading procedure deployed successfully"
else
    log_gcp_command "BQ" "bq query < sp_load_iot_telemetry.sql" "FAILED" "IoT telemetry loading procedure deployment"
    log_error "❌ Failed to deploy IoT telemetry loading procedure"
    exit 1
fi

# =============================================================================
# Step 4: Deploy Daily Summaries Generation Procedure
# =============================================================================

log_info "📊 Step 4: Deploying Daily Summaries Generation Procedure..."
if bq query \
    --project_id="$PROJECT_ID" \
    --use_legacy_sql=false \
    --max_rows=0 \
    --quiet \
    < sp_generate_daily_summaries.sql; then
    
    log_gcp_command "BQ" "bq query < sp_generate_daily_summaries.sql" "SUCCESS" "Daily summaries generation procedure deployment"
    log_success "✅ Daily summaries generation procedure deployed successfully"
else
    log_gcp_command "BQ" "bq query < sp_generate_daily_summaries.sql" "FAILED" "Daily summaries generation procedure deployment"
    log_error "❌ Failed to deploy daily summaries generation procedure"
    exit 1
fi

# =============================================================================
# Step 5: Deploy ML Features Update Procedure
# =============================================================================

log_info "🤖 Step 5: Deploying ML Features Update Procedure..."
if bq query \
    --project_id="$PROJECT_ID" \
    --use_legacy_sql=false \
    --max_rows=0 \
    --quiet \
    < sp_update_ml_features.sql; then
    
    log_gcp_command "BQ" "bq query < sp_update_ml_features.sql" "SUCCESS" "ML features update procedure deployment"
    log_success "✅ ML features update procedure deployed successfully"
else
    log_gcp_command "BQ" "bq query < sp_update_ml_features.sql" "FAILED" "ML features update procedure deployment"
    log_error "❌ Failed to deploy ML features update procedure"
    exit 1
fi

# =============================================================================
# Verification and Summary
# =============================================================================

log_info "🔍 Verifying deployment..."
echo ""

# Count stored procedures created
PROCEDURE_COUNT=$(bq ls --project_id="$PROJECT_ID" --routines "$DATASET" | grep -c "PROCEDURE" || echo "0")
VIEW_COUNT=$(bq ls --project_id="$PROJECT_ID" "$DATASET" | grep -c "VIEW" || echo "0")

log_gcp_command "BQ" "bq ls --routines $PROJECT_ID:$DATASET" "SUCCESS - $PROCEDURE_COUNT procedures" "Stored procedures verification"

# List all created procedures
log_info "Stored procedures created in dataset $DATASET:"
bq ls --project_id="$PROJECT_ID" --routines "$DATASET" | grep "PROCEDURE" | while read -r line; do
    procedure_name=$(echo "$line" | awk '{print $1}')
    echo "  ✓ $procedure_name (PROCEDURE)"
done

# List ETL monitoring views
log_info "ETL monitoring views created:"
bq ls --project_id="$PROJECT_ID" "$DATASET" | grep -E "(etl_status_today|etl_performance_trend|etl_errors_recent)" | while read -r line; do
    view_name=$(echo "$line" | awk '{print $1}')
    view_type=$(echo "$line" | awk '{print $2}')
    echo "  ✓ $view_name ($view_type)"
done

echo ""
echo "=============================================="
log_success "🎉 BigQuery Stored Procedures Deployment Complete!"
echo "=============================================="
echo "🔧 Procedures deployed: $PROCEDURE_COUNT"
echo "📊 Monitoring views: $VIEW_COUNT"
echo "🏗️  Dataset: $PROJECT_ID:$DATASET"
echo "📅 Deployment time: $(date)"
echo "📝 Logs written to: $LOG_FILE"
echo ""
echo "🔗 Access your procedures:"
echo "   https://console.cloud.google.com/bigquery?project=$PROJECT_ID"
echo ""
echo "📋 Usage examples:"
echo "   CALL \`$PROJECT_ID.$DATASET.sp_load_dimensions\`();"
echo "   CALL \`$PROJECT_ID.$DATASET.sp_load_iot_telemetry\`('2024-01-01', 1000);"
echo "   CALL \`$PROJECT_ID.$DATASET.sp_generate_daily_summaries\`('2024-01-01');"
echo "   CALL \`$PROJECT_ID.$DATASET.sp_update_ml_features\`('2024-01-01', 30);"
echo ""
echo "🔍 Monitor execution with:"
echo "   SELECT * FROM \`$PROJECT_ID.$DATASET.etl_status_today\`;"
echo "   SELECT * FROM \`$PROJECT_ID.$DATASET.etl_performance_trend\` LIMIT 10;"
echo "=============================================="