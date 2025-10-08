#!/bin/bash

# Setup Apache Beam Production Environment
# Creates Python 3.12 environment specifically for Dataflow pipelines

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

# Install Apache Beam and dependencies
echo "📦 Installing Apache Beam and GCP dependencies..."
pip install apache-beam[gcp]==2.61.0
pip install google-cloud-pubsub>=2.20.0
pip install google-cloud-bigquery>=3.25.0

# Verify installation
echo ""
echo "🧪 Testing Apache Beam installation..."
python -c "import apache_beam as beam; print(f'✅ Apache Beam {beam.__version__} installed successfully')"
python -c "from apache_beam.runners.direct.direct_runner import DirectRunner; print('✅ DirectRunner available')"
python -c "from apache_beam.runners.dataflow.dataflow_runner import DataflowRunner; print('✅ DataflowRunner available')"

echo ""
echo "✅ Apache Beam environment setup complete!"
echo ""
echo "🚀 To use this environment:"
echo "   source $BEAM_ENV_PATH/bin/activate"
echo ""
echo "📝 To update deploy script, use:"
echo "   PYTHON_CMD=$BEAM_ENV_PATH/bin/python ./deploy_pipeline.sh"