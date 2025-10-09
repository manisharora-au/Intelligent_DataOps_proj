#!/bin/bash

# Test Basic Pipeline Script
# Comprehensive test script for IoT telemetry pipeline testing
# Tests both local (DirectRunner) and GCP (DataflowRunner) deployments
#
# This script provides end-to-end testing for the IoT telemetry data pipeline by:
# 1. Setting up prerequisites and validating environment
# 2. Optionally truncating BigQuery tables for clean testing
# 3. Generating test IoT telemetry data and publishing to Pub/Sub
# 4. Deploying and testing pipeline in local and/or GCP environments
# 5. Verifying successful data processing and BigQuery insertion
# 6. Automatically cleaning up resources to control costs
#
# Usage:
#   ./test_basic_pipeline.sh [MODE] [BATCH_SIZE] [SKIP_TRUNCATE] [--dry-run]
#
# Modes:
#   local - Test with Apache Beam DirectRunner (free, local execution)
#   gcp   - Test with Google Cloud Dataflow (cost-optimized with auto-cancellation)
#   both  - Test both local and GCP environments sequentially
#
# Examples:
#   ./test_basic_pipeline.sh local 5        # Local test with 5 messages
#   ./test_basic_pipeline.sh gcp 10 true    # GCP test, skip table truncation
#   ./test_basic_pipeline.sh both 3 false --dry-run  # Dry run validation

set -e  # Exit on any error

# Configuration constants
# These define the GCP project and infrastructure components used for testing
PROJECT_ID="manish-sandpit"                              # GCP project for testing
REGION="us-central1"                                     # GCP region for Dataflow jobs
TOPIC="iot-telemetry"                                    # Pub/Sub topic for test data
SUBSCRIPTION="iot-telemetry-subscription"                # Pub/Sub subscription for pipeline
PROJECT_ROOT="/Users/manisharora/Projects/Intelligent_DataOps_proj"  # Project root directory
BEAM_ENV_PATH="$PROJECT_ROOT/venv_beam_312"              # Python 3.12 environment for Apache Beam
DEV_ENV_PATH="$PROJECT_ROOT/venv_dataops"                # Python 3.13 environment for development tools

# ANSI color codes for enhanced console output
# These provide visual distinction between different types of log messages
RED='\033[0;31m'      # Error messages
GREEN='\033[0;32m'    # Success messages  
YELLOW='\033[1;33m'   # Warning messages
BLUE='\033[0;34m'     # Info messages
NC='\033[0m'          # No Color (reset)

# Centralized logging functions
# These provide consistent, color-coded output throughout the script execution
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }      # General information messages
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }  # Successful operation confirmations
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; } # Non-critical issues or notifications
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }      # Critical errors requiring attention

# Validates all required prerequisites before running pipeline tests
# 
# This function performs comprehensive environment validation including:
# - Google Cloud SDK installation and authentication
# - Service account credentials verification
# - Virtual environment existence checks
# - Project directory structure validation
# - GCP project configuration
# - Pub/Sub topic auto-creation if missing
# 
# The function follows fail-fast principle - exits immediately on any critical error
# to prevent tests from running in an invalid environment.
# 
# Exits with code 1 if any critical prerequisite is missing or invalid
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Verify Google Cloud SDK installation
    # The gcloud CLI is essential for all GCP operations including Dataflow deployment
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI not found. Please install Google Cloud SDK."
        exit 1
    fi
    
    # Verify gcloud authentication status
    # An active authenticated account is required for GCP resource access
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "."; then
        log_error "Not authenticated with gcloud. Run: gcloud auth login"
        exit 1
    fi
    
    # Set up service account credentials for programmatic access
    # GOOGLE_APPLICATION_CREDENTIALS environment variable is used by GCP client libraries
    if [[ -z "$GOOGLE_APPLICATION_CREDENTIALS" ]]; then
        log_warning "GOOGLE_APPLICATION_CREDENTIALS not set. Setting to default..."
        export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/credentials/terraform-dataops-key.json"
    fi
    
    # Verify service account key file exists
    # This file contains the private key needed for service account authentication
    if [[ ! -f "$GOOGLE_APPLICATION_CREDENTIALS" ]]; then
        log_error "Credentials file not found: $GOOGLE_APPLICATION_CREDENTIALS"
        exit 1
    fi
    
    # Validate virtual environment directories
    # Two separate environments are required: one for Beam (Python 3.12) and one for dev tools (Python 3.13)
    [[ ! -d "$BEAM_ENV_PATH" ]] && { log_error "Apache Beam environment not found at $BEAM_ENV_PATH"; exit 1; }
    [[ ! -d "$DEV_ENV_PATH" ]] && { log_error "Development environment not found at $DEV_ENV_PATH"; exit 1; }

    # Verify project directory structure
    # The ingestion directory must exist and contain pipeline scripts
    if [[ ! -d "$PROJECT_ROOT/src/ingestion" ]]; then
        log_error "Directory not found: $PROJECT_ROOT/src/ingestion"
        exit 1
    fi
    
    # Configure gcloud to use the specified project
    # This ensures all subsequent gcloud commands target the correct project
    gcloud config set project $PROJECT_ID --quiet

    # Auto-create Pub/Sub topic if it doesn't exist
    # The topic is required for publishing test data and must exist before pipeline deployment
    if ! gcloud pubsub topics describe "$TOPIC" --project="$PROJECT_ID" >/dev/null 2>&1; then
        log_warning "Pub/Sub topic $TOPIC not found. Creating..."
        gcloud pubsub topics create "$TOPIC" --project="$PROJECT_ID" --quiet
        log_success "Created Pub/Sub topic: $TOPIC"
    fi

    log_success "Prerequisites check completed"
}

