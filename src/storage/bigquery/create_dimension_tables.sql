-- =============================================================================
-- BigQuery Data Warehouse - Dimension Tables Creation Script  
-- =============================================================================
-- Purpose: Create all dimension tables for reference data with SCD Type 2 support
-- Usage: bq query --use_legacy_sql=false < create_dimension_tables.sql
-- =============================================================================

-- =============================================================================
-- 1. Vehicle Dimension Table (SCD Type 2)
-- =============================================================================

CREATE OR REPLACE TABLE `intelligent_dataops_analytics.vehicle_dim` (
  -- Surrogate and business keys
  vehicle_key STRING NOT NULL OPTIONS(description="Surrogate key (UUID)"),
  vehicle_id STRING NOT NULL OPTIONS(description="Business key - vehicle identifier"),
  
  -- Vehicle specifications
  make STRING OPTIONS(description="Vehicle manufacturer (e.g., Ford, Mercedes)"),
  model STRING OPTIONS(description="Vehicle model"),
  year INTEGER OPTIONS(description="Manufacturing year"),
  vin STRING OPTIONS(description="Vehicle Identification Number"),
  license_plate STRING OPTIONS(description="Current license plate number"),
  
  -- Technical specifications
  engine_type STRING OPTIONS(description="Engine type: diesel, gasoline, electric, hybrid"),
  transmission_type STRING OPTIONS(description="Transmission: manual, automatic"),
  max_capacity_kg INTEGER OPTIONS(description="Maximum cargo capacity in kilograms"),
  fuel_tank_capacity_liters FLOAT64 OPTIONS(description="Fuel tank capacity in liters"),
  fuel_efficiency_rating FLOAT64 OPTIONS(description="Manufacturer fuel efficiency rating"),
  
  -- Operational data
  acquisition_date DATE OPTIONS(description="Vehicle acquisition/lease start date"),
  acquisition_cost_usd NUMERIC(12,2) OPTIONS(description="Vehicle acquisition cost in USD"),
  current_status STRING OPTIONS(description="Status: active, maintenance, retired, sold"),
  
  -- Location and assignment
  home_depot_key STRING OPTIONS(description="Primary depot assignment"),
  assigned_region STRING OPTIONS(description="Geographic region assignment"),
  fleet_group STRING OPTIONS(description="Fleet group classification"),
  
  -- Financial data
  monthly_depreciation_usd NUMERIC(8,2) OPTIONS(description="Monthly depreciation amount"),
  insurance_cost_monthly_usd NUMERIC(8,2) OPTIONS(description="Monthly insurance cost"),
  registration_expiry_date DATE OPTIONS(description="Registration renewal date"),
  
  -- SCD Type 2 fields
  effective_from_date DATE NOT NULL OPTIONS(description="Record effective start date"),
  effective_to_date DATE OPTIONS(description="Record effective end date (NULL for current)"),
  is_current BOOLEAN NOT NULL OPTIONS(description="Flag indicating current record"),
  change_reason STRING OPTIONS(description="Reason for dimension change"),
  
  -- Audit fields
  tenant_id STRING NOT NULL OPTIONS(description="Multi-tenant isolation key"),
  created_at TIMESTAMP NOT NULL OPTIONS(description="Record creation timestamp"),
  updated_at TIMESTAMP NOT NULL OPTIONS(description="Record last update timestamp"),
  created_by STRING OPTIONS(description="User/system that created the record")
)
CLUSTER BY tenant_id, is_current, vehicle_id
OPTIONS (
  description="Vehicle master data with SCD Type 2 historical tracking",
  labels=[("environment", "production"), ("data_type", "dimension")]
);

-- =============================================================================
-- 2. Driver Dimension Table (SCD Type 2)  
-- =============================================================================

