# Terraform Infrastructure (infrastructure/)

## **🎯 Purpose**

The Terraform infrastructure code defines and deploys the complete **Google Cloud Platform foundation** for the Intelligent DataOps Platform. It provides Infrastructure as Code (IaC) for cost-optimized, production-ready cloud resources supporting real-time data processing and analytics.

## **🏗️ Infrastructure Architecture**
```
GCP Project (manish-sandpit)
├── Pub/Sub (Messaging)
├── BigQuery (Data Warehouse) 
├── Cloud Storage (Data Lake)
├── Monitoring & Alerting
└── IAM & Security
```

## **📁 File Structure**

### **Core Configuration**
```
infrastructure/
├── main.tf              # Provider config & variables
├── pubsub.tf            # Message queuing infrastructure  
├── bigquery.tf          # Data warehouse setup
├── storage.tf           # Cloud Storage buckets
├── monitoring.tf        # Observability & alerting
├── outputs.tf           # Resource outputs & endpoints
└── terraform.tfstate    # Current infrastructure state
```

## **🔧 Component Details**

### **main.tf - Foundation**
```hcl
# Cost-optimized setup for $100/month budget
variable "project_id" {
  default = "manish-sandpit"
}
variable "region" {
  default = "us-central1"  # Cost-effective region
}
```

**Key Features:**
- **Budget constraints** - Designed for $100/month limit
- **Regional optimization** - US Central for cost efficiency  
- **Environment labeling** - Consistent resource tagging
- **Development focus** - Optimized for learning and testing

### **pubsub.tf - Messaging Infrastructure**
```hcl
# Core topics for data streams
google_pubsub_topic "iot_telemetry"      # Vehicle data
google_pubsub_topic "supplier_updates"   # Supplier APIs  
google_pubsub_topic "delivery_events"    # Delivery status
google_pubsub_topic "system_alerts"      # Platform alerts
google_pubsub_topic "dead_letter"        # Error handling
```

**Subscriptions:**
- **Dataflow integration** - Subscriptions for pipeline processing
- **Dead letter queues** - Error message handling
- **Message retention** - 7-day default retention
- **Auto-scaling** - Handles variable message volumes

### **bigquery.tf - Data Warehouse**
```hcl
# Analytics dataset
google_bigquery_dataset "analytics"
  ├── iot_telemetry table    # Vehicle sensor data
  ├── deliveries table       # Delivery records  
  └── vehicles table         # Fleet information

# Real-time dataset  
google_bigquery_dataset "realtime"
  └── operational_metrics    # Live KPIs
```

**Table Features:**
- **Partitioning** - Date-based for query performance
- **Clustering** - Optimized by vehicle_id, route_id
- **Schema enforcement** - Structured data validation
- **Cost optimization** - Automatic table lifecycle management

### **storage.tf - Data Lake**
```hcl
google_storage_bucket "raw_data_lake"     # Unstructured data
google_storage_bucket "processed_data"    # ETL outputs
google_storage_bucket "dataflow_temp"     # Pipeline staging
```

**Bucket Configuration:**
- **Lifecycle policies** - Auto-delete old temp files
- **Regional storage** - Cost optimization
- **Versioning** - Data protection for critical buckets
- **Access control** - IAM-based security

### **monitoring.tf - Observability**
```hcl
# Cost monitoring dashboard
google_monitoring_dashboard "cost_overview"

# Alert policies
google_monitoring_alert_policy "storage_usage"   # Storage limits
google_monitoring_alert_policy "pubsub_backlog"  # Message queues
```

**Monitoring Features:**
- **Cost tracking** - Budget and spend visualization
- **Resource alerts** - Proactive notifications
- **Performance metrics** - Pipeline and query monitoring
- **Custom dashboards** - Business KPI tracking

## **💰 Cost Optimization**

### **Budget Design**
- **Monthly limit**: $100 (development environment)
- **Resource sizing**: Minimal viable for learning
- **Auto-scaling limits** - Prevents runaway costs
- **Lifecycle policies** - Automatic cleanup of temporary data

