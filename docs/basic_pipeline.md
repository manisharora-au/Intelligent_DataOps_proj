# Basic Dataflow Pipeline (basic_pipeline.py)

## **🎯 Purpose**

The `basic_pipeline.py` serves as the **core data processing engine** that transforms raw IoT telemetry from Pub/Sub into clean, structured data in BigQuery for the Intelligent DataOps Platform.

## **📊 Data Flow**
```
IoT Devices → Pub/Sub (iot-telemetry) → Dataflow Pipeline → BigQuery Tables
                                      ↳ Error Handling → Error Table
```

## **🔧 Key Functionality**

### **1. Data Ingestion**
- **Real-time streaming** from `iot-telemetry` Pub/Sub topic
- **Apache Beam framework** for scalable stream processing
- **Cost-optimized** with 1-2 workers for development environment

### **2. Data Validation & Parsing**
- **JSON parsing** with error handling for malformed messages
- **Required field validation**: `vehicle_id`, `timestamp`, `device_type`
- **Dual output streams**: valid messages vs error records
- **Graceful degradation** - continues processing despite individual message failures

#### **Expected Input JSON Schema from Pub/Sub topic `iot-telemetry` to pipeline `basic_pipeline.py`**
```json
{
    "vehicle_id": "VH003",
    "device_type": "gps_tracker",
    "timestamp": "2025-10-03T06:30:00Z",
    "latitude": 41.8891,
    "longitude": -87.6198,
    "speed_kmh": 87,
    "fuel_level": 0.72,
    "engine_status": "running",
    "driver_id": "DR007",
    "route_id": "RT014",
    "odometer": 125847,
    "temperature": 18
}
```

#### **Pipeline Output Schema from `basic_pipeline.py` to BigQuery table `iot_telemetry.telemetry_data`**
```json
{
    "vehicle_id": "VH003",
    "device_type": "gps_tracker", 
    "timestamp": "2025-10-03T06:30:00Z",
    "latitude": 41.8891,
    "longitude": -87.6198,
    "speed_kmh": 87,
    "fuel_level": 0.72,
    "engine_status": "running",
    "processed_at": "2025-10-03T06:30:15Z",
    "data_quality_score": 0.875,
    "location_valid": true,
    "speed_category": "fast",
    "raw_data": "{\"vehicle_id\":\"VH003\",...}"
}
```

### **3. Data Enrichment**
- **Data quality scoring** - calculates completeness percentage (0-1.0)
- **Geospatial validation** - validates GPS coordinates within realistic bounds
- **Speed categorization** - classifies speed into: stationary, slow, moderate, fast, very_fast
- **Processing timestamps** - adds `processed_at` field for audit trails

### **4. Data Storage**
- **Valid telemetry** → `intelligent_dataops_analytics.iot_telemetry` table
- **Error records** → `intelligent_dataops_analytics.pipeline_errors` table
- **Windowed processing** - 1-minute windows for streaming efficiency
- **Auto-table creation** - creates BigQuery tables if they don't exist

## **🏗️ Technical Architecture**

### **Apache Beam Components**
```python
ParsePubSubMessage (DoFn)     # JSON parsing & validation
    ↓ valid / invalid
EnrichTelemetryData (DoFn)    # Data quality & enrichment
    ↓
WriteToBigQuery (Transform)   # Dual table writes
```

### **Error Handling Strategy**
- **Tagged outputs** - separate valid/invalid message streams
- **Dead letter pattern** - error records preserved for analysis
- **Retry logic** - built into Pub/Sub and BigQuery connectors
- **Monitoring** - all errors logged for operational visibility

### **Scalability Features**
- **Auto-scaling workers** - scales from 1 to 2 workers based on load
- **Windowing** - processes data in 60-second batches
- **Partitioned storage** - BigQuery tables partitioned by timestamp
- **Streaming inserts** - real-time data availability

## **💼 Business Value**

### **Operational Intelligence**
- **Fleet tracking** - Real-time vehicle location monitoring
- **Performance analytics** - Speed, fuel efficiency, route analysis
- **Anomaly detection** - Identify vehicles deviating from normal patterns
- **Compliance reporting** - Driver behavior and safety metrics

### **Cost Optimization**
- **Fuel efficiency** - Track consumption patterns across fleet
- **Route optimization** - Historical data for better planning
- **Maintenance scheduling** - Proactive based on usage patterns
- **Resource allocation** - Optimize vehicle and driver assignments

### **Data Foundation**
- **ML model training** - Clean, structured data for predictive analytics
- **Real-time dashboards** - KPI monitoring and alerts
- **Historical analysis** - Trend identification and forecasting
- **Integration ready** - Standardized schema for downstream systems

## **🔄 Integration Points**

### **Upstream Dependencies**
- **Pub/Sub Topic**: `iot-telemetry` 
- **Subscription**: `iot-telemetry-subscription`
- **Data Sources**: `test_data_generator.py`, `generate_test_data.sh`

### **Downstream Outputs**
- **Primary Table**: `intelligent_dataops_analytics.iot_telemetry`
- **Error Table**: `intelligent_dataops_analytics.pipeline_errors`
- **Monitoring**: Cloud Logging and Monitoring integration

### **Future Integrations**
- **AI Agents** - Route optimization, predictive maintenance
- **Alerting Systems** - Real-time anomaly notifications
- **Dashboard APIs** - Frontend data consumption
- **External Systems** - Customer notifications, fleet management

## **📈 Performance Characteristics**

### **Throughput**
- **Design capacity**: 1,000 messages/minute
- **Current setup**: 6-10 messages/minute (testing)
- **Latency**: <30 seconds end-to-end processing

### **Cost Profile**
- **Dataflow workers**: ~$2-5/hour (1-2 workers)
- **BigQuery storage**: ~$5-15/month
- **Pub/Sub messaging**: ~$2-5/month
- **Total estimated**: ~$50-100/month at full scale

## **🚀 Deployment**

### **Manual Deployment**
```bash
cd src/ingestion
./deploy_pipeline.sh
```

### **Configuration**
- **Project**: manish-sandpit
- **Region**: us-central1 (cost-optimized)
- **Machine type**: n1-standard-1
- **Temp location**: gs://manish-sandpit-dataflow-temp

### **Monitoring**
- **Dataflow Console**: Monitor job health and throughput
- **BigQuery**: Query data quality and volume metrics
- **Cloud Logging**: Error analysis and debugging

This pipeline forms the **critical foundation** for all future analytics, AI agents, and operational intelligence in the Intelligent DataOps Platform.