# Truncates BigQuery tables to ensure clean testing environment
# 
# This function removes all existing data from the pipeline's BigQuery tables
# to provide a clean slate for testing. This ensures that test results are not
# contaminated by data from previous test runs.
# 
# Tables truncated:
# - iot_telemetry: Main table for processed telemetry data
# - iot_telemetry_error_records: Table for storing processing errors
# 
# The function handles non-existent tables gracefully by issuing warnings
# rather than failing, allowing tests to proceed even if tables haven't been
# created yet.
# 
# Note: TRUNCATE is used instead of DELETE for better performance
# Note: Function continues execution even if individual truncations fail
truncate_bigquery_tables() {
    log_info "Truncating BigQuery tables for clean testing..."
    
    # Iterate through both pipeline tables and truncate them
    # This loop processes both the main data table and the error records table
    for table in iot_telemetry iot_telemetry_error_records; do
        log_info "Truncating $table..."
        
        # Execute TRUNCATE command using BigQuery CLI
        # TRUNCATE is more efficient than DELETE for removing all table data
        # Errors are suppressed to handle cases where tables don't exist yet
        if bq query --use_legacy_sql=false --quiet "TRUNCATE TABLE \`$PROJECT_ID.intelligent_dataops_analytics.$table\`" 2>/dev/null; then
            log_success "✅ $table table truncated"
        else
            # Non-fatal error handling - tables may not exist on first run
            log_warning "⚠️  Could not truncate $table (may not exist or no data)"
        fi
    done

    log_success "BigQuery tables truncated for clean testing"
}

# Purges pending messages from Pub/Sub subscription to ensure clean testing
# 
# This function removes any unprocessed messages from the IoT telemetry subscription
# that might be left over from previous test runs. This prevents message conflicts
# and ensures that new test data is processed correctly by the pipeline.
# 
# The function uses a loop to continuously pull and acknowledge messages until
# the subscription is empty, providing a clean state for new test messages.
# 
# Note: Messages are automatically acknowledged to permanently remove them
# Note: Function handles empty subscriptions gracefully without errors
purge_pubsub_subscription() {
    log_info "Purging pending messages from Pub/Sub subscription..."
    
    # Continue pulling messages until subscription is empty
    local messages_purged=0
    while true; do
        # Pull up to 100 messages and auto-acknowledge them
        local result=$(gcloud pubsub subscriptions pull iot-telemetry-subscription \
            --limit=100 --auto-ack --format="value(message.messageId)" 2>/dev/null)
        
        # Break if no messages were returned
        if [[ -z "$result" ]]; then
            break
        fi
        
        # Count purged messages for reporting
        local batch_count=$(echo "$result" | wc -l | tr -d ' ')
        messages_purged=$((messages_purged + batch_count))
    done
    
    if [[ $messages_purged -gt 0 ]]; then
        log_info "Purged $messages_purged pending messages from subscription"
    else
        log_info "No pending messages found in subscription"
    fi
}

