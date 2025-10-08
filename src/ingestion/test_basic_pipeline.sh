#!/bin/bash

# Test Basic Pipeline Script
# Comprehensive test script for IoT telemetry pipeline testing
# Tests both local (DirectRunner) and GCP (DataflowRunner) deployments

set -e  # Exit on any error

# Configuration
PROJECT_ID="manish-sandpit"
REGION="us-central1"
TOPIC="iot-telemetry"
SUBSCRIPTION="iot-telemetry-subscription"
PROJECT_ROOT="/Users/manisharora/Projects/Intelligent_DataOps_proj"
BEAM_ENV_PATH="$PROJECT_ROOT/venv_beam_312"
DEV_ENV_PATH="$PROJECT_ROOT/venv_dataops"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if gcloud is installed and authenticated
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI not found. Please install Google Cloud SDK."
        exit 1
    fi
    
    # Check if authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "."; then
        log_error "Not authenticated with gcloud. Run: gcloud auth login"
        exit 1
    fi
    
    # Check if credentials are set
    if [[ -z "$GOOGLE_APPLICATION_CREDENTIALS" ]]; then
        log_warning "GOOGLE_APPLICATION_CREDENTIALS not set. Setting to default..."
        export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/credentials/terraform-dataops-key.json"
    fi
    
    # Check if credentials file exists
    if [[ ! -f "$GOOGLE_APPLICATION_CREDENTIALS" ]]; then
        log_error "Credentials file not found: $GOOGLE_APPLICATION_CREDENTIALS"
        exit 1
    fi
    
    # Check if virtual environments exist
    if [[ ! -d "$BEAM_ENV_PATH" ]]; then
        log_error "Apache Beam environment not found at $BEAM_ENV_PATH"
        log_info "Run: ./setup_beam_env.sh"
        exit 1
    fi
    
    if [[ ! -d "$DEV_ENV_PATH" ]]; then
        log_error "Development environment not found at $DEV_ENV_PATH"
        exit 1
    fi
    
    # Set gcloud project
    gcloud config set project $PROJECT_ID
    
    log_success "Prerequisites check completed"
}

# Function to generate test data
generate_test_data() {
    local batch_size=${1:-5}
    log_info "Generating $batch_size test IoT events..."
    
    # Activate development environment for data generation
    source "$DEV_ENV_PATH/bin/activate"
    
    # Generate test data
    python test_data_generator.py \
        --project $PROJECT_ID \
        --topic $TOPIC \
        --batch-size $batch_size
    
    log_success "Generated $batch_size test events and published to Pub/Sub topic: $TOPIC"
    deactivate
}

# Function to test local pipeline
test_local_pipeline() {
    log_info "Testing pipeline locally with DirectRunner..."
    
    # Kill any existing background processes
    pkill -f "deploy_pipeline.sh local" 2>/dev/null || true
    sleep 2
    
    # Run local pipeline in background for limited time
    timeout 60s ./deploy_pipeline.sh local &
    LOCAL_PID=$!
    
    log_info "Local pipeline started (PID: $LOCAL_PID), running for 60 seconds..."
    
    # Wait for pipeline to process data
    wait $LOCAL_PID 2>/dev/null || true
    
    log_success "Local pipeline test completed"
}

# Function to test GCP pipeline
test_gcp_pipeline() {
    log_info "Testing pipeline on Google Cloud with DataflowRunner..."
    
    # Get list of existing jobs to avoid cancelling them
    EXISTING_JOBS=$(gcloud dataflow jobs list \
        --project=$PROJECT_ID \
        --region=$REGION \
        --status=active \
        --format="value(job_id)")
    
    if [[ -n "$EXISTING_JOBS" ]]; then
        log_warning "Found existing active jobs. Will only cancel the job created by this test."
        log_info "Existing jobs: $(echo $EXISTING_JOBS | tr '\n' ' ')"
    fi
    
    # Deploy to GCP and capture output to extract job ID
    log_info "Deploying pipeline to GCP..."
    DEPLOY_OUTPUT=$(./deploy_pipeline.sh 2>&1)
    echo "$DEPLOY_OUTPUT"
    
    # Extract job ID from deployment output
    CREATED_JOB_ID=$(echo "$DEPLOY_OUTPUT" | grep -o "job with id: \[[^]]*\]" | sed 's/job with id: \[\([^]]*\)\]/\1/')
    
    if [[ -z "$CREATED_JOB_ID" ]]; then
        # Fallback: try to extract from console URL
        CREATED_JOB_ID=$(echo "$DEPLOY_OUTPUT" | grep -o "jobs/[^/]*/[^?]*" | sed 's/jobs\/[^\/]*\///')
    fi
    
    if [[ -n "$CREATED_JOB_ID" ]]; then
        log_success "Pipeline deployed successfully with Job ID: $CREATED_JOB_ID"
        log_info "Monitor at: https://console.cloud.google.com/dataflow/jobs/$REGION/$CREATED_JOB_ID?project=$PROJECT_ID"
        
        # Wait for job to start and process some data
        log_info "Waiting for pipeline to start and process data..."
        sleep 60
        
        # Verify the job is still running and belongs to us
        JOB_STATUS=$(gcloud dataflow jobs describe $CREATED_JOB_ID \
            --project=$PROJECT_ID \
            --region=$REGION \
            --format="value(currentState)" 2>/dev/null || echo "NOT_FOUND")
        
        if [[ "$JOB_STATUS" == "JOB_STATE_RUNNING" ]] || [[ "$JOB_STATUS" == "JOB_STATE_PENDING" ]]; then
            # Wait a bit more for processing
            sleep 30
            
            # Cancel only our created job
            log_info "Cancelling our test job ($CREATED_JOB_ID) to avoid ongoing costs..."
            gcloud dataflow jobs cancel $CREATED_JOB_ID --region=$REGION
            log_success "Test job cancelled successfully"
        elif [[ "$JOB_STATUS" == "NOT_FOUND" ]]; then
            log_error "Created job not found. It may have failed to start."
            return 1
        else
            log_info "Job is in state: $JOB_STATUS (not running, no need to cancel)"
        fi
    else
        log_error "Could not extract job ID from deployment output"
        log_info "Please check for any active jobs manually:"
        gcloud dataflow jobs list --project=$PROJECT_ID --region=$REGION --status=active
        return 1
    fi
}

