# BigQuery Data Warehouse Schema Design

## Overview

This document describes the deployed BigQuery data warehouse for the Intelligent DataOps Platform. The schema follows dimensional modeling principles and supports comprehensive logistics and supply chain analytics through a star schema design with fact tables, dimension tables, aggregation tables, and ML feature tables.

## Deployed Architecture

```
intelligent_dataops_analytics (Dataset)
├── 📊 FACT TABLES (4 tables - Time-Series Data)
│   ├── iot_telemetry_fact (Primary telemetry data)
│   ├── delivery_events_fact (Delivery/pickup events)
│   ├── maintenance_events_fact (Vehicle maintenance)
│   └── fuel_transactions_fact (Fuel purchases)
├── 📋 DIMENSION TABLES (5 tables - Reference Data)
│   ├── vehicle_dim (Vehicle master with SCD Type 2)
│   ├── driver_dim (Driver information with privacy)
│   ├── route_dim (Route definitions with waypoints)
│   ├── customer_dim (Customer master with SLA)
│   └── location_dim (Geographic locations)
├── 📈 AGGREGATION TABLES (5 tables - Pre-computed Metrics)
│   ├── vehicle_daily_summary (Daily vehicle performance)
│   ├── driver_performance_summary (Daily driver analytics)
│   ├── route_efficiency_summary (Route optimization metrics)
│   ├── customer_service_summary (Customer satisfaction)
│   └── fleet_operations_summary (Executive dashboards)
├── 🤖 ML FEATURE TABLES (4 tables - Analytics Support)
│   ├── driving_behavior_features (Driver safety prediction)
│   ├── vehicle_health_features (Predictive maintenance)
│   ├── route_optimization_features (ETA prediction)
│   └── anomaly_detection_features (Fraud detection)
├── 📊 ANALYTICS VIEWS (2 views - ML Support)
│   ├── driver_features_latest (Latest driver features)
│   └── route_features_latest (Latest route features)
└── 🗂️ OPERATIONAL TABLES (4 tables - Phase 1 Legacy)
    ├── iot_telemetry (Raw streaming data)
    ├── vehicles (Vehicle master data)
    ├── deliveries (Delivery operations)
    └── iot_telemetry_error_records (Error handling)
```

## Data Flow and ETL Procedures

```
Raw/Operational Data → ETL Procedures → Dimensional Model → Analytics

iot_telemetry ────────► sp_load_iot_telemetry ────► iot_telemetry_fact
vehicles ─────────────► sp_load_dimensions ──────► vehicle_dim
deliveries ───────────► sp_load_dimensions ──────► delivery_events_fact
telemetry drivers ────► sp_load_dimensions ──────► driver_dim
telemetry routes ─────► sp_load_dimensions ──────► route_dim
GPS clusters ─────────► sp_load_dimensions ──────► location_dim

Fact Tables ──────────► sp_generate_daily_summaries ──► Aggregation Tables
Aggregation Tables ───► sp_update_ml_features ────────► ML Feature Tables
```

## 📊 Fact Tables (Time-Series Data)

### 1. iot_telemetry_fact
**Purpose**: Primary repository for processed IoT telemetry data with dimensional relationships  
**Source Data**: `iot_telemetry` (operational table)  
**ETL Procedure**: `sp_load_iot_telemetry`  
**Partitioning**: Daily by `event_date`  
**Retention**: 7 years (2555 days)  
**Clustering**: `vehicle_key, tenant_id`

**Key Columns**:
- Time: `event_date`, `event_timestamp`
- Location: `latitude`, `longitude`, `location_accuracy`
- Vehicle metrics: `speed_kmh`, `fuel_level_percent`, `engine_status`, `odometer_km`
- Foreign keys: `vehicle_key`, `driver_key`, `route_key`
- Data quality: `data_quality_score`, `location_valid`

### 2. delivery_events_fact
**Purpose**: Track all delivery and pickup events with performance metrics  
**Source Data**: `deliveries` table + event generation logic  
**ETL Procedure**: `sp_load_dimensions` (events creation)  
**Partitioning**: Daily by `event_date`  
**Retention**: 7 years (2555 days)  
**Clustering**: `customer_key, vehicle_key, tenant_id`

**Key Columns**:
- Event details: `delivery_id`, `event_type`, `event_status`
- Performance: `planned_timestamp`, `actual_timestamp`, `delay_minutes`
- Associations: `vehicle_key`, `driver_key`, `route_key`, `customer_key`

