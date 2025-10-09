# Production Deployment Guide

## Python Library Compatibility Issue

**Problem:** Apache Beam (v2.61.0) has compatibility issues with Python 3.13 due to `apitools` enum definition errors.

**Solution:** Use Python 3.12 in a dedicated environment for Apache Beam pipelines.

## Setup Instructions

### 1. Create Apache Beam Environment

```bash
# Run the setup script to create Python 3.12 environment
./setup_beam_env.sh
```

This creates:
- `venv_beam_312/` - Python 3.12 virtual environment
- Apache Beam 2.61.0 with GCP dependencies
- Compatible versions of all libraries

### 2. Deploy Pipeline

```bash
# Set credentials
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/credentials/terraform-dataops-key.json"

# Navigate to ingestion directory  
cd src/ingestion

# Deploy locally for testing (free)
./deploy_pipeline.sh local

# Deploy to Google Cloud (production)
./deploy_pipeline.sh


### 3. Flex Template Deployment (Future)

For production Flex Template deployment:

bash
# Build container image
gcloud builds submit --config cloudbuild.yaml .

# Create Flex Template
gcloud dataflow flex-template build \
    gs://manish-sandpit-dataflow-temp/templates/iot-telemetry-template.json \
    --image gcr.io/manish-sandpit/dataflow/iot-telemetry-pipeline \
    --sdk-language PYTHON

# Run from template
gcloud dataflow flex-template run iot-telemetry-job \
    --template-file-gcs-location gs://manish-sandpit-dataflow-temp/templates/iot-telemetry-template.json \
    --region us-central1 \
    --parameters input_subscription=projects/manish-sandpit/subscriptions/iot-telemetry-subscription \
    --parameters output_table=manish-sandpit:intelligent_dataops_analytics.iot_telemetry
```

## Environment Management

### Current Setup
- **Development Environment:** `venv_dataops/` (Python 3.13) - For all non-Beam development
- **Production Environment:** `venv_beam_312/` (Python 3.12) - For Apache Beam pipelines only

### Usage Pattern
```bash
# For general development (API, data generators, etc.)
source venv_dataops/bin/activate

# For Apache Beam pipeline work
source venv_beam_312/bin/activate
# OR use deploy script which handles this automatically
```

## Cost Optimization

Current production configuration:
- **1 worker minimum/maximum** (no autoscaling)
- **n1-standard-1 machine type** (cheapest)
- **Runner V2** (faster, more efficient)
- **Unified Worker** (additional optimizations)
- **Estimated cost:** ~$1-2/hour

## Alternative Solutions (Not Recommended)

1. **Downgrade Apache Beam:** Use older version compatible with Python 3.13
   - Risk: Missing features and security updates
   
2. **Pin apitools version:** Force compatible version
   - Risk: May break other dependencies
   
3. **Wait for fix:** Apache Beam team to fix Python 3.13 compatibility
   - Timeline: Unknown

## Recommendation

**Use the Python 3.12 environment approach** as it:
- ✅ Provides full Apache Beam functionality
- ✅ Maintains compatibility with all GCP services
- ✅ Allows easy migration when Python 3.13 support is added
- ✅ Isolates production pipeline from development environment
- ✅ Enables Flex Template deployment for production scaling