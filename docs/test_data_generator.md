# Test Data Generator (test_data_generator.py)

## **🎯 Purpose**

The `test_data_generator.py` creates realistic IoT telemetry data for testing and development of the Intelligent DataOps Platform. It simulates a fleet of vehicles sending GPS, speed, fuel, and engine status data to Pub/Sub topics.

## **📊 Data Generation Flow**
```
Vehicle Fleet Config → Message Generation → JSON Encoding → Pub/Sub Publishing
                                         ↳ Data Quality Issues (5% random)
```

## **🚗 Fleet Simulation**

### **Vehicle Configuration**
- **Fleet size**: 5 vehicles (VH001-VH005) for cost control
- **Vehicle types**: truck, van, pickup (randomly assigned)
- **Driver assignments**: DR001-DR005 mapped to vehicles
- **Specifications**: max_speed, fuel_capacity vary by vehicle

### **Geographic Coverage**
- **Base locations**: 5 major logistics hubs
  - Chicago Distribution (41.8781, -87.6298)
  - Indianapolis Hub (39.7684, -86.1581)
  - Milwaukee Depot (43.0389, -87.9065)
  - Detroit Center (42.3314, -83.0458)
  - Columbus Terminal (39.9612, -82.9988)
- **Movement simulation**: ±0.1 degree radius (~11km) around bases

## **📡 Message Structure**

### **Complete Generated JSON Schema**
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
    "data_source": "python_generator"
}
```

### **Field Descriptions**
```yaml
vehicle_id: "VH001-VH005" - Unique vehicle identifier
device_type: "gps_tracker|obd_device|fuel_sensor" - IoT device type
timestamp: ISO 8601 UTC timestamp - Event occurrence time
latitude: Float - GPS latitude (-90 to 90)
longitude: Float - GPS longitude (-180 to 180)
speed_kmh: Integer 0-120 - Vehicle speed in kilometers per hour
fuel_level: Float 0.0-1.0 - Fuel level as decimal percentage
engine_status: "running|idle|off" - Current engine state
driver_id: "DR001-DR010" - Assigned driver identifier
route_id: "RT001-RT020" - Current route assignment
odometer: Integer 50000-200000 - Vehicle mileage reading
temperature: Integer -10 to 30 - Engine/ambient temperature in Celsius
generated_at: ISO 8601 UTC timestamp - Message generation time
data_source: "python_generator" - Source identification
```

## **🎲 Realistic Data Patterns**

### **Speed Simulation**
- **Stationary** (10%): speed = 0 (parked/loading)
- **City driving** (30%): 5-50 km/h
- **Highway driving** (60%): 50-120 km/h based on vehicle max_speed

### **Engine Status Logic**
- **Moving vehicles**: "running" (75%) or "idle" (25%)
- **Stationary vehicles**: "idle" (50%) or "off" (50%)

### **Data Quality Issues**
- **5% random missing fields** - simulates sensor failures
- **Realistic ranges** - lat/lon, speed, fuel within bounds
- **Temporal consistency** - proper ISO timestamp formatting

## **🔧 Technical Implementation**

### **Python Libraries**
```python
from google.cloud import pubsub_v1    # Pub/Sub publishing
import json, random, time             # Data generation
from datetime import datetime         # Timestamp handling
```

### **Class Structure**
```python
class IoTDataGenerator:
    def __init__(project_id, topic_name)     # Initialize Pub/Sub client
    def generate_telemetry_message(vehicle)  # Create single message
    def publish_message(message)             # Send to Pub/Sub
    def generate_batch_data(num_messages)    # Batch mode
    def generate_continuous_data(duration)   # Streaming mode
