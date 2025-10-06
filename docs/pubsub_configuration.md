# Pub/Sub Configuration & Messaging System

## **🎯 Purpose**

The Pub/Sub configuration provides the **real-time messaging backbone** for the Intelligent DataOps Platform. It enables asynchronous, scalable communication between IoT devices, data pipelines, AI agents, and business applications through event-driven architecture.

## **📡 Messaging Architecture**
```
IoT Devices → Pub/Sub Topics → Subscriptions → Processing Components
                    ↓
            Dead Letter Queues → Error Handling
```

## **🔧 Topic Configuration**

### **Core Data Topics**
```yaml
iot-telemetry:
  purpose: Vehicle GPS, speed, fuel sensor data
  producers: test_data_generator.py, IoT devices
  consumers: basic_pipeline.py (Dataflow)
  message_rate: 6-1000 messages/minute
  retention: 7 days

supplier-updates:
  purpose: Inventory levels, delivery schedules
  producers: Supplier APIs, ERP systems  
  consumers: Inventory agents, route planners
  message_rate: 10-100 messages/hour
  retention: 7 days

delivery-events:
  purpose: Package pickup, delivery, status changes
  producers: Driver apps, scanning systems
  consumers: Customer notifications, analytics
  message_rate: 50-500 messages/hour
  retention: 7 days
```

### **System Topics**
```yaml
system-alerts:
  purpose: Platform health, errors, warnings
  producers: All system components
  consumers: Monitoring dashboards, on-call alerts
  message_rate: 1-50 messages/hour
  retention: 30 days

dead-letter:
  purpose: Failed message processing, error records
  producers: Failed pipeline processing
  consumers: Error analysis, debugging tools
  message_rate: 1-10 messages/hour  
  retention: 30 days
```

## **📋 Subscription Strategy**

### **Processing Subscriptions**
```yaml
iot-telemetry-subscription:
  topic: iot-telemetry
  consumer: Dataflow pipeline (basic_pipeline.py)
  ack_deadline: 60 seconds
  retry_policy: exponential backoff
  dead_letter_topic: dead-letter

supplier-updates-subscription:
  topic: supplier-updates  
  consumer: Inventory management agents
  ack_deadline: 120 seconds
  message_ordering: enabled (by supplier_id)

delivery-events-subscription:
  topic: delivery-events
  consumer: Customer notification workflows
  ack_deadline: 30 seconds
  filter: "delivery_status IN ('delivered', 'failed')"
```

### **Analytics Subscriptions**
```yaml
analytics-pull-subscription:
  topic: iot-telemetry
  consumer: Real-time dashboard updates
  ack_deadline: 10 seconds
  exactly_once_delivery: enabled
  
monitoring-subscription:
  topic: system-alerts
  consumer: Cloud Monitoring integration
  ack_deadline: 30 seconds
  push_endpoint: /monitoring/webhook
```

## **🔄 Message Flow Patterns**

### **IoT Data Flow**
```
Vehicle Sensors → iot-telemetry topic → iot-telemetry-subscription → Dataflow Pipeline → BigQuery
                                    ↳ analytics-subscription → Real-time Dashboard
                                    ↳ ml-training-subscription → AI Model Training
```

### **Event-Driven Workflows**
```
Delivery Complete → delivery-events topic → notification-subscription → Customer SMS/Email
                                        ↳ analytics-subscription → KPI Updates
                                        ↳ billing-subscription → Invoice Generation
```

### **Error Handling Flow**
```
Processing Failure → dead-letter topic → error-analysis-subscription → Debug Dashboard
                                     ↳ alert-subscription → On-call Notification
```

## **📊 Message Schema Design**

### **IoT Telemetry Schema (Published to Pub/Sub)**
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
  "temperature": 18,
  "generated_at": "2025-10-03T06:30:00Z",
  "data_source": "shell_script"
}
```

**Note:** This is the actual schema used by `test_data_generator.py` and `generate_test_data.sh`. The simplified nested structure shown previously was for illustration - the pipeline expects flat JSON structure for BigQuery compatibility.

### **Delivery Event Schema**  
```json
{
  "event_id": "uuid",
  "timestamp": "2025-10-02T01:55:56Z",
  "delivery_id": "DEL123456",
  "vehicle_id": "VH001",
  "event_type": "delivery_complete",
  "location": {
    "address": "123 Main St, Chicago, IL",
    "coordinates": [41.8781, -87.6298]
  },
  "customer": {
    "customer_id": "CUST789",
    "notification_preferences": ["sms", "email"]
  }
}
```

### **System Alert Schema**
```json
{
  "alert_id": "uuid",
  "timestamp": "2025-10-02T01:55:56Z",
  "severity": "warning",
  "component": "dataflow-pipeline",
  "alert_type": "high_latency",
  "message": "Processing delay detected",
  "metrics": {
    "current_latency_ms": 5000,
    "threshold_ms": 3000
  }
}
```

## **⚡ Performance & Scaling**

### **Throughput Characteristics**
```yaml
Current Capacity:
  iot-telemetry: 1,000 messages/minute
  supplier-updates: 100 messages/hour
  delivery-events: 500 messages/hour
  