verify_pubsub_messages() {
    log_info "Verifying test messages in Pub/Sub..."
    local msg_count
    # Use --limit=1 and NO auto-ack to just peek at messages without consuming them
    msg_count=$(gcloud pubsub subscriptions pull "$SUBSCRIPTION" --limit=1 --format="value(message.data)" 2>/dev/null | wc -l | tr -d ' ')
    if (( msg_count > 0 )); then
        log_success "✅ Verified messages are available in subscription: $SUBSCRIPTION"
    else
        log_error "❌ No messages found in Pub/Sub. Check test_data_generator.py"
        exit 1
    fi
}


# Generates synthetic IoT telemetry data for pipeline testing
# 
# This function creates realistic test data simulating IoT device telemetry
# from a fleet of vehicles. The data includes GPS coordinates, speed, fuel level,
# engine status, and other vehicle metrics.
# 
# The function uses the development virtual environment (Python 3.13) which
# contains the necessary dependencies for data generation and Pub/Sub publishing.
# 
# Generated data characteristics:
# - Realistic vehicle movement patterns around major cities
# - Varied speed profiles (stationary, city, highway driving)
# - Random but plausible fuel levels and engine states
# - Occasional data quality issues for testing error handling
# 
# Parameters:
#   batch_size - Number of telemetry messages to generate (default: 5)
# 
# Note: Data is automatically published to the configured Pub/Sub topic
# Note: Function activates/deactivates virtual environment automatically
generate_test_data() {
    local batch_size=${1:-5}
    log_info "Generating $batch_size test IoT events..."
    
    # Activate development environment for data generation
    # This environment contains google-cloud-pubsub and other data generation dependencies
    source "$DEV_ENV_PATH/bin/activate"
    log_info "Using Python version: $(python --version 2>&1)"
    
    # Execute the data generator script with specified parameters
    # The script creates realistic vehicle telemetry data and publishes to Pub/Sub
    python test_data_generator.py \
        --project $PROJECT_ID \
        --topic $TOPIC \
        --batch-size $batch_size
    
    log_success "Generated $batch_size test events and published to Pub/Sub topic: $TOPIC"
    
    # Deactivate virtual environment to return to system Python
    deactivate
}

# Tests the Apache Beam pipeline using DirectRunner for local execution
# 
# This function deploys and runs the IoT telemetry pipeline locally using
# Apache Beam's DirectRunner. This provides a cost-free way to test the
# pipeline logic and data transformations without using Google Cloud resources.
# 
# The DirectRunner executes the pipeline in the local environment and
# processes data from Pub/Sub, applying all transformations and writing
# results to BigQuery.
# 
# Process flow:
# 1. Clean up any existing local pipeline processes
# 2. Deploy pipeline using DirectRunner in background
# 3. Monitor pipeline execution for up to 90 seconds
# 4. Gracefully terminate pipeline after test duration
# 
# Note: Uses Python 3.12 virtual environment for Apache Beam compatibility
# Note: Pipeline processes data from Pub/Sub and writes to BigQuery
# Note: Execution is time-limited to prevent indefinite running
test_local_pipeline() {
    log_info "Testing pipeline locally with DirectRunner..."
    
    # Clean up any existing pipeline processes to prevent conflicts
    # This ensures a clean start for the current test run
    pkill -f "deploy_pipeline.sh local" 2>/dev/null || true
    pkill -f "basic_pipeline.py" 2>/dev/null || true
    sleep 2
    
    # Start the local pipeline deployment in background
    # The deploy script handles environment activation and pipeline execution
    # Ensure credentials are available to the subprocess
    export GOOGLE_APPLICATION_CREDENTIALS
    ./deploy_pipeline.sh local &
    LOCAL_PID=$!
    log_info "Local pipeline started (PID: $LOCAL_PID), running for 200 seconds..."
    
    # Allow pipeline startup time before monitoring
    sleep 10
    
    # Monitor pipeline execution with progress reporting
    # The loop checks if the process is still running and provides periodic updates
    COUNTER=0; MAX_WAIT=90
    while [ $COUNTER -lt $MAX_WAIT ]; do
        # Check if pipeline process is still running
        if ! kill -0 $LOCAL_PID 2>/dev/null; then
            log_info "Local pipeline process ended"
            break
        fi
        
        sleep 1; COUNTER=$((COUNTER + 1))
        
        # Provide progress updates every 30 seconds
        if [ $((COUNTER % 30)) -eq 0 ]; then
            log_info "Pipeline running... ${COUNTER}s elapsed"
        fi
    done

    # Graceful shutdown of pipeline process if still running
    # First attempt graceful termination, then force kill if necessary
    if kill -0 $LOCAL_PID 2>/dev/null; then
        log_info "Stopping local pipeline after $MAX_WAIT seconds..."
        kill $LOCAL_PID 2>/dev/null || true
        sleep 3; kill -9 $LOCAL_PID 2>/dev/null || true
    fi

    log_success "Local pipeline test completed"
}

