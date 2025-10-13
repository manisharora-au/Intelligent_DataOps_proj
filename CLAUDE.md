# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Intelligent DataOps Platform for Real Time Decisioning**

Vision: An end-to-end AI-powered cloud platform that ingests diverse data in real-time, applies AI Agents for decision-making, automates workflows, and delivers insights via a modern, interactive web application. A production-grade blend of MLOps + DataOps + Agentic AI Orchestration.

**Target Scenario**: Multi-tenant logistics & supply chain company with:
- Real-time data ingestion from IoT devices, supplier APIs, and databases
- Autonomous AI agents that detect delays/anomalies and trigger workflows
- Interactive dashboards with natural language querying
- Cloud-native, scalable, and secure deployment

## Development Commands

### Python Development

**Virtual Environment Setup:**
```bash
# ALWAYS check for existing virtual environments first
find . -name "*venv*" -type d -maxdepth 2

# Use the project-level virtual environment (preferred)
source venv_dataops/bin/activate

# If venv_dataops doesn't exist, create it at project root
cd /Users/manisharora/Projects/Intelligent_DataOps_proj
python3 -m venv venv_dataops
source venv_dataops/bin/activate

# Install dependencies
pip install -r src/ingestion/requirements.txt
```

**Development Commands:**
```bash
# Activate environment (run from project root)
source venv_dataops/bin/activate

# Run linting
flake8 .
black --check .
isort --check-only .

# Format code
black .
isort .

# Run tests
pytest
pytest tests/test_specific.py  # Run specific test file
pytest -k "test_name"          # Run specific test by name

# Type checking
mypy .
```

**Data Generator Testing:**
```bash
# Activate environment and set credentials
source venv_dataops/bin/activate
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/credentials/terraform-dataops-key.json"

# Test data generator (3 messages)
cd src/ingestion
python test_data_generator.py --project manish-sandpit --topic iot-telemetry --batch-size 3

# Verify messages
gcloud pubsub subscriptions pull iot-telemetry-subscription --limit=3 --auto-ack
```

### GCP Development

**Service Account Authentication (REQUIRED for ALL operations):**
```bash
# ALWAYS use service account for all GCP operations
gcloud auth activate-service-account --key-file="$HOME/.gcp/credentials/terraform-dataops-key.json"
gcloud config set project manish-sandpit
```

**Infrastructure Deployment:**
```bash
# Deploy BigQuery tables and procedures (scripts handle auth automatically)
cd src/storage/bigquery
./deploy_all_tables.sh
./deploy_stored_procedures.sh
```

**Development and Testing:**
```bash
# All development commands use service account
bq query --use_legacy_sql=false 'SELECT * FROM dataset.table LIMIT 10'
gcloud dataflow jobs list
gcloud pubsub topics list
```

**Application Deployment:**
```bash
# Deploy Cloud Functions
gcloud functions deploy FUNCTION_NAME --runtime python39

# Deploy to Cloud Run
gcloud run deploy SERVICE_NAME --image gcr.io/PROJECT_ID/IMAGE_NAME

# Dataflow job
python -m apache_beam.examples.wordcount --runner DataflowRunner
```

