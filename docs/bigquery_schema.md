# BigQuery Schema & Data Warehouse

## **🎯 Purpose**

The BigQuery schema defines the **structured data warehouse** for the Intelligent DataOps Platform. It provides optimized storage, querying, and analytics capabilities for IoT telemetry, logistics operations, and business intelligence across the entire supply chain ecosystem.

## **🏗️ Data Warehouse Architecture**
```
BigQuery Project: manish-sandpit
├── intelligent_dataops_analytics (Primary Dataset)
│   ├── iot_telemetry (Partitioned by timestamp)
│   ├── deliveries (Partitioned by scheduled_delivery_date)  
│   └── vehicles (Fleet master data)
└── intelligent_dataops_realtime (Operational Dataset)
    ├── live_vehicle_status (Current positions)
    └── operational_metrics (Real-time KPIs)
```

## **📊 Core Tables Schema**

### **iot_telemetry Table**
```sql
CREATE TABLE `intelligent_dataops_analytics.iot_telemetry` (
  timestamp TIMESTAMP NOT NULL OPTIONS(description="Event timestamp"),
  vehicle_id STRING NOT NULL OPTIONS(description="Vehicle identifier"), 
  device_type STRING NOT NULL OPTIONS(description="IoT device type"),
  latitude FLOAT OPTIONS(description="GPS latitude"),
  longitude FLOAT OPTIONS(description="GPS longitude"),
  speed_kmh FLOAT OPTIONS(description="Vehicle speed in km/h"),
  fuel_level FLOAT OPTIONS(description="Fuel level percentage"),
  engine_status STRING OPTIONS(description="Engine status"),
  raw_data JSON OPTIONS(description="Raw telemetry data")
)
PARTITION BY DATE(timestamp)
CLUSTER BY vehicle_id, device_type
OPTIONS(
  description="Vehicle IoT telemetry data from fleet devices",
  labels=[("environment", "dev"), ("phase", "1-foundation")]
);
```

**Optimization Features:**
- **Partitioning**: Daily partitions by timestamp for query performance
- **Clustering**: By vehicle_id and device_type for efficient filtering
- **JSON column**: Preserves raw data for future schema evolution
- **Cost optimization**: Automatic partition pruning

### **deliveries Table**
```sql
CREATE TABLE `intelligent_dataops_analytics.deliveries` (
  delivery_id STRING NOT NULL OPTIONS(description="Unique delivery identifier"),
  customer_id STRING NOT NULL OPTIONS(description="Customer identifier"),
  vehicle_id STRING OPTIONS(description="Assigned vehicle"),
  driver_id STRING OPTIONS(description="Assigned driver"),
  route_id STRING OPTIONS(description="Planned route identifier"),
  
  -- Address information
  pickup_address STRUCT<
    street STRING,
    city STRING, 
    state STRING,
    postal_code STRING,
    country STRING,
    latitude FLOAT,
    longitude FLOAT
  > OPTIONS(description="Pickup location details"),
  
  delivery_address STRUCT<
    street STRING,
    city STRING,
    state STRING, 
    postal_code STRING,
    country STRING,
    latitude FLOAT,
    longitude FLOAT
  > OPTIONS(description="Delivery location details"),
  
  -- Timing information
  scheduled_pickup_time TIMESTAMP OPTIONS(description="Planned pickup time"),
  actual_pickup_time TIMESTAMP OPTIONS(description="Actual pickup time"),
  scheduled_delivery_date DATE NOT NULL OPTIONS(description="Planned delivery date"),
  scheduled_delivery_time TIMESTAMP OPTIONS(description="Planned delivery time"),
  actual_delivery_time TIMESTAMP OPTIONS(description="Actual delivery time"),
  
  -- Status and metrics
  status STRING NOT NULL OPTIONS(description="Current delivery status"),
  priority_level STRING OPTIONS(description="Delivery priority"),
  package_count INT64 OPTIONS(description="Number of packages"),
  total_weight_kg FLOAT OPTIONS(description="Total package weight"),
  delivery_instructions STRING OPTIONS(description="Special delivery notes"),
  
  -- Calculated fields
  estimated_distance_km FLOAT OPTIONS(description="Planned route distance"),
  actual_distance_km FLOAT OPTIONS(description="Actual route distance"),
  delivery_time_variance_minutes INT64 OPTIONS(description="Early/late delivery time"),
  
  -- Metadata
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY scheduled_delivery_date
CLUSTER BY status, route_id
OPTIONS(
  description="Delivery records with pickup/delivery details and performance metrics"
);
```