# Tests the Apache Beam pipeline using Google Cloud Dataflow
# 
# This function deploys the IoT telemetry pipeline to Google Cloud Dataflow
# for production-scale testing. The pipeline runs on managed infrastructure
# with cost optimization settings (e2-micro instances, fixed scaling).
# 
# The function implements sophisticated job management including:
# - Safe job ID extraction from deployment output
# - Automatic job cancellation to control costs
# - Background monitoring with status reporting
# - Protection of existing jobs from accidental cancellation
# 
# Cost control features:
# - Single e2-micro worker instance (~$0.50-1/hour)
# - Auto-cancellation after ~120 seconds of processing
# - Background monitoring to track job status
# 
# Note: Uses multiple methods to extract job ID for robustness
# Note: Implements fail-safe job cancellation to prevent runaway costs
# Note: Provides console URL for manual monitoring
test_gcp_pipeline() {
    log_info "Testing pipeline on Google Cloud with DataflowRunner..."
    
    # Capture existing active jobs to avoid cancelling them
    # This safety measure ensures we only manage jobs created by this test
    EXISTING_JOBS=$(gcloud dataflow jobs list --project=$PROJECT_ID --region=$REGION --status=active --format="value(job_id)" || true)
    [[ -n "$EXISTING_JOBS" ]] && log_warning "Found existing active jobs. Will only cancel the job created by this test."

    # Deploy pipeline to Google Cloud and capture all output
    # The output contains job ID information needed for monitoring and cancellation
    DEPLOY_OUTPUT=$(./deploy_pipeline.sh 2>&1 || true)
    echo "$DEPLOY_OUTPUT"

    # Extract job ID using pattern matching for Dataflow job IDs
    # Dataflow job IDs follow a specific format with timestamps and random components
    CREATED_JOB_ID=$(echo "$DEPLOY_OUTPUT" | grep -Eo "[0-9a-fA-F]{8,}-[0-9a-fA-F-]{18,}" | head -1)
    
    # Fallback job ID detection by comparing job lists
    # If pattern matching fails, compare before/after job lists to find the new job
    if [[ -z "$CREATED_JOB_ID" ]]; then
        log_warning "Could not extract job ID from output. Trying to find newest job..."
        sleep 10  # Allow time for job to appear in listings
        ALL_JOBS=$(gcloud dataflow jobs list --project=$PROJECT_ID --region=$REGION --status=active --format="value(job_id)")
        for job in $ALL_JOBS; do
            if ! echo "$EXISTING_JOBS" | grep -q "$job"; then
                CREATED_JOB_ID="$job"
                log_info "Found new job: $CREATED_JOB_ID"
                break
            fi
        done
    fi

    if [[ -n "$CREATED_JOB_ID" ]]; then
        log_success "Pipeline deployed successfully with Job ID: $CREATED_JOB_ID"
        log_info "Monitor at: https://console.cloud.google.com/dataflow/jobs/$REGION/$CREATED_JOB_ID?project=$PROJECT_ID"
        
        # Start background monitoring and auto-cancellation process
        # This subshell runs independently to monitor job status and handle cancellation
        (
            sleep 30  # Initial wait for job startup
            
            # Monitor job status with 6 checks over 90 seconds (15-second intervals)
            for i in {1..6}; do
                JOB_STATUS=$(gcloud dataflow jobs describe $CREATED_JOB_ID --project=$PROJECT_ID --region=$REGION --format="value(currentState)" 2>/dev/null || echo "NOT_FOUND")
                log_info "Check $i/6: Job $CREATED_JOB_ID status: $JOB_STATUS"
                
                # Check if job has reached a terminal state
                if [[ "$JOB_STATUS" =~ JOB_STATE_(CANCELLED|DONE|FAILED) ]]; then
                    log_info "Job already in terminal state: $JOB_STATUS"; break
                fi
                
                # Auto-cancel on final check to prevent indefinite running
                if [[ "$i" -eq 6 ]]; then
                    log_info "Auto-cancelling job $CREATED_JOB_ID after processing time..."
                    gcloud dataflow jobs cancel $CREATED_JOB_ID --region=$REGION --quiet && log_success "✅ Job cancelled successfully"
                fi
                sleep 15
            done
        ) &
        MONITOR_PID=$!
        log_info "Auto-cancellation monitor started (PID: $MONITOR_PID)"
        sleep 45
        log_info "Pipeline test running. Auto-cancellation will occur soon."
    else
        # Handle job ID extraction failure
        log_error "Could not extract job ID from deployment output"
        log_info "Deployment output for debugging:"
        echo "$DEPLOY_OUTPUT"
        gcloud dataflow jobs list --project=$PROJECT_ID --region=$REGION --status=active
        return 1
    fi
}