### 3. maintenance_events_fact
**Purpose**: Vehicle maintenance tracking and cost analysis  
**Source Data**: External maintenance systems (to be integrated)  
**ETL Procedure**: To be developed  
**Partitioning**: Daily by `event_date`  
**Retention**: 7 years (2555 days)  
**Clustering**: `vehicle_key, maintenance_type, tenant_id`

**Key Columns**:
- Maintenance details: `maintenance_type`, `service_category`
- Costs: `labor_cost_usd`, `parts_cost_usd`, `total_cost_usd`
- Performance: `downtime_hours`, `completion_status`

### 4. fuel_transactions_fact
**Purpose**: Fuel purchase tracking and efficiency calculation  
**Source Data**: Fleet card systems (to be integrated)  
**ETL Procedure**: To be developed  
**Partitioning**: Daily by `transaction_date`  
**Retention**: 7 years (2555 days)  
**Clustering**: `vehicle_key, tenant_id`

**Key Columns**:
- Transaction: `fuel_quantity_liters`, `fuel_price_per_liter`, `total_cost_usd`
- Efficiency: `fuel_efficiency_kmpl`, `distance_since_last_fuel`
- Payment: `payment_method`, `approval_status`

## 📋 Dimension Tables (Reference Data)

### 1. vehicle_dim (SCD Type 2)
**Purpose**: Vehicle master data with historical tracking  
**Source Data**: `vehicles` table  
**ETL Procedure**: `sp_load_dimensions`  
**SCD Type**: Type 2 with `effective_from_date`, `effective_to_date`, `is_current`  
**Clustering**: `tenant_id, is_current, vehicle_id`

**Key Features**:
- Vehicle specifications: `make`, `model`, `year`, `vin`, `engine_type`
- Capacity: `max_capacity_kg`, `fuel_tank_capacity_liters`
- Financial: `acquisition_cost_usd`, `monthly_depreciation_usd`
- Assignment: `home_depot_key`, `assigned_region`, `fleet_group`

### 2. driver_dim (SCD Type 2)
**Purpose**: Privacy-compliant driver information with historical tracking  
**Source Data**: Unique drivers extracted from `iot_telemetry`  
**ETL Procedure**: `sp_load_dimensions`  
**SCD Type**: Type 2 with historical employment changes  
**Clustering**: `tenant_id, is_current, driver_id`

**Key Features**:
- Privacy: `driver_code`, hashed PII fields
- Qualifications: `license_class`, `safety_certifications`, `experience_years`
- Employment: `hire_date`, `employment_type`, `employment_status`
- Performance: `safety_score_baseline`, `performance_tier`

### 3. route_dim
**Purpose**: Route definitions with operational characteristics  
**Source Data**: Unique routes extracted from `iot_telemetry`  
**ETL Procedure**: `sp_load_dimensions`  
**Active Flag**: `is_active` for current routes  
**Clustering**: `tenant_id, is_active, route_type`

**Key Features**:
- Route planning: `planned_distance_km`, `estimated_duration_minutes`
- Structure: `waypoints` array with stops and timing
- Performance: `baseline_fuel_consumption_liters`, `difficulty_rating`
- Business: `primary_customer_key`, `customer_sla_minutes`

### 4. customer_dim (SCD Type 2)
**Purpose**: Customer master data with service level agreements  
**Source Data**: To be integrated from CRM systems  
**ETL Procedure**: `sp_load_dimensions` (template created)  
**SCD Type**: Type 2 for contract and tier changes  
**Clustering**: `tenant_id, is_current, customer_tier`

**Key Features**:
- Customer info: `customer_name`, `customer_type`, `industry_sector`
- Service: `service_level_agreement`, `delivery_instructions`
- Business: `customer_tier`, `credit_limit_usd`, `payment_terms_days`
- Geographic: `billing_address`, `preferred_delivery_windows`

### 5. location_dim
**Purpose**: Geographic locations with operational details  
**Source Data**: GPS coordinate clusters from `iot_telemetry`  
**ETL Procedure**: `sp_load_dimensions` (frequent locations ≥5 visits)  
**Clustering**: `tenant_id, location_type, country`

**Key Features**:
- Coordinates: `latitude`, `longitude`, `elevation_meters`
- Address: `street_address`, `city`, `state_province`, `country`
- Operations: `operating_hours`, `loading_dock_available`
- Access: `vehicle_access_restrictions`, `parking_spaces_available`