CREATE OR REPLACE TABLE `intelligent_dataops_analytics.driver_dim` (
  -- Surrogate and business keys
  driver_key STRING NOT NULL OPTIONS(description="Surrogate key (UUID)"),
  driver_id STRING NOT NULL OPTIONS(description="Business key - driver identifier"),
  
  -- Personal information (privacy-compliant)
  driver_code STRING OPTIONS(description="Anonymized driver identifier for reporting"),
  hire_date DATE OPTIONS(description="Employment start date"),
  employment_type STRING OPTIONS(description="Employment type: full_time, part_time, contractor"),
  
  -- Qualifications and certifications
  license_class STRING OPTIONS(description="Driver license class (CDL-A, CDL-B, etc.)"),
  license_number_hash STRING OPTIONS(description="Hashed driver license number for verification"),
  license_issue_date DATE OPTIONS(description="License issue date"),
  license_expiry_date DATE OPTIONS(description="License expiration date"),
  safety_certifications ARRAY<STRING> OPTIONS(description="List of safety certifications"),
  
  -- Performance baseline and metrics
  experience_years INTEGER OPTIONS(description="Years of driving experience"),
  safety_score_baseline FLOAT64 OPTIONS(description="Initial safety score baseline"),
  training_completion_date DATE OPTIONS(description="Latest training completion"),
  
  -- Organizational assignment
  home_depot_key STRING OPTIONS(description="Primary depot assignment"),
  supervisor_key STRING OPTIONS(description="Direct supervisor reference"),
  team_assignment STRING OPTIONS(description="Team or crew assignment"),
  employment_status STRING OPTIONS(description="Status: active, inactive, terminated"),
  
  -- Pay and performance tier
  pay_grade STRING OPTIONS(description="Driver pay grade classification"),
  performance_tier STRING OPTIONS(description="Performance tier: bronze, silver, gold"),
  
  -- Contact and emergency (hashed for privacy)
  contact_phone_hash STRING OPTIONS(description="Hashed contact phone number"),
  emergency_contact_hash STRING OPTIONS(description="Hashed emergency contact"),
  
  -- SCD Type 2 fields
  effective_from_date DATE NOT NULL OPTIONS(description="Record effective start date"),
  effective_to_date DATE OPTIONS(description="Record effective end date (NULL for current)"),
  is_current BOOLEAN NOT NULL OPTIONS(description="Flag indicating current record"),
  change_reason STRING OPTIONS(description="Reason for dimension change"),
  
  -- Audit fields
  tenant_id STRING NOT NULL OPTIONS(description="Multi-tenant isolation key"),
  created_at TIMESTAMP NOT NULL OPTIONS(description="Record creation timestamp"),
  updated_at TIMESTAMP NOT NULL OPTIONS(description="Record last update timestamp"),
  created_by STRING OPTIONS(description="User/system that created the record")
)
CLUSTER BY tenant_id, is_current, driver_id
OPTIONS (
  description="Driver master data with privacy compliance and SCD Type 2 tracking",
  labels=[("environment", "production"), ("data_type", "dimension")]
);

-- =============================================================================
-- 3. Route Dimension Table
-- =============================================================================