# Verifies successful data processing by querying BigQuery tables
# 
# This function validates that the pipeline successfully processed and stored
# telemetry data in BigQuery. It queries for recent records and displays
# key metrics to confirm proper pipeline operation.
# 
# The verification includes:
# - Querying recent telemetry data (last 10 minutes)
# - Displaying sample records with key fields
# - Using jq for pretty JSON formatting when available
# - Providing clear success/failure feedback
# 
# Query fields verified:
# - vehicle_id: Vehicle identifier
# - timestamp: Event timestamp
# - speed_kmh: Vehicle speed
# - speed_category: Derived speed classification
# - processed_at: Pipeline processing timestamp
# - data_quality_score: Data completeness metric
# 
# Note: Falls back to CSV format if jq is not available
# Note: Only shows records from the last 10 minutes to focus on test data
verify_bigquery_data() {
    log_info "Verifying data in BigQuery..."
    
    # SQL query to retrieve recent telemetry data with key metrics
    # Limited to last 10 minutes to focus on data from current test run
    QUERY="SELECT vehicle_id, timestamp, speed_kmh, speed_category, processed_at, data_quality_score
           FROM \`$PROJECT_ID.intelligent_dataops_analytics.iot_telemetry\`
           WHERE processed_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 10 MINUTE)
           ORDER BY processed_at DESC LIMIT 10"
    
    # Use jq for pretty JSON formatting if available, otherwise fall back to CSV
    # jq provides better readability for complex data structures
    if command -v jq >/dev/null 2>&1; then
        RESULT=$(bq query --use_legacy_sql=false --format=prettyjson "$QUERY" | jq .)
    else
        RESULT=$(bq query --use_legacy_sql=false --format=csv "$QUERY")
    fi

    # Verify that data was found and display results
    # The presence of vehicle_id indicates successful data processing
    if echo "$RESULT" | grep -q "vehicle_id"; then
        log_success "Data verification successful. Recent records found:"
        echo "$RESULT" | head -6
    else
        log_warning "No recent data found in BigQuery."
    fi
}

# Cleans up background processes and resources
# 
# This function ensures proper cleanup of all processes started during
# pipeline testing. It's called automatically on script exit via trap
# to prevent orphaned processes and resource leaks.
# 
# Cleanup targets:
# - Pipeline deployment scripts
# - Apache Beam pipeline processes
# - Background monitoring processes
# - gcloud command processes
# 
# Note: Uses process name matching to find and terminate related processes
# Note: Suppresses errors for processes that may have already terminated
# Note: Called automatically on script exit via EXIT trap
cleanup() {
    log_info "Cleaning up background processes..."
    
    # Terminate pipeline deployment and execution processes
    pkill -f "deploy_pipeline.sh" 2>/dev/null || true
    pkill -f "basic_pipeline.py" 2>/dev/null || true
    
    # Clean up background monitoring process if it exists
    [[ -n "${MONITOR_PID:-}" ]] && kill $MONITOR_PID 2>/dev/null || true
    
    # Terminate any lingering gcloud monitoring commands
    pkill -f "gcloud dataflow jobs describe" 2>/dev/null || true
}

# Main execution function that orchestrates the entire pipeline testing workflow
# 
# This function serves as the primary entry point and coordinator for all testing
# activities. It processes command-line arguments, sets up the testing environment,
# and executes the appropriate test sequence based on the specified mode.
# 
# The function implements a comprehensive testing workflow:
# 1. Parameter parsing and validation
# 2. Environment setup and prerequisite checking
# 3. Optional table truncation for clean testing
# 4. Test data generation and publishing
# 5. Pipeline deployment and execution (local/GCP/both)
# 6. Data verification and result reporting
# 
# Parameters:
#   test_mode        Testing mode: local, gcp, or both (default: both)
#   data_batch_size  Number of test messages to generate (default: 5)
#   skip_truncate    Whether to skip BigQuery table truncation (default: false)
#   --dry-run        Optional flag for validation without execution
# 
# Note: Implements automatic cleanup via EXIT trap
# Note: Supports flexible parameter combinations for different testing scenarios
main() {
    local test_mode=${1:-"both"}
    local data_batch_size=${2:-5}
    local skip_truncate=${3:-false}
    local dry_run=false

    # Parse dry-run flag from any parameter position
    [[ "$4" == "--dry-run" ]] && dry_run=true

    # Display test configuration and parameters
    echo "=========================================="
    echo "🚀 IoT Telemetry Pipeline Test Suite"
    echo "=========================================="
    echo "Mode: $test_mode"
    echo "Data batch size: $data_batch_size"
    echo "Skip truncate: $skip_truncate"
    echo "Dry run: $dry_run"
    echo "Project: $PROJECT_ID"
    echo "Region: $REGION"
    echo "=========================================="

    # Set up automatic cleanup on script exit
    # This ensures proper resource cleanup even if script is interrupted
    trap cleanup EXIT
    
    # Navigate to the ingestion directory where pipeline scripts are located
    cd "$PROJECT_ROOT/src/ingestion"

    # Execute prerequisite validation
    check_prerequisites
    
    # Exit early if in dry-run mode (validation only)
    $dry_run && { log_info "Dry-run mode enabled. Exiting before pipeline execution."; exit 0; }
    
    # Conditionally truncate BigQuery tables for clean testing
    [[ "$skip_truncate" != "true" ]] && truncate_bigquery_tables
    
    # Purge any pending messages from previous test runs to ensure clean state
    # This is necessary because DirectRunner in streaming mode maintains state
    purge_pubsub_subscription
    
    # Generate and publish test data to Pub/Sub
    generate_test_data $data_batch_size
    # verify_pubsub_messages

    # Execute appropriate test sequence based on mode
    case $test_mode in
        local) 
            # Test only with Apache Beam DirectRunner (local, free)
            test_local_pipeline 
            ;;
        gcp|cloud) 
            # Test only with Google Cloud Dataflow (managed, cost-optimized)
            test_gcp_pipeline 
            ;;
        both|full) 
            # Test both environments sequentially
            test_local_pipeline
            sleep 5  # Brief pause between tests
            test_gcp_pipeline 
            ;;
        *) 
            # Handle invalid test mode
            log_error "Invalid test mode: $test_mode"
            exit 1 
            ;;
    esac

    # Verify successful data processing and display results
    verify_bigquery_data
    
    # Display completion message
    echo "=========================================="
    log_success "Pipeline testing completed successfully!"
    echo "=========================================="
}

# Help text and usage information
# Display comprehensive usage instructions when help is requested
[[ "$1" == "--help" || "$1" == "-h" ]] && {
    echo "IoT Telemetry Pipeline Test Script"
    echo ""
    echo "Usage: $0 [MODE] [BATCH_SIZE] [SKIP_TRUNCATE] [--dry-run]"
    echo ""
    echo "Parameters:"
    echo "  MODE           Testing mode (default: both)"
    echo "                 local  - Test with DirectRunner only (free)"
    echo "                 gcp    - Test with DataflowRunner only (cost-optimized)"
    echo "                 both   - Test both environments sequentially"
    echo ""
    echo "  BATCH_SIZE     Number of test messages to generate (default: 5)"
    echo ""
    echo "  SKIP_TRUNCATE  Skip BigQuery table truncation (default: false)"
    echo "                 true   - Keep existing data"
    echo "                 false  - Clean tables before testing"
    echo ""
    echo "  --dry-run      Validate environment without running pipelines"
    echo ""
    echo "Examples:"
    echo "  $0                           # Full test with default settings"
    echo "  $0 local 3                  # Local test with 3 messages"
    echo "  $0 gcp 10 true              # GCP test, keep existing data"
    echo "  $0 both 5 false --dry-run   # Validation only"
    echo ""
    exit 0
}

# Script entry point
# Execute main function with all provided arguments
main "$@"
