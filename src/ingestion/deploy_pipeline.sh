#!/bin/bash

# Deploy Dataflow Pipeline Script
# Ultra cost-optimized deployment for learning environment

PROJECT_ID="manish-sandpit"
REGION="us-central1"
TEMP_LOCATION="gs://${PROJECT_ID}-dataflow-temp"

# Pipeline configuration
PIPELINE_NAME="iot-telemetry-pipeline"
INPUT_SUBSCRIPTION="projects/${PROJECT_ID}/subscriptions/iot-telemetry-subscription"
OUTPUT_TABLE="${PROJECT_ID}:intelligent_dataops_analytics.iot_telemetry"
ERROR_TABLE="${PROJECT_ID}:intelligent_dataops_analytics.pipeline_errors"

# Python environment configuration
PROJECT_ROOT="/Users/manisharora/Projects/Intelligent_DataOps_proj"
BEAM_ENV_PATH="$PROJECT_ROOT/venv_beam_312"
PYTHON_CMD="${PYTHON_CMD:-$BEAM_ENV_PATH/bin/python}"

# Deployment mode (local or cloud)
MODE="${1:-cloud}"

# Check if Beam environment exists
if [ ! -f "$BEAM_ENV_PATH/bin/python" ]; then
    echo "❌ Apache Beam environment not found at $BEAM_ENV_PATH"
    echo "🔧 Please run: ./setup_beam_env.sh"
    exit 1
fi

echo "=== Deploying Dataflow Pipeline ==="
echo "Project: $PROJECT_ID"
echo "Pipeline: $PIPELINE_NAME"
echo "Mode: $MODE"
echo "Input: $INPUT_SUBSCRIPTION" 
echo "Output: $OUTPUT_TABLE"
echo ""

echo "🐍 Using Python: $PYTHON_CMD"
echo ""

if [ "$MODE" = "local" ]; then
    echo "Running pipeline locally with DirectRunner in streaming mode..."
    # Force use of legacy DirectRunner instead of PrismRunner
    export BEAM_DIRECT_RUNNER_USE_PRISM=false
    $PYTHON_CMD basic_pipeline.py \
        --project=$PROJECT_ID \
        --input_subscription=$INPUT_SUBSCRIPTION \
        --output_table=$OUTPUT_TABLE \
        --error_table=$ERROR_TABLE \
        --temp_location=$TEMP_LOCATION \
        --streaming=true \
        --runner=DirectRunner \
        --save_main_session
    
    echo ""
    echo "Local pipeline started!"
    echo "Cost: $0 (running locally)"
else
    echo "Deploying to Google Cloud with ultra cost optimization..."
    $PYTHON_CMD basic_pipeline.py \
        --project=$PROJECT_ID \
        --region=$REGION \
        --job_name=$PIPELINE_NAME \
        --temp_location=$TEMP_LOCATION \
        --input_subscription=$INPUT_SUBSCRIPTION \
        --output_table=$OUTPUT_TABLE \
        --error_table=$ERROR_TABLE \
        --streaming=true \
        --runner=DataflowRunner \
        --num_workers=1 \
        --max_num_workers=1 \
        --autoscaling_algorithm=NONE \
        --machine_type=e2-micro \
        --disk_size_gb=20 \
        --use_public_ips \
        --experiments=use_runner_v2 \
        --experiments=use_unified_worker \
        --save_main_session

    echo ""
    echo "Pipeline deployment initiated!"
    echo "Monitor at: https://console.cloud.google.com/dataflow/jobs?project=${PROJECT_ID}"
    echo ""
    echo "Estimated cost: ~$0.50-1/hour with 1 e2-micro worker + Runner V2 optimizations"
fi