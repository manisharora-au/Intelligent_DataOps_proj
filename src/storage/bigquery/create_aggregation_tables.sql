-- =============================================================================
-- BigQuery Data Warehouse - Aggregation Tables Creation Script
-- =============================================================================
-- Purpose: Create pre-computed aggregation tables for fast analytics queries
-- Usage: bq query --use_legacy_sql=false < create_aggregation_tables.sql
-- =============================================================================

-- =============================================================================
-- 1. Vehicle Daily Summary (Daily Aggregations)
-- =============================================================================

CREATE OR REPLACE TABLE `intelligent_dataops_analytics.vehicle_daily_summary` (
  -- Dimensions
  summary_date DATE NOT NULL OPTIONS(description="Date of aggregated data"),
  vehicle_key STRING NOT NULL OPTIONS(description="Foreign key to vehicle_dim"),
  driver_key STRING OPTIONS(description="Primary driver for the day"),
  tenant_id STRING NOT NULL OPTIONS(description="Multi-tenant isolation key"),
  
  -- Distance and movement metrics
  total_distance_km FLOAT64 OPTIONS(description="Total kilometers driven"),
  total_driving_hours FLOAT64 OPTIONS(description="Hours in motion"),
  total_idle_hours FLOAT64 OPTIONS(description="Hours idling (engine on, speed=0)"),
  total_stopped_hours FLOAT64 OPTIONS(description="Hours completely stopped"),
  
  -- Speed analytics
  average_speed_kmh FLOAT64 OPTIONS(description="Average speed while driving"),
  max_speed_kmh FLOAT64 OPTIONS(description="Maximum speed recorded"),
  speed_variance FLOAT64 OPTIONS(description="Speed consistency metric"),
  time_over_speed_limit_minutes INTEGER OPTIONS(description="Time exceeding speed limits"),
  
  -- Fuel efficiency metrics
  fuel_consumed_liters FLOAT64 OPTIONS(description="Total fuel consumption"),
  fuel_efficiency_kmpl FLOAT64 OPTIONS(description="Kilometers per liter efficiency"),
  fuel_cost_usd NUMERIC(10,2) OPTIONS(description="Total fuel cost"),
  idle_fuel_consumption_liters FLOAT64 OPTIONS(description="Fuel used while idling"),
  
  -- Operational performance  
  deliveries_completed INTEGER OPTIONS(description="Number of deliveries completed"),
  pickups_completed INTEGER OPTIONS(description="Number of pickups completed"),
  on_time_deliveries INTEGER OPTIONS(description="Deliveries within SLA window"),
  failed_deliveries INTEGER OPTIONS(description="Failed or cancelled deliveries"),
  
  -- Safety and behavior metrics
  hard_braking_events INTEGER OPTIONS(description="Harsh braking incidents"),
  rapid_acceleration_events INTEGER OPTIONS(description="Rapid acceleration incidents"),
  speed_violations INTEGER OPTIONS(description="Speed limit violations"),
  unauthorized_stops INTEGER OPTIONS(description="Stops outside planned route"),
  
  -- Location and coverage
  unique_locations_visited INTEGER OPTIONS(description="Distinct locations visited"),
  total_stops INTEGER OPTIONS(description="Total number of stops"),
  route_deviation_minutes INTEGER OPTIONS(description="Time spent off planned route"),
  
  -- Calculated performance scores (0.0 - 1.0)
  safety_score FLOAT64 OPTIONS(description="Daily safety performance score"),
  efficiency_score FLOAT64 OPTIONS(description="Fuel and time efficiency score"),
  customer_service_score FLOAT64 OPTIONS(description="On-time delivery performance score"),
  overall_performance_score FLOAT64 OPTIONS(description="Composite performance score"),
  
  -- Environmental metrics
  co2_emissions_kg FLOAT64 OPTIONS(description="Estimated CO2 emissions"),
  engine_health_score FLOAT64 OPTIONS(description="Engine performance indicator"),
  
  -- Cost allocation
  total_operational_cost_usd NUMERIC(10,2) OPTIONS(description="Total daily operational cost"),
  cost_per_km_usd NUMERIC(6,4) OPTIONS(description="Cost per kilometer driven"),
  cost_per_delivery_usd NUMERIC(8,2) OPTIONS(description="Cost per completed delivery"),
  
  -- Data quality and completeness
  data_completeness_percent FLOAT64 OPTIONS(description="Percentage of expected data points received"),
  gps_signal_quality_avg FLOAT64 OPTIONS(description="Average GPS signal quality"),
  
  -- Calculation metadata
  calculated_at TIMESTAMP NOT NULL OPTIONS(description="Aggregation calculation timestamp"),
  data_source_version STRING OPTIONS(description="Source data version for reproducibility")
)
PARTITION BY summary_date
CLUSTER BY vehicle_key, tenant_id
OPTIONS (
  description="Daily vehicle performance aggregations for analytics and reporting",
  partition_expiration_days=2555,  -- 7 years retention
  labels=[("environment", "production"), ("data_type", "aggregation")]
);

