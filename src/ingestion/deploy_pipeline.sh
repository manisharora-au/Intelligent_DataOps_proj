#!/bin/bash

# Deploy Dataflow Pipeline Script
# Cost-optimized deployment for learning environment

PROJECT_ID="manish-sandpit"
REGION="us-central1"
TEMP_LOCATION="gs://${PROJECT_ID}-dataflow-temp"

# Pipeline configuration
PIPELINE_NAME="iot-telemetry-pipeline"
INPUT_SUBSCRIPTION="projects/${PROJECT_ID}/subscriptions/iot-telemetry-subscription"
OUTPUT_TABLE="${PROJECT_ID}:intelligent_dataops_analytics.iot_telemetry"
ERROR_TABLE="${PROJECT_ID}:intelligent_dataops_analytics.pipeline_errors"

echo "=== Deploying Dataflow Pipeline ==="
echo "Project: $PROJECT_ID"
echo "Pipeline: $PIPELINE_NAME"
echo "Input: $INPUT_SUBSCRIPTION" 
echo "Output: $OUTPUT_TABLE"
echo ""

# Cost-optimized Dataflow job parameters
python basic_pipeline.py \
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
    --max_num_workers=2 \
    --machine_type=n1-standard-1 \
    --disk_size_gb=20 \
    --use_public_ips=true \
    --save_main_session=true

echo ""
echo "Pipeline deployment initiated!"
echo "Monitor at: https://console.cloud.google.com/dataflow/jobs?project=${PROJECT_ID}"
echo ""
echo "Estimated cost: ~$2-5/hour with 1-2 workers"