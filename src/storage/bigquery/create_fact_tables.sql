-- =============================================================================
-- BigQuery Data Warehouse - Fact Tables Creation Script
-- =============================================================================
-- Purpose: Create all fact tables for time-series and event data
-- Usage: bq query --use_legacy_sql=false < create_fact_tables.sql
-- =============================================================================

-- Set the target dataset
-- Note: Ensure intelligent_dataops_analytics dataset exists before running

-- =============================================================================
-- 1. IoT Telemetry Fact Table (Primary Time-Series Data)
-- =============================================================================

CREATE OR REPLACE TABLE `intelligent_dataops_analytics.iot_telemetry_fact` (
  -- Time dimension (Partition key)
  event_date DATE NOT NULL OPTIONS(description="Partition key for daily data organization"),
  event_timestamp TIMESTAMP NOT NULL OPTIONS(description="Precise timestamp of telemetry event"),
  
  -- Location data
  latitude FLOAT64 NOT NULL OPTIONS(description="GPS latitude coordinate"),
  longitude FLOAT64 NOT NULL OPTIONS(description="GPS longitude coordinate"), 
  location_accuracy FLOAT64 OPTIONS(description="GPS accuracy in meters"),
  
  -- Vehicle metrics
  vehicle_key STRING NOT NULL OPTIONS(description="Foreign key to vehicle_dim"),
  speed_kmh FLOAT64 OPTIONS(description="Vehicle speed in kilometers per hour"),
  fuel_level_percent FLOAT64 OPTIONS(description="Fuel tank level percentage (0-100)"),
  engine_status STRING OPTIONS(description="Engine status: running, idle, off"),
  odometer_km INTEGER OPTIONS(description="Vehicle odometer reading in kilometers"),
  engine_temperature FLOAT64 OPTIONS(description="Engine temperature in Celsius"),
  
  -- Contextual data
  driver_key STRING OPTIONS(description="Foreign key to driver_dim"),
  route_key STRING OPTIONS(description="Foreign key to route_dim"),
  
  -- Data quality and lineage
  data_quality_score FLOAT64 OPTIONS(description="Computed data quality score (0.0-1.0)"),
  location_valid BOOLEAN OPTIONS(description="GPS coordinate validation flag"),
  source_system STRING OPTIONS(description="Source system identifier"),
  processed_at TIMESTAMP OPTIONS(description="Pipeline processing timestamp"),
  
  -- Business keys for joins
  tenant_id STRING NOT NULL OPTIONS(description="Multi-tenant isolation key")
)
PARTITION BY event_date
CLUSTER BY vehicle_key, tenant_id
OPTIONS (
  description="Primary fact table for IoT telemetry data with daily partitioning and 7-year retention",
  partition_expiration_days=2555,  -- 7 years retention
  labels=[("environment", "production"), ("data_type", "telemetry")]
);

-- =============================================================================  
-- 2. Delivery Events Fact Table
-- =============================================================================

CREATE OR REPLACE TABLE `intelligent_dataops_analytics.delivery_events_fact` (
  -- Time dimension
  event_date DATE NOT NULL OPTIONS(description="Partition key for daily events"),
  event_timestamp TIMESTAMP NOT NULL OPTIONS(description="Event occurrence timestamp"),
  
  -- Event details
  delivery_id STRING NOT NULL OPTIONS(description="Unique delivery identifier"),
  event_type STRING NOT NULL OPTIONS(description="Event type: pickup, delivery, exception"),
  event_status STRING NOT NULL OPTIONS(description="Event status: completed, failed, delayed, in_progress"),
  
  -- Location context
  latitude FLOAT64 OPTIONS(description="Event location latitude"),
  longitude FLOAT64 OPTIONS(description="Event location longitude"),
  location_key STRING OPTIONS(description="Foreign key to location_dim"),
  
  -- Associations
  vehicle_key STRING NOT NULL OPTIONS(description="Foreign key to vehicle_dim"),
  driver_key STRING NOT NULL OPTIONS(description="Foreign key to driver_dim"), 
  route_key STRING OPTIONS(description="Foreign key to route_dim"),
  customer_key STRING NOT NULL OPTIONS(description="Foreign key to customer_dim"),
  
  -- Performance metrics
  planned_timestamp TIMESTAMP OPTIONS(description="Originally scheduled timestamp"),
  actual_timestamp TIMESTAMP OPTIONS(description="Actual completion timestamp"),
  delay_minutes INTEGER OPTIONS(description="Delay in minutes (negative for early)"),
  
  -- Additional context
  exception_reason STRING OPTIONS(description="Reason for exceptions or delays"),
  delivery_notes STRING OPTIONS(description="Driver or system notes"),
  signature_captured BOOLEAN OPTIONS(description="Delivery signature confirmation"),
  
  -- Business context
  tenant_id STRING NOT NULL OPTIONS(description="Multi-tenant isolation key"),
  created_at TIMESTAMP NOT NULL OPTIONS(description="Record creation timestamp")
)
PARTITION BY event_date
CLUSTER BY customer_key, vehicle_key, tenant_id
OPTIONS (
  description="Delivery and pickup events with performance tracking",
  partition_expiration_days=2555,
  labels=[("environment", "production"), ("data_type", "events")]
);

-- =============================================================================
-- 3. Maintenance Events Fact Table  
-- =============================================================================