CREATE OR REPLACE TABLE `intelligent_dataops_analytics.route_dim` (
  -- Surrogate and business keys
  route_key STRING NOT NULL OPTIONS(description="Surrogate key (UUID)"),
  route_id STRING NOT NULL OPTIONS(description="Business key - route identifier"),
  
  -- Route characteristics
  route_name STRING OPTIONS(description="Human-readable route name"),
  route_description STRING OPTIONS(description="Detailed route description"),
  route_type STRING OPTIONS(description="Type: delivery, pickup, mixed, return"),
  service_type STRING OPTIONS(description="Service type: standard, express, overnight"),
  
  -- Geographic and distance data
  planned_distance_km FLOAT64 OPTIONS(description="Planned total route distance"),
  estimated_duration_minutes INTEGER OPTIONS(description="Estimated completion time"),
  traffic_complexity_score FLOAT64 OPTIONS(description="Route traffic complexity (0.0-1.0)"),
  
  -- Route structure
  origin_location_key STRING OPTIONS(description="Starting location reference"),
  destination_location_key STRING OPTIONS(description="Ending location reference"),
  waypoints ARRAY<STRUCT<
    sequence_number INTEGER,
    location_key STRING,
    planned_arrival_time TIME,
    estimated_duration_minutes INTEGER,
    stop_type STRING  -- pickup, delivery, break
  >> OPTIONS(description="Ordered waypoints with timing"),
  
  -- Operational characteristics
  max_stops INTEGER OPTIONS(description="Maximum number of stops on route"),
  vehicle_requirements ARRAY<STRING> OPTIONS(description="Required vehicle capabilities"),
  driver_skill_requirements ARRAY<STRING> OPTIONS(description="Required driver skills"),
  
  -- Performance benchmarks
  baseline_fuel_consumption_liters FLOAT64 OPTIONS(description="Expected fuel consumption"),
  baseline_cost_usd NUMERIC(8,2) OPTIONS(description="Expected route operating cost"),
  difficulty_rating INTEGER OPTIONS(description="Route difficulty (1-5 scale)"),
  
  -- Customer and business context
  primary_customer_key STRING OPTIONS(description="Primary customer served"),
  customer_sla_minutes INTEGER OPTIONS(description="Customer SLA requirement"),
  revenue_per_stop_usd NUMERIC(8,2) OPTIONS(description="Average revenue per stop"),
  
  -- Temporal validity
  effective_from_date DATE NOT NULL OPTIONS(description="Route effective start date"),
  effective_to_date DATE OPTIONS(description="Route effective end date"),
  is_active BOOLEAN NOT NULL OPTIONS(description="Route currently active flag"),
  seasonality_pattern STRING OPTIONS(description="Seasonal usage pattern"),
  
  -- Audit fields
  tenant_id STRING NOT NULL OPTIONS(description="Multi-tenant isolation key"),
  created_at TIMESTAMP NOT NULL OPTIONS(description="Record creation timestamp"),
  updated_at TIMESTAMP OPTIONS(description="Record last update timestamp"),
  created_by STRING OPTIONS(description="User/system that created the record")
)
CLUSTER BY tenant_id, is_active, route_type
OPTIONS (
  description="Route master data with operational characteristics and performance benchmarks",
  labels=[("environment", "production"), ("data_type", "dimension")]
);

-- =============================================================================  
-- 4. Customer Dimension Table (SCD Type 2)
-- =============================================================================

CREATE OR REPLACE TABLE `intelligent_dataops_analytics.customer_dim` (
  -- Surrogate and business keys
  customer_key STRING NOT NULL OPTIONS(description="Surrogate key (UUID)"),
  customer_id STRING NOT NULL OPTIONS(description="Business key - customer identifier"),
  
  -- Customer identification
  customer_name STRING OPTIONS(description="Customer business name"),
  customer_type STRING OPTIONS(description="Type: enterprise, small_business, individual"),
  industry_sector STRING OPTIONS(description="Industry classification"),
  
  -- Contact information (for business use)
  primary_contact_name STRING OPTIONS(description="Primary contact person"),
  billing_address STRUCT<
    street_address STRING,
    city STRING,
    state_province STRING,
    postal_code STRING,
    country STRING
  > OPTIONS(description="Billing address structure"),
  
  -- Service requirements
  service_level_agreement STRING OPTIONS(description="SLA tier: standard, premium, express"),
  delivery_instructions STRING OPTIONS(description="Special delivery instructions"),
  access_requirements ARRAY<STRING> OPTIONS(description="Site access requirements"),
  
  -- Business metrics
  customer_tier STRING OPTIONS(description="Customer value tier: bronze, silver, gold, platinum"),
  credit_limit_usd NUMERIC(12,2) OPTIONS(description="Customer credit limit"),
  payment_terms_days INTEGER OPTIONS(description="Payment terms in days"),
  
  -- Geographic and operational
  primary_location_key STRING OPTIONS(description="Primary delivery location"),
  service_territory STRING OPTIONS(description="Geographic service territory"),
  preferred_delivery_windows ARRAY<STRUCT<
    day_of_week STRING,
    start_time TIME,
    end_time TIME
  >> OPTIONS(description="Preferred delivery time windows"),
  
  -- Account status
  account_status STRING OPTIONS(description="Status: active, inactive, suspended"),
  contract_start_date DATE OPTIONS(description="Service contract start date"),
  contract_end_date DATE OPTIONS(description="Service contract end date"),
  
  -- SCD Type 2 fields
  effective_from_date DATE NOT NULL OPTIONS(description="Record effective start date"),
  effective_to_date DATE OPTIONS(description="Record effective end date (NULL for current)"),
  is_current BOOLEAN NOT NULL OPTIONS(description="Flag indicating current record"),
  change_reason STRING OPTIONS(description="Reason for dimension change"),
  
  -- Audit fields
  tenant_id STRING NOT NULL OPTIONS(description="Multi-tenant isolation key"),
  created_at TIMESTAMP NOT NULL OPTIONS(description="Record creation timestamp"),
  updated_at TIMESTAMP NOT NULL OPTIONS(description="Record last update timestamp"),
  created_by STRING OPTIONS(description="User/system that created the record")
)
CLUSTER BY tenant_id, is_current, customer_tier
OPTIONS (
  description="Customer master data with SLA and service requirements",
  labels=[("environment", "production"), ("data_type", "dimension")]
);