## 📈 Aggregation Tables (Pre-computed Metrics)

### 1. vehicle_daily_summary
**Purpose**: Daily vehicle performance aggregations for fast analytics  
**Source Data**: `iot_telemetry_fact` + `delivery_events_fact`  
**ETL Procedure**: `sp_generate_daily_summaries`  
**Partitioning**: Daily by `summary_date`  
**Retention**: 7 years (2555 days)  
**Clustering**: `vehicle_key, tenant_id`

**Key Metrics**:
- Distance: `total_distance_km`, `total_driving_hours`, `total_idle_hours`
- Fuel: `fuel_consumed_liters`, `fuel_efficiency_kmpl`, `fuel_cost_usd`
- Performance: `deliveries_completed`, `on_time_deliveries`, `safety_score`
- Costs: `total_operational_cost_usd`, `cost_per_km_usd`, `cost_per_delivery_usd`

### 2. driver_performance_summary
**Purpose**: Daily driver analytics and performance rankings  
**Source Data**: `iot_telemetry_fact` + `vehicle_daily_summary`  
**ETL Procedure**: `sp_generate_daily_summaries`  
**Partitioning**: Daily by `summary_date`  
**Retention**: 3 years (1095 days)  
**Clustering**: `driver_key, tenant_id`

**Key Metrics**:
- Productivity: `deliveries_per_hour`, `miles_per_hour`, `total_working_hours`
- Safety: `safety_violations`, `safety_score`, `aggressive_driving_events`
- Efficiency: `fuel_efficiency_vs_baseline`, `speed_compliance_percentage`
- Rankings: `safety_rank`, `efficiency_rank`, `customer_service_rank`

### 3. route_efficiency_summary
**Purpose**: Route performance analysis and optimization metrics  
**Source Data**: `delivery_events_fact` + `iot_telemetry_fact`  
**ETL Procedure**: To be developed  
**Partitioning**: Daily by `summary_date`  
**Retention**: 5 years (1825 days)  
**Clustering**: `route_key, tenant_id`

**Key Metrics**:
- Performance: `planned_vs_actual_time_ratio`, `on_time_completion_rate`
- Cost: `avg_fuel_cost_usd`, `cost_per_delivery_usd`, `cost_per_km_usd`
- Volume: `total_deliveries_completed`, `delivery_success_rate`
- Efficiency: `route_efficiency_score`, `optimization_potential_score`

### 4. customer_service_summary
**Purpose**: Customer satisfaction tracking and service metrics  
**Source Data**: `delivery_events_fact` + customer feedback systems  
**ETL Procedure**: To be developed  
**Partitioning**: Daily by `summary_date`  
**Retention**: 5 years (1825 days)  
**Clustering**: `customer_key, tenant_id`

**Key Metrics**:
- Delivery: `delivery_completion_rate`, `on_time_percentage`
- Quality: `customer_satisfaction_score`, `customer_complaints`
- Performance: `avg_delay_minutes`, `delivery_damage_reports`
- Revenue: `total_delivery_revenue_usd`, `profit_margin_usd`

### 5. fleet_operations_summary
**Purpose**: Executive dashboard metrics for fleet-wide KPIs  
**Source Data**: All aggregation tables  
**ETL Procedure**: To be developed  
**Partitioning**: By `summary_start_date` (weekly/monthly)  
**Retention**: 10 years (3650 days)  
**Clustering**: `tenant_id, summary_period`

**Key Metrics**:
- Fleet: `total_vehicles_in_fleet`, `fleet_utilization_percentage`
- Operations: `total_distance_km`, `total_deliveries_completed`
- Costs: `total_operational_cost_usd`, `cost_per_km_usd`
- Performance: `fleet_on_time_percentage`, `fleet_safety_score`

## 🤖 ML Feature Tables (Analytics Support)

### 1. driving_behavior_features
**Purpose**: Driver safety prediction and performance optimization features  
**Source Data**: `iot_telemetry_fact` with 30-day rolling windows  
**ETL Procedure**: `sp_update_ml_features`  
**Partitioning**: Daily by `feature_date`  
**Retention**: 3 years (1095 days)  
**Clustering**: `driver_key, vehicle_key, tenant_id`

**Feature Categories**:
- Speed behavior: `avg_speed_kmh`, `speeding_frequency`, `speed_percentile_95`
- Driving patterns: `hard_braking_frequency`, `smooth_driving_ratio`
- Route adherence: `route_deviation_frequency`, `unauthorized_stops_frequency`
- Target variables: `safety_incidents_next_30d`, `performance_decline_next_30d`