CREATE OR REPLACE TABLE `intelligent_dataops_analytics.maintenance_events_fact` (
  -- Time dimension
  event_date DATE NOT NULL OPTIONS(description="Partition key for maintenance events"),
  event_timestamp TIMESTAMP NOT NULL OPTIONS(description="Maintenance event timestamp"),
  
  -- Maintenance details
  maintenance_id STRING NOT NULL OPTIONS(description="Unique maintenance record identifier"),
  maintenance_type STRING NOT NULL OPTIONS(description="Type: scheduled, unscheduled, emergency"),
  service_category STRING OPTIONS(description="Category: engine, transmission, tires, electrical, etc."),
  work_order_number STRING OPTIONS(description="External work order reference"),
  
  -- Vehicle context
  vehicle_key STRING NOT NULL OPTIONS(description="Foreign key to vehicle_dim"),
  odometer_at_service INTEGER OPTIONS(description="Vehicle odometer at time of service"),
  
  -- Cost and performance metrics
  labor_hours FLOAT64 OPTIONS(description="Labor hours for maintenance work"),
  labor_cost_usd NUMERIC(10,2) OPTIONS(description="Labor cost in USD"),
  parts_cost_usd NUMERIC(10,2) OPTIONS(description="Parts and materials cost in USD"),
  total_cost_usd NUMERIC(10,2) OPTIONS(description="Total maintenance cost in USD"),
  downtime_hours FLOAT64 OPTIONS(description="Vehicle downtime during maintenance"),
  
  -- Service details
  service_location_key STRING OPTIONS(description="Foreign key to service location"),
  service_provider STRING OPTIONS(description="Maintenance provider/vendor"),
  technician_id STRING OPTIONS(description="Service technician identifier"),
  
  -- Maintenance outcome
  completion_status STRING OPTIONS(description="Status: completed, partial, failed"),
  next_service_due_km INTEGER OPTIONS(description="Next scheduled service odometer"),
  warranty_coverage BOOLEAN OPTIONS(description="Whether covered by warranty"),
  
  -- Business context
  tenant_id STRING NOT NULL OPTIONS(description="Multi-tenant isolation key"),
  created_at TIMESTAMP NOT NULL OPTIONS(description="Record creation timestamp"),
  updated_at TIMESTAMP OPTIONS(description="Record last update timestamp")
)
PARTITION BY event_date  
CLUSTER BY vehicle_key, maintenance_type, tenant_id
OPTIONS (
  description="Vehicle maintenance events and cost tracking",
  partition_expiration_days=2555,
  labels=[("environment", "production"), ("data_type", "maintenance")]
);

-- =============================================================================
-- 4. Fuel Transactions Fact Table
-- =============================================================================

CREATE OR REPLACE TABLE `intelligent_dataops_analytics.fuel_transactions_fact` (
  -- Time dimension
  transaction_date DATE NOT NULL OPTIONS(description="Partition key for fuel transactions"),
  transaction_timestamp TIMESTAMP NOT NULL OPTIONS(description="Fuel purchase timestamp"),
  
  -- Transaction details
  transaction_id STRING NOT NULL OPTIONS(description="Unique transaction identifier"),
  fuel_station_id STRING OPTIONS(description="Fuel station identifier"),
  receipt_number STRING OPTIONS(description="Fuel receipt reference number"),
  
  -- Vehicle and driver context
  vehicle_key STRING NOT NULL OPTIONS(description="Foreign key to vehicle_dim"),
  driver_key STRING OPTIONS(description="Foreign key to driver_dim"),
  odometer_at_fuel INTEGER OPTIONS(description="Vehicle odometer at fuel-up"),
  
  -- Fuel details
  fuel_type STRING OPTIONS(description="Fuel type: diesel, gasoline, electric"),
  fuel_quantity_liters FLOAT64 OPTIONS(description="Fuel quantity in liters"),
  fuel_price_per_liter NUMERIC(8,4) OPTIONS(description="Price per liter in local currency"),
  total_cost_usd NUMERIC(10,2) OPTIONS(description="Total fuel cost in USD"),
  
  -- Location context
  latitude FLOAT64 OPTIONS(description="Fuel station latitude"),
  longitude FLOAT64 OPTIONS(description="Fuel station longitude"),
  
  -- Performance metrics
  previous_fuel_odometer INTEGER OPTIONS(description="Previous fuel-up odometer reading"),
  distance_since_last_fuel INTEGER OPTIONS(description="Distance traveled since last fuel-up"),
  fuel_efficiency_kmpl FLOAT64 OPTIONS(description="Calculated fuel efficiency km per liter"),
  
  -- Payment and approval
  payment_method STRING OPTIONS(description="Payment method: fleet_card, cash, credit"),
  approval_status STRING OPTIONS(description="Transaction approval status"),
  approved_by STRING OPTIONS(description="Approval authority"),
  
  -- Business context
  tenant_id STRING NOT NULL OPTIONS(description="Multi-tenant isolation key"),
  created_at TIMESTAMP NOT NULL OPTIONS(description="Record creation timestamp")
)
PARTITION BY transaction_date
CLUSTER BY vehicle_key, tenant_id
OPTIONS (
  description="Fuel transactions and efficiency tracking",
  partition_expiration_days=2555,
  labels=[("environment", "production"), ("data_type", "transactions")]
);

-- =============================================================================
-- Create indexes for performance optimization
-- =============================================================================

-- Note: BigQuery automatically creates indexes based on clustering keys
-- Additional custom indexes can be created as needed for specific query patterns

-- ✅ Fact tables created successfully!
-- 📊 Tables created:
--   - iot_telemetry_fact (partitioned by event_date)  
--   - delivery_events_fact (partitioned by event_date)
--   - maintenance_events_fact (partitioned by event_date)
--   - fuel_transactions_fact (partitioned by transaction_date)
--
-- 🔑 All tables are clustered for optimal query performance
-- 📅 Partition expiration: 7 years (2555 days)
-- 🏷️  Labels applied for resource management