# Function to verify data in BigQuery
verify_bigquery_data() {
    log_info "Verifying data in BigQuery..."
    
    # Query recent data
    QUERY="
    SELECT 
        vehicle_id,
        timestamp,
        speed_kmh,
        speed_category,
        processed_at,
        data_quality_score
    FROM \`$PROJECT_ID.intelligent_dataops_analytics.iot_telemetry\` 
    WHERE processed_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 10 MINUTE)
    ORDER BY processed_at DESC
    LIMIT 10
    "
    
    RESULT=$(bq query --use_legacy_sql=false --format=csv --max_rows=10 "$QUERY")
    
    if echo "$RESULT" | grep -q "vehicle_id"; then
        log_success "Data verification successful. Recent records found:"
        echo "$RESULT" | head -6
        
        # Count total records
        COUNT_QUERY="SELECT COUNT(*) as total_records FROM \`$PROJECT_ID.intelligent_dataops_analytics.iot_telemetry\` WHERE processed_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 10 MINUTE)"
        RECORD_COUNT=$(bq query --use_legacy_sql=false --format=csv --quiet "$COUNT_QUERY" | tail -1)
        log_info "Total records processed in last 10 minutes: $RECORD_COUNT"
    else
        log_warning "No recent data found in BigQuery"
    fi
}

# Function to cleanup
cleanup() {
    log_info "Cleaning up background processes..."
    pkill -f "deploy_pipeline.sh" 2>/dev/null || true
    pkill -f "basic_pipeline.py" 2>/dev/null || true
}

# Main execution function
main() {
    local test_mode=${1:-"both"}
    local data_batch_size=${2:-5}
    
    echo "=========================================="
    echo "🚀 IoT Telemetry Pipeline Test Suite"
    echo "=========================================="
    echo "Mode: $test_mode"
    echo "Data batch size: $data_batch_size"
    echo "Project: $PROJECT_ID"
    echo "Region: $REGION"
    echo "=========================================="
    
    # Set trap for cleanup on exit
    trap cleanup EXIT
    
    # Navigate to ingestion directory
    cd "$PROJECT_ROOT/src/ingestion"
    
    # Run tests based on mode
    case $test_mode in
        "local")
            check_prerequisites
            generate_test_data $data_batch_size
            test_local_pipeline
            verify_bigquery_data
            ;;
        "gcp"|"cloud")
            check_prerequisites
            generate_test_data $data_batch_size
            test_gcp_pipeline
            verify_bigquery_data
            ;;
        "both"|"full")
            check_prerequisites
            generate_test_data $data_batch_size
            log_info "Testing local pipeline first..."
            test_local_pipeline
            sleep 5
            log_info "Now testing GCP pipeline..."
            test_gcp_pipeline
            verify_bigquery_data
            ;;
        *)
            log_error "Invalid test mode: $test_mode"
            log_info "Usage: $0 [local|gcp|both] [batch_size]"
            log_info "Examples:"
            log_info "  $0 local 3      # Test locally with 3 messages"
            log_info "  $0 gcp 5        # Test on GCP with 5 messages"
            log_info "  $0 both 10      # Test both with 10 messages"
            exit 1
            ;;
    esac
    
    echo "=========================================="
    log_success "Pipeline testing completed successfully!"
    echo "=========================================="
}

# Script usage information
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "IoT Telemetry Pipeline Test Script"
    echo ""
    echo "Usage: $0 [MODE] [BATCH_SIZE]"
    echo ""
    echo "MODES:"
    echo "  local    - Test with DirectRunner only"
    echo "  gcp      - Test with DataflowRunner on Google Cloud"
    echo "  both     - Test both local and GCP (default)"
    echo ""
    echo "BATCH_SIZE:"
    echo "  Number of test messages to generate (default: 5)"
    echo ""
    echo "Examples:"
    echo "  $0                  # Full test with 5 messages"
    echo "  $0 local 3          # Local test with 3 messages"
    echo "  $0 gcp 10           # GCP test with 10 messages"
    echo ""
    echo "Prerequisites:"
    echo "  - gcloud CLI authenticated"
    echo "  - Virtual environments set up (venv_dataops, venv_beam_312)"
    echo "  - GOOGLE_APPLICATION_CREDENTIALS set"
    exit 0
fi

# Execute main function with all arguments
main "$@"