-- =============================================================================
-- 2. Driver Performance Summary (Daily Aggregations)
-- =============================================================================

CREATE OR REPLACE TABLE `intelligent_dataops_analytics.driver_performance_summary` (
  -- Dimensions
  summary_date DATE NOT NULL OPTIONS(description="Date of aggregated performance data"),
  driver_key STRING NOT NULL OPTIONS(description="Foreign key to driver_dim"),
  primary_vehicle_key STRING OPTIONS(description="Primary vehicle used"),
  tenant_id STRING NOT NULL OPTIONS(description="Multi-tenant isolation key"),
  
  -- Working hours and productivity
  total_working_hours FLOAT64 OPTIONS(description="Total hours on duty"),
  driving_hours FLOAT64 OPTIONS(description="Hours actively driving"),
  break_hours FLOAT64 OPTIONS(description="Scheduled break time"),
  overtime_hours FLOAT64 OPTIONS(description="Hours worked beyond standard"),
  
  -- Performance metrics
  deliveries_per_hour FLOAT64 OPTIONS(description="Delivery productivity rate"),
  miles_per_hour FLOAT64 OPTIONS(description="Average driving efficiency"),
  fuel_efficiency_vs_baseline FLOAT64 OPTIONS(description="Fuel efficiency compared to vehicle baseline"),
  
  -- Safety performance
  safety_violations INTEGER OPTIONS(description="Total safety violations"),
  accident_incidents INTEGER OPTIONS(description="Accidents or incidents reported"),
  near_miss_events INTEGER OPTIONS(description="Near-miss safety events"),
  safety_score FLOAT64 OPTIONS(description="Daily safety performance score (0-1)"),
  
  -- Driving behavior analysis
  aggressive_driving_events INTEGER OPTIONS(description="Harsh braking + rapid acceleration"),
  smooth_driving_percentage FLOAT64 OPTIONS(description="Percentage of time driving smoothly"),
  speed_compliance_percentage FLOAT64 OPTIONS(description="Time within speed limits"),
  
  -- Route and navigation performance
  on_time_percentage FLOAT64 OPTIONS(description="Percentage of on-time deliveries"),
  route_adherence_percentage FLOAT64 OPTIONS(description="Time spent on planned route"),
  customer_satisfaction_score FLOAT64 OPTIONS(description="Customer feedback score"),
  
  -- Vehicle utilization
  vehicle_idle_time_percentage FLOAT64 OPTIONS(description="Percentage of time vehicle idle"),
  unauthorized_use_minutes INTEGER OPTIONS(description="Vehicle use outside work hours"),
  
  -- Cost and revenue impact
  total_revenue_generated_usd NUMERIC(10,2) OPTIONS(description="Revenue from completed deliveries"),
  operational_cost_allocated_usd NUMERIC(10,2) OPTIONS(description="Allocated operational costs"),
  profit_margin_usd NUMERIC(10,2) OPTIONS(description="Profit generated (revenue - costs)"),
  
  -- Training and compliance
  training_hours_completed FLOAT64 OPTIONS(description="Training hours in period"),
  compliance_violations INTEGER OPTIONS(description="Regulatory compliance violations"),
  certifications_expiring INTEGER OPTIONS(description="Certifications expiring soon"),
  
  -- Performance rankings (within tenant)
  safety_rank INTEGER OPTIONS(description="Safety ranking among peers"),
  efficiency_rank INTEGER OPTIONS(description="Efficiency ranking among peers"),
  customer_service_rank INTEGER OPTIONS(description="Customer service ranking among peers"),
  
  -- Calculation metadata
  calculated_at TIMESTAMP NOT NULL OPTIONS(description="Summary calculation timestamp"),
  peer_group_size INTEGER OPTIONS(description="Size of comparison group for rankings")
)
PARTITION BY summary_date
CLUSTER BY driver_key, tenant_id
OPTIONS (
  description="Daily driver performance metrics and rankings",
  partition_expiration_days=1095,  -- 3 years retention
  labels=[("environment", "production"), ("data_type", "aggregation")]
);

