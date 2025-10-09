#!/bin/bash

# Setup Apache Beam Production Environment
# Creates Python 3.12 environment specifically for Dataflow pipelines
# 
# This script sets up a dedicated environment for Apache Beam development
# using Python 3.12 and Apache Beam 2.56.0 for stable DirectRunner operation.
# 
# Usage: ./setup_beam_env.sh
#
# Prerequisites:
# - Python 3.12 installed (brew install python@3.12)
# - Git repository with setup.py in current directory

PROJECT_ROOT="/Users/manisharora/Projects/Intelligent_DataOps_proj"
BEAM_ENV_NAME="venv_beam_312"
BEAM_ENV_PATH="$PROJECT_ROOT/$BEAM_ENV_NAME"

echo "=== Setting up Apache Beam Production Environment ==="
echo "Project Root: $PROJECT_ROOT"
echo "Environment: $BEAM_ENV_NAME"
echo ""

# Check if Python 3.12 is available
if ! command -v python3.12 &> /dev/null; then
    echo "❌ Python 3.12 not found. Please install Python 3.12:"
    echo "   brew install python@3.12"
    exit 1
fi

echo "✅ Python 3.12 found: $(python3.12 --version)"

# Create virtual environment with Python 3.12
if [ -d "$BEAM_ENV_PATH" ]; then
    echo "📁 Beam environment already exists at $BEAM_ENV_PATH"
    echo "🗑️  Removing existing environment..."
    rm -rf "$BEAM_ENV_PATH"
fi

echo "🔨 Creating new Python 3.12 virtual environment..."
cd "$PROJECT_ROOT"
python3.12 -m venv "$BEAM_ENV_NAME"

# Activate environment
echo "🔌 Activating environment..."
source "$BEAM_ENV_PATH/bin/activate"

# Upgrade pip
echo "⬆️  Upgrading pip..."
pip install --upgrade pip

# Install Apache Beam and dependencies from setup.py
echo "📦 Installing Apache Beam and GCP dependencies..."
echo "🔧 Using Apache Beam 2.56.0 for stable DirectRunner (2.61.0+ has PrismRunner issues)"
pip install -e .

# Verify installation and DirectRunner functionality
echo ""
echo "🧪 Testing Apache Beam installation..."
python -c "import apache_beam as beam; print(f'✅ Apache Beam {beam.__version__} installed successfully')"
python -c "from apache_beam.runners.direct.direct_runner import DirectRunner; print('✅ DirectRunner available')"
python -c "from apache_beam.runners.dataflow.dataflow_runner import DataflowRunner; print('✅ DataflowRunner available')"

# Test that DirectRunner works correctly (not PrismRunner)
echo ""
echo "🔍 Verifying DirectRunner functionality..."
python -c "
import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions
import os
os.environ['BEAM_DIRECT_RUNNER_USE_PRISM'] = 'false'
try:
    options = PipelineOptions(['--runner=DirectRunner'])
    with beam.Pipeline(options=options) as p:
        _ = p | 'Create' >> beam.Create([1, 2, 3]) | 'Sum' >> beam.CombineGlobally(sum)
    print('✅ DirectRunner test successful - ready for local pipeline testing')
except Exception as e:
    print(f'❌ DirectRunner test failed: {e}')
    exit(1)
"

echo ""
echo "✅ Apache Beam environment setup complete!"
echo ""
echo "🚀 To use this environment:"
echo "   source $BEAM_ENV_PATH/bin/activate"
echo ""
echo "🧪 To test the pipeline:"
echo "   ./test_basic_pipeline.sh local 5"
echo ""
echo "☁️  To deploy to GCP:"
echo "   ./deploy_pipeline.sh"
echo ""
echo "📋 Environment details:"
echo "   Python: $(python3.12 --version)"
echo "   Apache Beam: 2.56.0 (stable DirectRunner)"
echo "   Virtual Environment: $BEAM_ENV_PATH"
echo ""
echo "⚠️  Note: This environment uses Apache Beam 2.56.0 to avoid PrismRunner issues in 2.61.0+"