### **vehicles Table**
```sql
CREATE TABLE `intelligent_dataops_analytics.vehicles` (
  vehicle_id STRING NOT NULL OPTIONS(description="Unique vehicle identifier"),
  fleet_id STRING NOT NULL OPTIONS(description="Fleet group identifier"),
  vehicle_type STRING NOT NULL OPTIONS(description="Vehicle category"),
  
  -- Vehicle specifications  
  make STRING OPTIONS(description="Vehicle manufacturer"),
  model STRING OPTIONS(description="Vehicle model"),
  year INT64 OPTIONS(description="Manufacturing year"), 
  license_plate STRING OPTIONS(description="License plate number"),
  vin STRING OPTIONS(description="Vehicle identification number"),
  
  -- Capacity specifications
  max_weight_capacity_kg FLOAT OPTIONS(description="Maximum cargo weight"),
  max_volume_capacity_m3 FLOAT OPTIONS(description="Maximum cargo volume"),
  fuel_tank_capacity_l FLOAT OPTIONS(description="Fuel tank capacity"),
  max_speed_kmh INT64 OPTIONS(description="Maximum safe speed"),
  
  -- Operational details
  current_odometer_km INT64 OPTIONS(description="Current mileage"),
  last_maintenance_date DATE OPTIONS(description="Last service date"),
  next_maintenance_due_km INT64 OPTIONS(description="Next service mileage"),
  insurance_expiry_date DATE OPTIONS(description="Insurance renewal date"),
  
  -- Status information
  operational_status STRING NOT NULL OPTIONS(description="Vehicle availability"),
  current_location STRUCT<
    latitude FLOAT,
    longitude FLOAT,
    address STRING,
    last_updated TIMESTAMP
  > OPTIONS(description="Last known position"),
  
  -- Metadata
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
CLUSTER BY fleet_id, vehicle_type
OPTIONS(
  description="Fleet vehicle master data and specifications"
);
```

## **📈 Real-time Operational Tables**

### **live_vehicle_status (Realtime Dataset)**
```sql
CREATE TABLE `intelligent_dataops_realtime.live_vehicle_status` (
  vehicle_id STRING NOT NULL,
  timestamp TIMESTAMP NOT NULL,
  latitude FLOAT,
  longitude FLOAT,
  speed_kmh FLOAT,
  heading_degrees FLOAT,
  fuel_level_percent FLOAT,
  engine_status STRING,
  driver_id STRING,
  current_route_id STRING,
  next_stop_eta TIMESTAMP,
  distance_to_destination_km FLOAT
)
PARTITION BY DATE(timestamp)
CLUSTER BY vehicle_id
OPTIONS(
  description="Real-time vehicle positions and status for live tracking",
  labels=[("refresh_rate", "30_seconds"), ("retention", "7_days")]
);
```

### **operational_metrics (Realtime Dataset)**
```sql
CREATE TABLE `intelligent_dataops_realtime.operational_metrics` (
  metric_timestamp TIMESTAMP NOT NULL,
  metric_type STRING NOT NULL,
  metric_name STRING NOT NULL,
  metric_value FLOAT NOT NULL,
  dimensions STRUCT<
    vehicle_id STRING,
    route_id STRING,
    driver_id STRING,
    fleet_id STRING,
    region STRING
  >,
  aggregation_window_minutes INT64,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(metric_timestamp)
CLUSTER BY metric_type, metric_name
OPTIONS(
  description="Real-time operational KPIs and performance metrics"
);
```

## **🔍 Query Optimization Strategies**

### **Partitioning Benefits**
```sql
-- Efficient time-range queries (only scans relevant partitions)
SELECT vehicle_id, AVG(speed_kmh) as avg_speed
FROM `intelligent_dataops_analytics.iot_telemetry`
WHERE DATE(timestamp) BETWEEN '2025-10-01' AND '2025-10-02'
  AND vehicle_id = 'VH001'
GROUP BY vehicle_id;

-- Cost: Scans only 2 days of data instead of entire table
```