-- =============================================================================
-- 3. Route Efficiency Summary (Daily Aggregations)
-- =============================================================================

CREATE OR REPLACE TABLE `intelligent_dataops_analytics.route_efficiency_summary` (
  -- Dimensions
  summary_date DATE NOT NULL OPTIONS(description="Date of route performance data"),
  route_key STRING NOT NULL OPTIONS(description="Foreign key to route_dim"),
  tenant_id STRING NOT NULL OPTIONS(description="Multi-tenant isolation key"),
  
  -- Execution metrics
  total_executions INTEGER OPTIONS(description="Number of times route was executed"),
  completed_executions INTEGER OPTIONS(description="Successfully completed executions"),
  failed_executions INTEGER OPTIONS(description="Failed or cancelled executions"),
  
  -- Time performance
  avg_actual_duration_minutes FLOAT64 OPTIONS(description="Average actual completion time"),
  planned_vs_actual_time_ratio FLOAT64 OPTIONS(description="Time efficiency ratio"),
  on_time_completion_rate FLOAT64 OPTIONS(description="Percentage completed on time"),
  average_delay_minutes FLOAT64 OPTIONS(description="Average delay when late"),
  
  -- Distance and fuel efficiency
  avg_actual_distance_km FLOAT64 OPTIONS(description="Average actual distance traveled"),
  planned_vs_actual_distance_ratio FLOAT64 OPTIONS(description="Distance efficiency ratio"),
  avg_fuel_consumption_liters FLOAT64 OPTIONS(description="Average fuel consumption"),
  fuel_efficiency_kmpl FLOAT64 OPTIONS(description="Route fuel efficiency"),
  
  -- Cost analysis
  avg_fuel_cost_usd NUMERIC(8,2) OPTIONS(description="Average fuel cost per execution"),
  avg_labor_cost_usd NUMERIC(8,2) OPTIONS(description="Average labor cost per execution"),
  avg_total_cost_usd NUMERIC(10,2) OPTIONS(description="Average total route cost"),
  cost_per_delivery_usd NUMERIC(8,2) OPTIONS(description="Cost per delivery on route"),
  cost_per_km_usd NUMERIC(6,4) OPTIONS(description="Cost per kilometer traveled"),
  
  -- Delivery performance
  total_deliveries_planned INTEGER OPTIONS(description="Total planned deliveries"),
  total_deliveries_completed INTEGER OPTIONS(description="Total completed deliveries"),
  delivery_success_rate FLOAT64 OPTIONS(description="Delivery completion percentage"),
  avg_deliveries_per_execution FLOAT64 OPTIONS(description="Average deliveries per route run"),
  
  -- Customer satisfaction
  customer_satisfaction_avg FLOAT64 OPTIONS(description="Average customer satisfaction score"),
  customer_complaints INTEGER OPTIONS(description="Number of customer complaints"),
  delivery_damage_incidents INTEGER OPTIONS(description="Delivery damage incidents"),
  
  -- Traffic and external factors
  avg_traffic_delay_minutes FLOAT64 OPTIONS(description="Average traffic-related delays"),
  weather_impact_score FLOAT64 OPTIONS(description="Weather impact on performance (0-1)"),
  
  -- Vehicle and driver variability
  unique_vehicles_used INTEGER OPTIONS(description="Number of different vehicles used"),
  unique_drivers_assigned INTEGER OPTIONS(description="Number of different drivers assigned"),
  performance_consistency_score FLOAT64 OPTIONS(description="Consistency across executions"),
  
  -- Optimization opportunities
  route_efficiency_score FLOAT64 OPTIONS(description="Overall route efficiency (0-1)"),
  optimization_potential_score FLOAT64 OPTIONS(description="Potential for improvement (0-1)"),
  
  -- Revenue metrics
  total_revenue_usd NUMERIC(12,2) OPTIONS(description="Total revenue from route"),
  profit_margin_percentage FLOAT64 OPTIONS(description="Profit margin percentage"),
  
  -- Calculation metadata
  calculated_at TIMESTAMP NOT NULL OPTIONS(description="Summary calculation timestamp"),
  data_quality_score FLOAT64 OPTIONS(description="Quality of underlying data (0-1)")
)
PARTITION BY summary_date
CLUSTER BY route_key, tenant_id
OPTIONS (
  description="Route performance analysis and optimization metrics",
  partition_expiration_days=1825,  -- 5 years retention
  labels=[("environment", "production"), ("data_type", "aggregation")]
);