### **Cost Breakdown** (Estimated)
```
BigQuery storage: ~$5-15/month
Pub/Sub messaging: ~$2-5/month  
Cloud Storage: ~$5-10/month
Monitoring: ~$1-3/month
────────────────────────────
Total: ~$13-33/month for Phase 1
```

### **Cost Controls**
- **Preemptible instances** - Where applicable
- **Regional deployment** - US Central for cost efficiency
- **Data retention limits** - Automatic cleanup policies
- **Alert thresholds** - Prevent unexpected charges

## **🔐 Security & IAM**

### **Access Control**
```hcl
# Service accounts for pipeline components
google_service_account "dataflow_sa"     # Pipeline execution
google_service_account "monitoring_sa"   # Observability

# IAM bindings with least privilege
google_project_iam_binding "pubsub_publisher"
google_project_iam_binding "bigquery_data_editor"
```

### **Security Features**
- **Least privilege** - Minimal required permissions
- **Service accounts** - Component-specific identities
- **Network security** - VPC and firewall rules
- **Encryption** - At-rest and in-transit by default

## **📊 Deployment Process**

### **Initial Setup**
```bash
# Enable APIs
./scripts/gcp-setup.sh

# Deploy infrastructure  
cd infrastructure/
terraform init
terraform plan
terraform apply
```

### **State Management**
- **Local state** - terraform.tfstate (development)
- **State backup** - terraform.tfstate.backup
- **Future**: Remote state in Cloud Storage for team collaboration

### **Validation**
```bash
# Verify deployment
terraform output
gcloud pubsub topics list
bq ls
gsutil ls
```

## **🔄 Integration Points**

### **Upstream Dependencies**
- **GCP Project** - manish-sandpit with billing enabled
- **APIs enabled** - All required Google Cloud services
- **Authentication** - gcloud CLI configured
- **Terraform CLI** - v1.0+ installed

### **Downstream Components**
- **Data pipelines** - Dataflow jobs use Pub/Sub and BigQuery
- **Monitoring** - Dashboards track all infrastructure metrics
- **Applications** - APIs connect to BigQuery for data access
- **CI/CD** - Future automated deployments

### **Resource Outputs**
```hcl
output "pubsub_topics" {
  value = {
    iot_telemetry = google_pubsub_topic.iot_telemetry.name
    # ... other topics
  }
}

output "bigquery_datasets" {
  value = {
    analytics = google_bigquery_dataset.analytics.dataset_id
    realtime = google_bigquery_dataset.realtime.dataset_id
  }
}
```

## **📈 Scalability & Performance**

### **Current Capacity**
- **Pub/Sub**: 1,000 messages/minute
- **BigQuery**: 1,000 queries/day  
- **Storage**: 100GB initial capacity
- **Dataflow**: 1-2 workers maximum

### **Scaling Strategy**
- **Horizontal scaling** - Increase worker counts
- **Vertical scaling** - Larger machine types
- **Storage scaling** - Automatic capacity expansion
- **Performance optimization** - Query and pipeline tuning

### **Performance Monitoring**
- **Query performance** - BigQuery slot usage
- **Pipeline latency** - End-to-end processing time
- **Storage efficiency** - Compression and partitioning
- **Cost per transaction** - Unit economics tracking

## **🚀 Future Enhancements**

### **Phase 2 Additions**
- **Cloud Functions** - Event-driven processing
- **AI Platform** - Vertex AI for ML models
- **Container Registry** - Docker image storage
- **Load balancers** - Frontend application support

### **Production Readiness**
- **Multi-environment** - Dev/staging/prod separation
- **Remote state** - Team collaboration support
- **Automated backup** - Disaster recovery planning
- **Security hardening** - Advanced IAM and VPC configuration

### **Advanced Features**
- **Auto-scaling policies** - Dynamic resource adjustment
- **Cost optimization** - Committed use discounts
- **Multi-region** - High availability deployment
- **Compliance** - SOC 2, GDPR readiness

This Terraform infrastructure provides the **scalable, cost-optimized foundation** for the entire Intelligent DataOps Platform, enabling rapid development while maintaining production-grade architecture principles.