### 2. vehicle_health_features
**Purpose**: Predictive maintenance and failure prediction features  
**Source Data**: `iot_telemetry_fact` + `maintenance_events_fact`  
**ETL Procedure**: `sp_update_ml_features`  
**Partitioning**: Daily by `feature_date`  
**Retention**: 3 years (1095 days)  
**Clustering**: `vehicle_key, tenant_id`

**Feature Categories**:
- Engine health: `avg_engine_temperature`, `engine_temperature_variance`
- Usage patterns: `usage_intensity_score`, `peak_load_frequency`
- Maintenance history: `maintenance_frequency_90d`, `emergency_maintenance_90d`
- Target variables: `maintenance_needed_next_30d`, `breakdown_risk_next_60d`

### 3. route_optimization_features
**Purpose**: ETA prediction and dynamic routing features  
**Source Data**: `delivery_events_fact` + `iot_telemetry_fact`  
**ETL Procedure**: To be developed  
**Partitioning**: Daily by `feature_date`  
**Retention**: 2 years (730 days)  
**Clustering**: `route_key, time_of_day_bucket, tenant_id`

**Feature Categories**:
- Performance: `avg_completion_time_minutes`, `on_time_completion_rate`
- Traffic: `avg_traffic_delay_minutes`, `weather_impact_factor`
- Optimization: `distance_optimization_potential`, `consolidation_opportunity_score`
- Predictions: `predicted_completion_time_minutes`, `predicted_success_probability`

### 4. anomaly_detection_features
**Purpose**: Fraud and misuse detection features  
**Source Data**: `iot_telemetry_fact` with baseline behavior analysis  
**ETL Procedure**: To be developed  
**Partitioning**: Daily by `feature_datetime`  
**Retention**: 3 years (1095 days)  
**Clustering**: `entity_type, tenant_id, risk_level`

**Feature Categories**:
- Baseline deviations: `distance_deviation_percent`, `fuel_deviation_percent`
- Unusual patterns: `off_hours_usage_minutes`, `unauthorized_location_visits`
- Risk scoring: `overall_anomaly_score`, `business_impact_score`
- Investigation: `investigation_priority`, `similar_historical_events`

## 📊 Analytics Views (ML Support)

### 1. driver_features_latest
**Purpose**: Latest driver features for real-time ML inference  
**Source Data**: `driving_behavior_features` + `vehicle_health_features`  
**Filter**: Last 7 days, `model_ready = TRUE`

### 2. route_features_latest
**Purpose**: Latest route optimization features for routing algorithms  
**Source Data**: `route_optimization_features`  
**Filter**: Last 7 days, `model_ready = TRUE`

## 🔧 ETL Procedures

### Core Procedures
1. **`sp_load_dimensions()`** - Populates all dimension tables from operational data
2. **`sp_load_iot_telemetry(date, batch_size)`** - Loads fact data with dimension keys
3. **`sp_generate_daily_summaries(date)`** - Creates daily aggregations
4. **`sp_update_ml_features(date, lookback_days)`** - Generates ML features

### ETL Monitoring
- **`etl_processing_log`** - Tracks all procedure executions
- **`etl_status_today`** - Current day execution status
- **`etl_performance_trend`** - 30-day performance trends
- **`etl_errors_recent`** - Recent errors and warnings

## 🔑 Design Principles

### **1. Multi-Tenancy**
- `tenant_id` in all tables for data isolation
- Row-level security capabilities
- Cost allocation by tenant

### **2. Partitioning & Clustering**
- Daily partitioning for cost optimization
- Clustering on `tenant_id` + business keys
- Query pattern optimization

### **3. Data Quality**
- Data quality scoring in fact tables
- Validation flags and completeness ratios
- Audit trails with timestamps

### **4. Slowly Changing Dimensions**
- SCD Type 2 for vehicle, driver, and customer dimensions
- Historical tracking with effective date ranges
- Current flag for latest state queries

### **5. Retention Policies**
- 7 years for operational data (compliance)
- 3 years for ML features (model lifecycle)
- 10 years for strategic analytics

### **6. Performance Optimization**
- Pre-computed aggregations for common queries
- Materialized views for ML feature access
- Proper indexing through clustering

This schema supports comprehensive logistics analytics while maintaining performance, scalability, and governance requirements for the Intelligent DataOps Platform.