-- =============================================================================
-- 5. Location Dimension Table
-- =============================================================================

CREATE OR REPLACE TABLE `intelligent_dataops_analytics.location_dim` (
  -- Primary keys
  location_key STRING NOT NULL OPTIONS(description="Surrogate key (UUID)"),
  location_id STRING NOT NULL OPTIONS(description="Business key - location identifier"),
  
  -- Geographic coordinates
  latitude FLOAT64 NOT NULL OPTIONS(description="Location latitude coordinate"),
  longitude FLOAT64 NOT NULL OPTIONS(description="Location longitude coordinate"),
  elevation_meters FLOAT64 OPTIONS(description="Elevation above sea level"),
  
  -- Address components
  street_address STRING OPTIONS(description="Street address"),
  city STRING OPTIONS(description="City name"),
  state_province STRING OPTIONS(description="State or province"),
  postal_code STRING OPTIONS(description="Postal/ZIP code"),
  country STRING NOT NULL OPTIONS(description="Country name"),
  
  -- Location classification
  location_type STRING OPTIONS(description="Type: depot, customer, fuel_station, service_center"),
  location_category STRING OPTIONS(description="Category: warehouse, retail, residential"),
  
  -- Operational characteristics
  operating_hours STRUCT<
    monday_open TIME,
    monday_close TIME,
    tuesday_open TIME,
    tuesday_close TIME,
    wednesday_open TIME,
    wednesday_close TIME,
    thursday_open TIME,
    thursday_close TIME,
    friday_open TIME,
    friday_close TIME,
    saturday_open TIME,
    saturday_close TIME,
    sunday_open TIME,
    sunday_close TIME
  > OPTIONS(description="Weekly operating hours"),
  
  -- Access and facilities
  vehicle_access_restrictions ARRAY<STRING> OPTIONS(description="Vehicle size/type restrictions"),
  loading_dock_available BOOLEAN OPTIONS(description="Loading dock availability"),
  parking_spaces_available INTEGER OPTIONS(description="Available parking spaces"),
  
  -- Geographic context
  timezone STRING OPTIONS(description="Local timezone identifier"),
  region_code STRING OPTIONS(description="Geographic region classification"),
  traffic_zone STRING OPTIONS(description="Traffic management zone"),
  
  -- Contact and reference
  location_contact_phone STRING OPTIONS(description="Location contact phone"),
  location_manager STRING OPTIONS(description="Location manager name"),
  
  -- Status and validity
  is_active BOOLEAN NOT NULL OPTIONS(description="Location currently active"),
  verified_date DATE OPTIONS(description="Last address verification date"),
  
  -- Audit fields
  tenant_id STRING NOT NULL OPTIONS(description="Multi-tenant isolation key"),
  created_at TIMESTAMP NOT NULL OPTIONS(description="Record creation timestamp"),
  updated_at TIMESTAMP OPTIONS(description="Record last update timestamp")
)
CLUSTER BY tenant_id, location_type, country
OPTIONS (
  description="Geographic location master data with operational details",
  labels=[("environment", "production"), ("data_type", "dimension")]
);

-- =============================================================================
-- Create summary information
-- =============================================================================

-- ✅ Dimension tables created successfully!
-- 📋 Tables created:
--   - vehicle_dim (SCD Type 2)
--   - driver_dim (SCD Type 2) 
--   - route_dim (with waypoints)
--   - customer_dim (SCD Type 2)
--   - location_dim (geographic master)
--
-- 🔑 All tables clustered for multi-tenant performance
-- 📊 SCD Type 2 support for historical tracking
-- 🏷️  Privacy-compliant design for sensitive data