### **Clustering Advantages**
```sql
-- Fast vehicle-specific queries (clustered by vehicle_id)
SELECT timestamp, speed_kmh, fuel_level
FROM `intelligent_dataops_analytics.iot_telemetry`  
WHERE vehicle_id IN ('VH001', 'VH002', 'VH003')
  AND DATE(timestamp) = '2025-10-02'
ORDER BY timestamp;

-- Performance: Data co-located for specific vehicles
```

### **Materialized Views**
```sql
-- Pre-aggregated daily vehicle summaries
CREATE MATERIALIZED VIEW `intelligent_dataops_analytics.daily_vehicle_summary`
PARTITION BY summary_date
CLUSTER BY vehicle_id
AS
SELECT 
  DATE(timestamp) as summary_date,
  vehicle_id,
  COUNT(*) as total_readings,
  AVG(speed_kmh) as avg_speed,
  MAX(speed_kmh) as max_speed,
  AVG(fuel_level) as avg_fuel_level,
  MIN(fuel_level) as min_fuel_level,
  SUM(CASE WHEN engine_status = 'running' THEN 1 ELSE 0 END) as running_time_readings
FROM `intelligent_dataops_analytics.iot_telemetry`
GROUP BY DATE(timestamp), vehicle_id;
```

## **📊 Analytics & Reporting Queries**

### **Fleet Performance Dashboard**
```sql
-- Real-time fleet overview
WITH fleet_status AS (
  SELECT 
    v.vehicle_id,
    v.vehicle_type,
    v.operational_status,
    t.timestamp,
    t.speed_kmh,
    t.fuel_level,
    t.engine_status,
    ROW_NUMBER() OVER (PARTITION BY v.vehicle_id ORDER BY t.timestamp DESC) as rn
  FROM `intelligent_dataops_analytics.vehicles` v
  LEFT JOIN `intelligent_dataops_analytics.iot_telemetry` t 
    ON v.vehicle_id = t.vehicle_id 
    AND DATE(t.timestamp) = CURRENT_DATE()
)
SELECT 
  vehicle_type,
  COUNT(*) as total_vehicles,
  SUM(CASE WHEN operational_status = 'active' THEN 1 ELSE 0 END) as active_vehicles,
  AVG(speed_kmh) as avg_current_speed,
  AVG(fuel_level) as avg_fuel_level
FROM fleet_status 
WHERE rn = 1
GROUP BY vehicle_type;
```

### **Delivery Performance Analysis**  
```sql
-- Delivery timeliness analysis
SELECT 
  DATE(scheduled_delivery_date) as delivery_date,
  status,
  COUNT(*) as delivery_count,
  AVG(delivery_time_variance_minutes) as avg_variance_minutes,
  COUNTIF(delivery_time_variance_minutes <= 0) as on_time_deliveries,
  COUNTIF(delivery_time_variance_minutes > 0) as late_deliveries,
  ROUND(COUNTIF(delivery_time_variance_minutes <= 0) * 100.0 / COUNT(*), 2) as on_time_percentage
FROM `intelligent_dataops_analytics.deliveries`
WHERE scheduled_delivery_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY DATE(scheduled_delivery_date), status
ORDER BY delivery_date DESC;
```

### **Route Efficiency Metrics**
```sql
-- Route performance and fuel efficiency
SELECT 
  d.route_id,
  COUNT(DISTINCT d.delivery_id) as total_deliveries,
  AVG(d.actual_distance_km) as avg_distance_km,
  AVG(t.fuel_efficiency) as avg_fuel_efficiency
FROM `intelligent_dataops_analytics.deliveries` d
JOIN (
  SELECT 
    vehicle_id,
    DATE(timestamp) as date,
    (MAX(odometer_km) - MIN(odometer_km)) / NULLIF(SUM(fuel_consumed_l), 0) as fuel_efficiency
  FROM `intelligent_dataops_analytics.iot_telemetry`
  WHERE DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  GROUP BY vehicle_id, DATE(timestamp)
) t ON d.vehicle_id = t.vehicle_id AND DATE(d.actual_delivery_time) = t.date
WHERE d.status = 'delivered'
  AND d.actual_delivery_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
GROUP BY d.route_id
HAVING total_deliveries >= 5
ORDER BY avg_fuel_efficiency DESC;
```