```

### **Error Handling**
- **JSON parsing errors** - gracefully handled
- **Pub/Sub connection issues** - timeout with 10-second limit
- **Publishing failures** - logged but don't stop generation
- **Python 3.13 compatibility** - timeout handling for gRPC issues

## **⚡ Usage Modes**

### **Batch Mode** (Default)
```bash
python test_data_generator.py --project manish-sandpit --topic iot-telemetry --batch-size 5
```
- **Use case**: Quick testing, pipeline validation
- **Execution time**: ~4-8 seconds for 5 messages
- **Message interval**: 1 second between messages

### **Continuous Mode**
```bash
python test_data_generator.py --project manish-sandpit --topic iot-telemetry --continuous --duration 10 --rate 6
```
- **Use case**: Load testing, sustained data flow simulation
- **Execution time**: Exactly as specified (10 minutes)
- **Message rate**: 6 messages/minute (configurable)

## **🚨 Known Issues & Solutions**

### **Python 3.13 Compatibility**
- **Issue**: `future.result()` hangs due to gRPC/protobuf conflicts
- **Solution**: 10-second timeout with graceful error handling
- **Impact**: Timeout warnings appear but messages publish successfully
- **Workaround**: Use `generate_test_data.sh` for critical testing

### **Performance Characteristics**
- **Success scenario**: Completes in expected time with success messages
- **Timeout scenario**: Shows timeout warnings but messages reach Pub/Sub
- **Failure scenario**: Script hangs >15 seconds (rare with timeout fix)

## **🔍 Monitoring & Validation**

### **Publishing Verification**
```bash
# Check messages arrived in subscription
gcloud pubsub subscriptions pull iot-telemetry-subscription --limit=3 --auto-ack
```

### **Output Indicators**
```
✅ Success: "Published message for vehicle VH001"
⚠️  Timeout: "Timeout publishing message for vehicle VH001"
❌ Error: "Error publishing message: [details]"
```

### **Data Quality Metrics**
- **Message completeness**: 95% complete, 5% with missing fields
- **Geographic distribution**: Evenly spread across 5 hub locations
- **Speed realism**: Follows stationary/city/highway patterns
- **Temporal accuracy**: Proper UTC timestamps

## **💼 Business Value**

### **Development & Testing**
- **Pipeline validation** - Test data processing workflows
- **Performance testing** - Load generation for capacity planning
- **Error simulation** - Test error handling with incomplete data
- **Integration testing** - End-to-end system validation

### **Cost Management**
- **Controlled volume** - Limited fleet size prevents runaway costs
- **Realistic patterns** - Representative of actual IoT data
- **Flexible scaling** - Adjust message rates for different test scenarios

### **Data Science Support**
- **Model training** - Generate datasets for ML development
- **Algorithm testing** - Consistent data for reproducible results
- **Feature engineering** - Test new data enrichment ideas

## **🔄 Integration Points**

### **Upstream Configuration**
- **GCP Project**: manish-sandpit
- **Authentication**: Application default credentials
- **Virtual environment**: Requires google-cloud-pubsub library

### **Downstream Targets**
- **Primary topic**: `iot-telemetry`
- **Alternative topics**: Can target any Pub/Sub topic
- **Data pipeline**: Feeds into `basic_pipeline.py` for processing

### **Alternatives**
- **Shell script**: `generate_test_data.sh` (gcloud CLI-based)
- **Production data**: Eventually replaced by real IoT devices
- **External APIs**: Could integrate with real fleet management systems

## **🚀 Future Enhancements**

### **Planned Improvements**
- **Python 3.11 environment** - Eliminate timeout issues
- **Configurable patterns** - Vehicle behavior profiles
- **Multi-topic support** - Different device types to different topics
- **Historical data generation** - Backfill for testing analytics

### **Advanced Features**
- **Anomaly injection** - Simulate equipment failures
- **Route simulation** - Realistic GPS tracks between locations
- **Weather integration** - Speed/fuel adjustments for conditions
- **Driver behavior modeling** - Individual driving patterns

This test data generator is **essential for development and testing** of all data processing, analytics, and AI components in the Intelligent DataOps Platform.