-- =============================================================================
-- 4. Customer Service Summary (Daily Aggregations)
-- =============================================================================

CREATE OR REPLACE TABLE `intelligent_dataops_analytics.customer_service_summary` (
  -- Dimensions
  summary_date DATE NOT NULL OPTIONS(description="Date of customer service metrics"),
  customer_key STRING NOT NULL OPTIONS(description="Foreign key to customer_dim"),
  tenant_id STRING NOT NULL OPTIONS(description="Multi-tenant isolation key"),
  
  -- Delivery performance
  total_deliveries_scheduled INTEGER OPTIONS(description="Total deliveries scheduled"),
  total_deliveries_completed INTEGER OPTIONS(description="Total deliveries completed"),
  total_deliveries_failed INTEGER OPTIONS(description="Total failed deliveries"),
  delivery_completion_rate FLOAT64 OPTIONS(description="Delivery success percentage"),
  
  -- Timing performance
  on_time_deliveries INTEGER OPTIONS(description="Deliveries within SLA window"),
  early_deliveries INTEGER OPTIONS(description="Deliveries ahead of schedule"),
  late_deliveries INTEGER OPTIONS(description="Deliveries past SLA window"),
  on_time_percentage FLOAT64 OPTIONS(description="On-time delivery percentage"),
  avg_delay_minutes FLOAT64 OPTIONS(description="Average delay for late deliveries"),
  
  -- Service quality metrics
  customer_satisfaction_score FLOAT64 OPTIONS(description="Average satisfaction score"),
  customer_complaints INTEGER OPTIONS(description="Number of complaints received"),
  delivery_damage_reports INTEGER OPTIONS(description="Damage reports filed"),
  missing_item_reports INTEGER OPTIONS(description="Missing item reports"),
  
  -- Communication and tracking
  delivery_notifications_sent INTEGER OPTIONS(description="Automated notifications sent"),
  real_time_tracking_usage_minutes INTEGER OPTIONS(description="Customer tracking usage"),
  customer_initiated_calls INTEGER OPTIONS(description="Customer service calls"),
  
  -- Cost and revenue
  total_delivery_revenue_usd NUMERIC(12,2) OPTIONS(description="Revenue from deliveries"),
  service_cost_usd NUMERIC(10,2) OPTIONS(description="Cost to serve customer"),
  profit_margin_usd NUMERIC(10,2) OPTIONS(description="Profit margin"),
  
  -- Special handling
  special_instructions_deliveries INTEGER OPTIONS(description="Deliveries with special instructions"),
  signature_required_deliveries INTEGER OPTIONS(description="Deliveries requiring signature"),
  failed_delivery_attempts INTEGER OPTIONS(description="Failed delivery attempts"),
  
  -- Geographic and access
  delivery_locations_served INTEGER OPTIONS(description="Unique delivery locations"),
  access_issues_reported INTEGER OPTIONS(description="Location access problems"),
  
  -- Driver and vehicle assignments
  unique_drivers_assigned INTEGER OPTIONS(description="Different drivers serving customer"),
  unique_vehicles_used INTEGER OPTIONS(description="Different vehicles used"),
  preferred_driver_requests INTEGER OPTIONS(description="Requests for specific driver"),
  
  -- Performance trends
  service_improvement_trend FLOAT64 OPTIONS(description="Month-over-month improvement"),
  customer_retention_indicator FLOAT64 OPTIONS(description="Retention likelihood score"),
  
  -- SLA compliance
  sla_adherence_percentage FLOAT64 OPTIONS(description="Overall SLA compliance"),
  premium_service_deliveries INTEGER OPTIONS(description="Premium service level deliveries"),
  
  -- Calculation metadata
  calculated_at TIMESTAMP NOT NULL OPTIONS(description="Summary calculation timestamp"),
  sla_definition_version STRING OPTIONS(description="SLA definition version used")
)
PARTITION BY summary_date
CLUSTER BY customer_key, tenant_id
OPTIONS (
  description="Customer service performance and satisfaction metrics",
  partition_expiration_days=1825,  -- 5 years retention for customer analytics
  labels=[("environment", "production"), ("data_type", "aggregation")]
);

-- =============================================================================
-- 5. Fleet Operations Summary (Weekly/Monthly Aggregations)
-- =============================================================================