## **💰 Cost Management**

### **Storage Optimization**
```sql
-- Table size and cost analysis
SELECT 
  table_name,
  ROUND(size_bytes / POWER(1024, 3), 2) as size_gb,
  ROUND(size_bytes / POWER(1024, 3) * 0.020, 2) as monthly_storage_cost_usd,
  partition_count,
  creation_time
FROM `manish-sandpit.intelligent_dataops_analytics.INFORMATION_SCHEMA.TABLES`
WHERE table_type = 'BASE TABLE'
ORDER BY size_bytes DESC;
```

### **Query Cost Monitoring**
```sql
-- Expensive query identification  
SELECT 
  user_email,
  job_id,
  query,
  total_bytes_processed,
  ROUND(total_bytes_processed / POWER(1024, 4), 6) as tb_processed,
  ROUND(total_bytes_processed / POWER(1024, 4) * 5.00, 4) as cost_usd,
  creation_time
FROM `manish-sandpit.region-us-central1.INFORMATION_SCHEMA.JOBS_BY_PROJECT`  
WHERE DATE(creation_time) = CURRENT_DATE()
  AND total_bytes_processed > 1000000000  -- >1GB queries
ORDER BY total_bytes_processed DESC
LIMIT 10;
```

### **Lifecycle Management**
```sql
-- Automated data retention (via Terraform)
resource "google_bigquery_table" "iot_telemetry" {
  table_id = "iot_telemetry"
  
  time_partitioning {
    type                     = "DAY"
    expiration_ms           = 7776000000  # 90 days
    require_partition_filter = true
  }
}
```

## **🔐 Security & Access Control**

### **Row-Level Security**
```sql
-- Create row access policy for vehicle data
CREATE ROW ACCESS POLICY fleet_access_policy
ON `intelligent_dataops_analytics.iot_telemetry`
GRANT TO ("serviceAccount:dataflow-sa@manish-sandpit.iam.gserviceaccount.com")
FILTER USING (vehicle_id IN (
  SELECT vehicle_id 
  FROM `intelligent_dataops_analytics.vehicles` 
  WHERE fleet_id = SESSION_USER().fleet_assignment
));
```

### **Column-Level Security**
```sql
-- Sensitive data masking for compliance
CREATE OR REPLACE VIEW `intelligent_dataops_analytics.deliveries_public` AS
SELECT 
  delivery_id,
  vehicle_id,
  route_id,
  scheduled_delivery_date,
  status,
  -- Mask sensitive customer data
  SHA256(customer_id) as customer_hash,
  STRUCT(
    delivery_address.city,
    delivery_address.state,
    delivery_address.postal_code
  ) as delivery_location
FROM `intelligent_dataops_analytics.deliveries`;
```

## **🚀 Future Schema Evolution**

### **Phase 2 Enhancements**
```sql
-- AI/ML training datasets
CREATE TABLE `intelligent_dataops_ml.training_features` (
  feature_timestamp TIMESTAMP,
  vehicle_id STRING,
  route_id STRING,
  features STRUCT<
    traffic_density FLOAT,
    weather_conditions STRING,
    driver_behavior_score FLOAT,
    vehicle_health_index FLOAT
  >,
  target_variables STRUCT<
    eta_accuracy_minutes FLOAT,
    fuel_efficiency_actual FLOAT,
    delivery_success_rate FLOAT
  >
);

-- Real-time predictions
CREATE TABLE `intelligent_dataops_realtime.ml_predictions` (
  prediction_timestamp TIMESTAMP,
  model_version STRING,
  vehicle_id STRING,
  prediction_type STRING,
  prediction_value FLOAT,
  confidence_score FLOAT,
  input_features JSON
);
```

This BigQuery schema provides the **analytical foundation** for the Intelligent DataOps Platform, enabling real-time insights, historical analysis, and data-driven decision making across the entire logistics operation.