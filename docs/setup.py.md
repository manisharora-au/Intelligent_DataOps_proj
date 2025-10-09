# setup.py Usage Guide

The `setup.py` file is a critical component for Apache Beam/Dataflow pipeline packaging and deployment. This guide explains how it's used across different deployment scenarios.

## Overview

The `setup.py` file defines the IoT telemetry pipeline as a Python package, enabling consistent dependency management and professional deployment workflows.

## Usage Scenarios

### 1. Google Cloud Dataflow Deployment

When deploying to Dataflow, use the `--setup_file` parameter to ensure all workers have consistent dependencies:

```bash
python basic_pipeline.py \
    --project=manish-sandpit \
    --runner=DataflowRunner \
    --setup_file=./setup.py \
    --temp_location=gs://bucket/temp \
    --input_subscription=projects/PROJECT/subscriptions/SUBSCRIPTION \
    --output_table=PROJECT:dataset.table
```

**What this does:**
- Installs the package and all dependencies on each Dataflow worker
- Ensures consistent environment across all workers
- Handles dependency resolution automatically
- Prevents version conflicts between workers

### 2. Flex Template Deployment (Production)

For containerized deployments, `setup.py` is used in the Docker build process:

```dockerfile
# Dockerfile example
FROM gcr.io/dataflow-templates-base/python312-template-launcher-base

COPY setup.py requirements.txt ./
COPY src/ingestion/ ./

# Install pipeline as package
RUN pip install .

# Set the entrypoint
ENTRYPOINT ["/opt/google/dataflow/python_template_launcher"]
```

This creates a self-contained container with all dependencies pre-installed.

### 3. Local Development Installation

Install the pipeline as a development package:

```bash
# Install in development mode (editable)
pip install -e .

# Install with AI/ML features
pip install -e .[ai]

# Install with development tools
pip install -e .[dev]

# Install everything
pip install -e .[ai,dev]
```

**Benefits:**
- Editable installation allows code changes without reinstallation
- Modular extras for optional features
- Consistent local and production environments

### 4. Command Line Usage

The entry point enables running the pipeline as a CLI command:

```bash
# After installation, run directly:
iot-pipeline \
    --project=PROJECT \
    --input_subscription=projects/PROJECT/subscriptions/SUBSCRIPTION \
    --output_table=PROJECT:dataset.table \
    --runner=DirectRunner
```

### 5. Package Distribution

Build and distribute the pipeline across teams:

```bash
# Build distribution packages
python setup.py sdist bdist_wheel

# Install from built package
pip install dist/iot-telemetry-pipeline-1.0.0.tar.gz

# Or upload to private PyPI repository
twine upload dist/* --repository-url https://private-pypi.company.com
```

### 6. Dataflow Worker Setup Process

When Dataflow spins up workers, the following happens automatically:

1. **Code Download**: Downloads your pipeline code and `setup.py`
2. **Package Installation**: Runs `pip install .` on each worker
3. **Environment Consistency**: Ensures all workers have identical Python environments
4. **Dependency Resolution**: Installs all dependencies listed in `install_requires`

## Package Structure

Our `setup.py` defines:

```python
# Core dependencies (always installed)
install_requires=[
    'apache-beam[gcp]==2.56.0',
    'google-cloud-pubsub==2.31.1',
    # ... other core dependencies
]

# Optional extras
extras_require={
    'ai': ['google-cloud-aiplatform==1.119.0', ...],
    'dev': ['pytest>=7.4.0', ...]
}

# Command line interface
entry_points={
    'console_scripts': [
        'iot-pipeline=basic_pipeline:run_pipeline',
    ],
}
```

## Current vs Future Usage

### Current Implementation
- **Direct Script Deployment**: Using `./deploy_pipeline.sh`
- **Simple Setup**: Good for development and testing
- **Manual Dependency Management**: Requirements handled via `requirements.txt`

### Future Production Implementation
- **Flex Templates**: Containerized deployment with `setup.py`
- **Robust Dependency Management**: Automatic resolution across workers
- **CI/CD Integration**: Easier automated deployments
- **Package Distribution**: Share across teams and environments
- **Version Management**: Semantic versioning and release management

## Best Practices

1. **Version Pinning**: Pin exact versions for reproducible builds
2. **Modular Extras**: Use extras for optional features
3. **Entry Points**: Provide CLI interfaces for operational use
4. **Documentation**: Include comprehensive package metadata
5. **Testing**: Test package installation in clean environments

## Migration Path

To transition from current direct deployment to package-based deployment:

1. **Phase 1**: Continue using current deployment with `setup.py` available
2. **Phase 2**: Test Flex Template deployment in staging
3. **Phase 3**: Migrate production to containerized deployment
4. **Phase 4**: Implement full CI/CD with package distribution

The `setup.py` provides a **professional packaging foundation** that enables scalable, maintainable deployment workflows for production environments.