CREATE OR REPLACE TABLE `intelligent_dataops_analytics.fleet_operations_summary` (
  -- Time dimensions
  summary_period STRING NOT NULL OPTIONS(description="Time period: weekly, monthly"),
  summary_start_date DATE NOT NULL OPTIONS(description="Period start date"),
  summary_end_date DATE NOT NULL OPTIONS(description="Period end date"),
  tenant_id STRING NOT NULL OPTIONS(description="Multi-tenant isolation key"),
  
  -- Fleet utilization
  total_vehicles_in_fleet INTEGER OPTIONS(description="Total vehicles in fleet"),
  active_vehicles INTEGER OPTIONS(description="Vehicles actively used"),
  vehicles_in_maintenance INTEGER OPTIONS(description="Vehicles under maintenance"),
  fleet_utilization_percentage FLOAT64 OPTIONS(description="Fleet utilization rate"),
  
  -- Operational metrics
  total_distance_km FLOAT64 OPTIONS(description="Total fleet distance covered"),
  total_fuel_consumed_liters FLOAT64 OPTIONS(description="Total fuel consumption"),
  total_deliveries_completed INTEGER OPTIONS(description="Total deliveries across fleet"),
  fleet_fuel_efficiency_kmpl FLOAT64 OPTIONS(description="Fleet average fuel efficiency"),
  
  -- Cost analysis
  total_fuel_cost_usd NUMERIC(15,2) OPTIONS(description="Total fuel costs"),
  total_maintenance_cost_usd NUMERIC(15,2) OPTIONS(description="Total maintenance costs"),
  total_operational_cost_usd NUMERIC(15,2) OPTIONS(description="Total operational costs"),
  cost_per_km_usd NUMERIC(6,4) OPTIONS(description="Fleet cost per kilometer"),
  
  -- Performance metrics
  fleet_on_time_percentage FLOAT64 OPTIONS(description="Fleet-wide on-time performance"),
  fleet_safety_score FLOAT64 OPTIONS(description="Fleet average safety score"),
  fleet_efficiency_score FLOAT64 OPTIONS(description="Fleet efficiency score"),
  
  -- Driver metrics
  total_active_drivers INTEGER OPTIONS(description="Active drivers in period"),
  avg_driver_utilization_hours FLOAT64 OPTIONS(description="Average driver working hours"),
  driver_turnover_count INTEGER OPTIONS(description="Driver turnover in period"),
  
  -- Customer service
  total_customers_served INTEGER OPTIONS(description="Unique customers served"),
  overall_customer_satisfaction FLOAT64 OPTIONS(description="Fleet-wide customer satisfaction"),
  total_customer_complaints INTEGER OPTIONS(description="Total customer complaints"),
  
  -- Environmental impact
  total_co2_emissions_kg FLOAT64 OPTIONS(description="Total fleet CO2 emissions"),
  co2_per_delivery_kg FLOAT64 OPTIONS(description="CO2 emissions per delivery"),
  
  -- Revenue and profitability
  total_revenue_usd NUMERIC(15,2) OPTIONS(description="Total fleet revenue"),
  gross_profit_margin_percentage FLOAT64 OPTIONS(description="Gross profit margin"),
  roi_percentage FLOAT64 OPTIONS(description="Return on investment"),
  
  -- Trends and insights
  period_over_period_growth FLOAT64 OPTIONS(description="Growth compared to previous period"),
  efficiency_trend FLOAT64 OPTIONS(description="Efficiency trend indicator"),
  cost_trend FLOAT64 OPTIONS(description="Cost trend indicator"),
  
  -- Calculation metadata
  calculated_at TIMESTAMP NOT NULL OPTIONS(description="Summary calculation timestamp"),
  reporting_currency STRING OPTIONS(description="Currency for financial metrics")
)
PARTITION BY summary_start_date
CLUSTER BY tenant_id, summary_period
OPTIONS (
  description="High-level fleet operations summary for executive reporting",
  partition_expiration_days=3650,  -- 10 years retention for strategic analysis
  labels=[("environment", "production"), ("data_type", "aggregation")]
);

-- =============================================================================
-- Create summary information
-- =============================================================================

-- ✅ Aggregation tables created successfully!
-- 📊 Tables created:
--   - vehicle_daily_summary (daily vehicle metrics)
--   - driver_performance_summary (daily driver metrics)
--   - route_efficiency_summary (route performance analysis)
--   - customer_service_summary (customer satisfaction tracking)
--   - fleet_operations_summary (executive dashboards)
--
-- 🚀 Pre-computed aggregations for fast query performance
-- 📅 Optimized partitioning and retention policies
-- 📈 Ready for analytics dashboards and reporting