Peak Capacity:
  iot-telemetry: 10,000 messages/minute
  supplier-updates: 1,000 messages/hour  
  delivery-events: 5,000 messages/hour
```

### **Latency Performance**
- **End-to-end latency**: <100ms for real-time processing
- **Batch processing**: 1-5 minute windows
- **Push delivery**: <10ms to subscribers
- **Pull delivery**: On-demand with <1 second response

### **Auto-scaling Features**
- **Dynamic scaling** - Automatic subscriber scaling
- **Load balancing** - Message distribution across workers
- **Backpressure handling** - Prevents system overload
- **Regional distribution** - Multi-zone message delivery

## **🔐 Security & Access Control**

### **Authentication & Authorization**
```yaml
Service Accounts:
  dataflow-pipeline-sa:
    permissions: pubsub.subscriber, bigquery.dataEditor
    topics: iot-telemetry, delivery-events
    
  iot-device-sa:
    permissions: pubsub.publisher
    topics: iot-telemetry only
    
  monitoring-sa:
    permissions: pubsub.subscriber
    topics: system-alerts, dead-letter
```

### **Message Security**
- **Encryption in transit** - TLS 1.2+ for all connections
- **Encryption at rest** - Google-managed encryption keys
- **Access control** - IAM-based topic and subscription permissions
- **Message filtering** - Subscription-level content filtering

### **Compliance Features**
- **Audit logging** - All publish/subscribe operations logged
- **Data retention** - Configurable per topic (7-30 days)
- **Geographic controls** - Regional message storage
- **GDPR compliance** - Data deletion capabilities

## **📈 Monitoring & Observability**

### **Key Metrics**
```yaml
Message Metrics:
  - Messages published per topic
  - Messages consumed per subscription
  - Unacknowledged message count
  - Message latency (publish to consume)
  
Error Metrics:
  - Failed deliveries
  - Dead letter queue size
  - Subscription errors
  - Acknowledgment timeouts
  
Resource Metrics:
  - Subscription CPU usage
  - Network throughput
  - Storage usage per topic
  - Cost per message
```

### **Alerting Thresholds**
```yaml
Critical Alerts:
  - Dead letter queue > 100 messages
  - Message latency > 5 seconds
  - Unacknowledged messages > 1000
  
Warning Alerts:
  - Subscription lag > 60 seconds
  - Error rate > 5%
  - Cost increase > 20% week-over-week
```

### **Dashboard Integration**
- **Cloud Monitoring** - Built-in Pub/Sub metrics
- **Custom dashboards** - Business KPI visualization
- **Real-time alerts** - Slack/email notifications
- **Log analysis** - Error pattern detection

## **🔄 Integration Points**

### **Data Pipeline Integration**
```python
# Dataflow pipeline subscription
from apache_beam.io import ReadFromPubSub
from apache_beam.io import WriteToBigQuery

messages = pipeline | ReadFromPubSub(subscription='iot-telemetry-subscription')
processed = messages | 'ProcessTelemetry' >> beam.ParDo(ProcessTelemetryFn())
processed | WriteToBigQuery(table='analytics.iot_telemetry')
```

### **AI Agent Integration**
```python
# Agent listening for events
from google.cloud import pubsub_v1

def process_delivery_event(message):
    event = json.loads(message.data)
    if event['event_type'] == 'delivery_complete':
        notify_customer(event['customer'])
        update_route_optimization(event['vehicle_id'])
    message.ack()

subscriber.subscribe(delivery_events_subscription, process_delivery_event)
```

### **Frontend Integration**
```javascript
// Real-time dashboard updates
const subscription = pubsub.subscription('analytics-pull-subscription');
subscription.on('message', (message) => {
  const telemetry = JSON.parse(message.data);
  updateVehiclePosition(telemetry.vehicle_id, telemetry.location);
  message.ack();
});
```

## **🚀 Future Enhancements**

### **Phase 2 Additions**
- **Message schemas** - Formal schema registry and validation
- **Exactly-once delivery** - For critical financial transactions  
- **Message ordering** - Global ordering for audit trails
- **Cross-region replication** - Disaster recovery capabilities

### **Advanced Features**
- **Message transformation** - Built-in data enrichment
- **Content-based routing** - Dynamic subscription assignment
- **Stream analytics** - Real-time aggregation and windowing
- **Integration APIs** - Connect external systems seamlessly

### **Operational Improvements**
- **Automated scaling** - ML-based capacity planning
- **Cost optimization** - Intelligent message retention
- **Performance tuning** - Auto-configuration optimization
- **Advanced monitoring** - Predictive alerting

This Pub/Sub configuration forms the **nervous system** of the Intelligent DataOps Platform, enabling real-time communication and event-driven architecture across all components.