### Docker Development
```bash
# Build containers
docker-compose build

# Start services locally
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## Code Architecture

### Core Components
- **Data Ingestion Layer**: Multi-source streaming pipelines (GCP Pub/Sub, Dataflow, API Gateway)
- **Data Processing & Storage**: Batch + streaming processing (BigQuery, Firestore, Cloud SQL)
- **AI/ML Models**: Predictive analytics and anomaly detection (Vertex AI, scikit-learn, XGBoost)
- **Agentic AI Orchestration**: Autonomous decision-making agents (CrewAI, OpenAI SDK, LangChain)
- **Event-Driven Automation**: Workflow triggers and execution (Cloud Functions, Workflows, Eventarc)
- **Frontend Dashboard**: Interactive UI with natural language queries (Next.js, Tailwind)

### Directory Structure
```
/
├── src/                    # Main source code
│   ├── ingestion/         # Data ingestion pipelines (Pub/Sub, Dataflow)
│   ├── processing/        # Data processing and transformation
│   ├── models/           # AI/ML models and training scripts
│   ├── agents/           # AI agents and orchestration logic
│   ├── workflows/        # Event-driven automation workflows
│   ├── api/             # REST API endpoints and handlers
│   └── frontend/        # Next.js dashboard application
├── infrastructure/       # GCP infrastructure as code (Terraform)
├── tests/               # Test files (unit, integration, e2e)
├── config/              # Configuration files and environment settings
├── docs/               # Architecture documentation and blueprints
└── scripts/            # Deployment and utility scripts
```

## Development Guidelines

### Code Quality
- Use type hints for all Python functions
- Maintain test coverage above 80%
- Follow PEP 8 style guidelines
- Document all public APIs with docstrings

### Data Operations
- All data transformations must be idempotent
- Implement proper error handling and retry mechanisms
- Log all data quality metrics and pipeline status
- Use configuration-driven pipeline definitions

### Testing Strategy
- Unit tests for individual components
- Integration tests for pipeline workflows
- End-to-end tests for critical data flows
- Mock external dependencies in tests

### Security
- Never commit credentials or API keys
- Use environment variables for sensitive configuration
- Implement proper data access controls
- Encrypt sensitive data at rest and in transit
- **MANDATORY**: Use service account authentication for ALL GCP operations (no user accounts)

### Tasks
- First think through the problem, read the codebase for relevant files, and write a plan to tasks/todo.md.
- The plan should have a list of todo items that you can check off as you complete them
- Before you begin working, check in with me and I will verify the plan.
- Then, begin working on the todo items, marking them as complete as you go.
- Please every step of the way just give me a high level explanation of what changes you made
- Make every task and code change you do as simple as possible. We want to avoid making any massive or complex changes. Every change should impact as little code as possible. Everything is about simplicity.
- Ensure that there is adequate documentation for the class and any methods / functions introduced to the code base. This documentation should clearly articulate the purpose of the class or the method, function.

## GCP Command Logging

All GCP commands executed during development and testing must be logged for audit, debugging, and operational tracking purposes.

### Log File Structure
```
logs/
├── gcp-commands-YYYY-MM-DD.log     # Daily command logs
├── dataflow-jobs-YYYY-MM-DD.log    # Dataflow-specific operations
└── bigquery-queries-YYYY-MM-DD.log # BigQuery operations
```

### Logging Format
Each command must be logged with the following format:
```
[YYYY-MM-DD HH:MM:SS] COMMAND_TYPE: <actual_command>
[YYYY-MM-DD HH:MM:SS] RESULT: <success/failure/output_summary>
[YYYY-MM-DD HH:MM:SS] CONTEXT: <purpose/script/operation>
```

### Commands to Log
- **gcloud**: All gcloud CLI commands (auth, config, deploy, etc.)
- **bq**: BigQuery operations (queries, schema updates, data loads)
- **gsutil**: Cloud Storage operations
- **gcloud dataflow**: Pipeline deployments and management
- **gcloud builds**: Cloud Build operations
- **gcloud pubsub**: Pub/Sub topic and subscription management

### Example Log Entries
```bash
# Main GCP commands log
[2025-10-09 14:30:25] GCLOUD: gcloud dataflow jobs run iot-pipeline --gcs-location gs://bucket/template
[2025-10-09 14:30:45] RESULT: SUCCESS - Job ID: 2025-10-09_06_30_25-12345678901234567
[2025-10-09 14:30:45] CONTEXT: test_basic_pipeline.sh - GCP pipeline testing

[2025-10-09 14:32:10] BQ: bq query --use_legacy_sql=false "SELECT COUNT(*) FROM dataset.table"
[2025-10-09 14:32:12] RESULT: SUCCESS - 1,250 records found
[2025-10-09 14:32:12] CONTEXT: Pipeline verification after test run
```

### Implementation
- Add logging to all scripts that execute GCP commands
- Use `tee` or explicit logging functions in bash scripts
- Include environment context (local/dev/staging)
- Log both successful operations and failures with error details

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.
ALL markup files (*.md) must be created in the docs/ folder only, never in other directories. 