-- =============================================================================
-- BigQuery Data Warehouse - ML Feature Tables Creation Script
-- =============================================================================
-- Purpose: Create feature tables optimized for machine learning and AI workloads
-- Usage: bq query --use_legacy_sql=false < create_ml_feature_tables.sql
-- =============================================================================

-- =============================================================================
-- 1. Driving Behavior Features (for Driver Scoring and Safety Prediction)
-- =============================================================================

CREATE OR REPLACE TABLE `intelligent_dataops_analytics.driving_behavior_features` (
  -- Identification and time windows
  feature_date DATE NOT NULL OPTIONS(description="Date for feature calculation"),
  driver_key STRING NOT NULL OPTIONS(description="Foreign key to driver_dim"),
  vehicle_key STRING NOT NULL OPTIONS(description="Primary vehicle used"),
  tenant_id STRING NOT NULL OPTIONS(description="Multi-tenant isolation key"),
  
  -- Rolling window indicators
  lookback_window_days INTEGER NOT NULL OPTIONS(description="Days of data used for features"),
  data_completeness_ratio FLOAT64 OPTIONS(description="Ratio of expected vs actual data points"),
  
  -- Speed behavior features
  avg_speed_kmh FLOAT64 OPTIONS(description="Average speed over period"),
  median_speed_kmh FLOAT64 OPTIONS(description="Median speed (robust to outliers)"),
  speed_std_dev FLOAT64 OPTIONS(description="Speed standard deviation"),
  speed_percentile_95 FLOAT64 OPTIONS(description="95th percentile speed"),
  speeding_frequency FLOAT64 OPTIONS(description="Frequency of speed limit violations"),
  speeding_severity_avg FLOAT64 OPTIONS(description="Average severity of speed violations"),
  
  -- Acceleration and braking patterns
  hard_braking_frequency FLOAT64 OPTIONS(description="Hard braking events per hour"),
  rapid_acceleration_frequency FLOAT64 OPTIONS(description="Rapid acceleration events per hour"),
  smooth_driving_ratio FLOAT64 OPTIONS(description="Ratio of smooth driving time"),
  acceleration_variance FLOAT64 OPTIONS(description="Acceleration pattern variability"),
  
  -- Route adherence behavior
  route_deviation_frequency FLOAT64 OPTIONS(description="Frequency of route deviations"),
  route_deviation_duration_avg FLOAT64 OPTIONS(description="Average duration of deviations"),
  unauthorized_stops_frequency FLOAT64 OPTIONS(description="Unauthorized stops per day"),
  unauthorized_stops_duration_avg FLOAT64 OPTIONS(description="Average duration of unauthorized stops"),
  
  -- Fuel efficiency patterns
  fuel_efficiency_trend FLOAT64 OPTIONS(description="Fuel efficiency trend slope"),
  fuel_efficiency_vs_baseline FLOAT64 OPTIONS(description="Efficiency vs vehicle baseline"),
  idle_time_ratio FLOAT64 OPTIONS(description="Idle time as ratio of total time"),
  eco_driving_score FLOAT64 OPTIONS(description="Eco-friendly driving score"),
  
  -- Temporal and contextual patterns
  peak_hour_performance_ratio FLOAT64 OPTIONS(description="Performance during peak vs off-peak"),
  weekend_vs_weekday_ratio FLOAT64 OPTIONS(description="Weekend vs weekday performance difference"),
  weather_impact_score FLOAT64 OPTIONS(description="Performance degradation in poor weather"),
  night_driving_frequency FLOAT64 OPTIONS(description="Frequency of night driving"),
  
  -- Safety incident history
  safety_incidents_30d INTEGER OPTIONS(description="Safety incidents in last 30 days"),
  near_miss_events_30d INTEGER OPTIONS(description="Near-miss events in last 30 days"),
  accident_history_90d INTEGER OPTIONS(description="Accident history in last 90 days"),
  days_since_last_incident INTEGER OPTIONS(description="Days since last safety incident"),
  
  -- Interaction with technology
  gps_signal_quality_avg FLOAT64 OPTIONS(description="Average GPS signal quality"),
  mobile_app_usage_frequency FLOAT64 OPTIONS(description="Frequency of mobile app interactions"),
  alert_response_time_avg FLOAT64 OPTIONS(description="Average response time to system alerts"),
  
  -- Predictive target variables (labels for ML)
  safety_incidents_next_30d INTEGER OPTIONS(description="Safety incidents in next 30 days (target)"),
  fuel_overconsumption_next_30d BOOLEAN OPTIONS(description="Fuel overconsumption in next 30 days (target)"),
  customer_complaint_next_30d BOOLEAN OPTIONS(description="Customer complaint in next 30 days (target)"),
  performance_decline_next_30d BOOLEAN OPTIONS(description="Performance decline in next 30 days (target)"),
  
  -- Feature engineering metadata
  calculated_at TIMESTAMP NOT NULL OPTIONS(description="Feature calculation timestamp"),
  feature_version STRING OPTIONS(description="Feature engineering version"),
  model_ready BOOLEAN OPTIONS(description="Ready for model training/inference")
)
PARTITION BY feature_date
CLUSTER BY driver_key, vehicle_key, tenant_id
OPTIONS (
  description="Driver behavior features for safety prediction and performance optimization",
  partition_expiration_days=1095,  -- 3 years for ML model lifecycle
  labels=[("environment", "production"), ("data_type", "ml_features")]
);

-- =============================================================================
-- 2. Vehicle Health Features (for Predictive Maintenance)
-- =============================================================================

CREATE OR REPLACE TABLE `intelligent_dataops_analytics.vehicle_health_features` (
  -- Identification and time windows
  feature_date DATE NOT NULL OPTIONS(description="Date for feature calculation"),
  vehicle_key STRING NOT NULL OPTIONS(description="Foreign key to vehicle_dim"),
  tenant_id STRING NOT NULL OPTIONS(description="Multi-tenant isolation key"),
  
  -- Vehicle context
  vehicle_age_months INTEGER OPTIONS(description="Vehicle age in months"),
  odometer_km INTEGER OPTIONS(description="Current odometer reading"),
  days_since_last_maintenance INTEGER OPTIONS(description="Days since last maintenance"),
  
  -- Engine performance indicators
  avg_engine_temperature FLOAT64 OPTIONS(description="Average engine temperature"),
  engine_temperature_variance FLOAT64 OPTIONS(description="Engine temperature variance"),
  engine_temperature_anomalies INTEGER OPTIONS(description="Temperature anomaly events"),
  
  -- Fuel system health
  fuel_efficiency_trend FLOAT64 OPTIONS(description="Fuel efficiency trend over 90 days"),
  fuel_efficiency_decline_rate FLOAT64 OPTIONS(description="Rate of efficiency decline"),
  fuel_system_anomalies INTEGER OPTIONS(description="Fuel system anomaly events"),
  
  -- Operational stress indicators
  avg_daily_distance_km FLOAT64 OPTIONS(description="Average daily distance"),
  high_stress_driving_hours FLOAT64 OPTIONS(description="Hours of high-stress driving"),
  stop_start_frequency FLOAT64 OPTIONS(description="Frequency of stop-start cycles"),
  load_factor_avg FLOAT64 OPTIONS(description="Average vehicle load factor"),
  
  -- Maintenance history patterns
  maintenance_frequency_90d INTEGER OPTIONS(description="Maintenance events in 90 days"),
  emergency_maintenance_90d INTEGER OPTIONS(description="Emergency maintenance in 90 days"),
  maintenance_cost_trend FLOAT64 OPTIONS(description="Maintenance cost trend"),
  recurring_issues_count INTEGER OPTIONS(description="Count of recurring maintenance issues"),
  
  -- Performance degradation indicators
  acceleration_performance_decline FLOAT64 OPTIONS(description="Acceleration performance decline"),
  braking_efficiency_decline FLOAT64 OPTIONS(description="Braking efficiency decline"),
  power_output_variance FLOAT64 OPTIONS(description="Engine power output variance"),
  
  -- Environmental impact factors
  extreme_weather_exposure_hours FLOAT64 OPTIONS(description="Hours exposed to extreme weather"),
  dusty_environment_exposure_hours FLOAT64 OPTIONS(description="Hours in dusty environments"),
  high_altitude_driving_hours FLOAT64 OPTIONS(description="Hours of high altitude driving"),
  
  -- Usage pattern analysis
  usage_intensity_score FLOAT64 OPTIONS(description="Vehicle usage intensity (0-1)"),
  usage_consistency_score FLOAT64 OPTIONS(description="Usage pattern consistency"),
  peak_load_frequency FLOAT64 OPTIONS(description="Frequency of peak load conditions"),
  
  -- Sensor and system health
  gps_sensor_reliability FLOAT64 OPTIONS(description="GPS sensor reliability score"),
  fuel_sensor_accuracy FLOAT64 OPTIONS(description="Fuel sensor accuracy score"),
  temperature_sensor_stability FLOAT64 OPTIONS(description="Temperature sensor stability"),
  
  -- Predictive maintenance targets
  maintenance_needed_next_30d BOOLEAN OPTIONS(description="Maintenance needed in next 30 days (target)"),
  breakdown_risk_next_60d BOOLEAN OPTIONS(description="Breakdown risk in next 60 days (target)"),
  major_repair_needed_next_90d BOOLEAN OPTIONS(description="Major repair needed in next 90 days (target)"),
  component_failure_risk_score FLOAT64 OPTIONS(description="Overall component failure risk (0-1)"),
  
  -- Cost prediction features
  estimated_maintenance_cost_next_30d NUMERIC(8,2) OPTIONS(description="Predicted maintenance cost"),
  downtime_risk_hours FLOAT64 OPTIONS(description="Predicted downtime risk in hours"),
  
  -- Feature engineering metadata
  calculated_at TIMESTAMP NOT NULL OPTIONS(description="Feature calculation timestamp"),
  feature_version STRING OPTIONS(description="Feature engineering version"),
  model_ready BOOLEAN OPTIONS(description="Ready for model training/inference")
)
PARTITION BY feature_date
CLUSTER BY vehicle_key, tenant_id
OPTIONS (
  description="Vehicle health features for predictive maintenance and failure prediction",
  partition_expiration_days=1095,  -- 3 years retention
  labels=[("environment", "production"), ("data_type", "ml_features")]
);

-- =============================================================================
-- 3. Route Optimization Features (for Dynamic Routing and ETA Prediction)
-- =============================================================================

CREATE OR REPLACE TABLE `intelligent_dataops_analytics.route_optimization_features` (
  -- Identification
  feature_date DATE NOT NULL OPTIONS(description="Date for feature calculation"),
  route_key STRING NOT NULL OPTIONS(description="Foreign key to route_dim"),
  time_of_day_bucket STRING NOT NULL OPTIONS(description="Time bucket: morning, midday, evening, night"),
  day_of_week STRING NOT NULL OPTIONS(description="Day of week for seasonal patterns"),
  tenant_id STRING NOT NULL OPTIONS(description="Multi-tenant isolation key"),
  
  -- Historical performance features
  avg_completion_time_minutes FLOAT64 OPTIONS(description="Average historical completion time"),
  completion_time_variance FLOAT64 OPTIONS(description="Completion time variability"),
  on_time_completion_rate FLOAT64 OPTIONS(description="Historical on-time rate"),
  
  -- Traffic and external factors
  avg_traffic_delay_minutes FLOAT64 OPTIONS(description="Average traffic delay"),
  traffic_congestion_score FLOAT64 OPTIONS(description="Route traffic congestion score"),
  weather_impact_factor FLOAT64 OPTIONS(description="Weather impact on route performance"),
  seasonal_factor FLOAT64 OPTIONS(description="Seasonal performance adjustment"),
  
  -- Route characteristics
  total_distance_km FLOAT64 OPTIONS(description="Total route distance"),
  number_of_stops INTEGER OPTIONS(description="Number of stops on route"),
  stop_density_per_km FLOAT64 OPTIONS(description="Stop density along route"),
  route_complexity_score FLOAT64 OPTIONS(description="Route complexity (turns, traffic lights)"),
  
  -- Customer behavior patterns
  customer_availability_rate FLOAT64 OPTIONS(description="Historical customer availability"),
  average_service_time_minutes FLOAT64 OPTIONS(description="Average time per stop"),
  failed_delivery_rate FLOAT64 OPTIONS(description="Historical failed delivery rate"),
  special_requirements_frequency FLOAT64 OPTIONS(description="Frequency of special delivery requirements"),
  
  -- Vehicle and driver matching
  optimal_vehicle_type STRING OPTIONS(description="Best performing vehicle type for route"),
  optimal_driver_experience_level STRING OPTIONS(description="Ideal driver experience level"),
  fuel_efficiency_on_route FLOAT64 OPTIONS(description="Average fuel efficiency for route"),
  
  -- Dynamic factors
  current_traffic_multiplier FLOAT64 OPTIONS(description="Real-time traffic adjustment factor"),
  weather_condition_code STRING OPTIONS(description="Current weather condition"),
  holiday_indicator BOOLEAN OPTIONS(description="Holiday/special event indicator"),
  construction_impact_score FLOAT64 OPTIONS(description="Construction zone impact"),
  
  -- Performance predictions
  predicted_completion_time_minutes FLOAT64 OPTIONS(description="ML-predicted completion time"),
  predicted_fuel_consumption_liters FLOAT64 OPTIONS(description="Predicted fuel consumption"),
  predicted_success_probability FLOAT64 OPTIONS(description="Predicted route success probability"),
  
  -- Optimization opportunities  
  distance_optimization_potential FLOAT64 OPTIONS(description="Potential distance savings"),
  time_optimization_potential FLOAT64 OPTIONS(description="Potential time savings"),
  consolidation_opportunity_score FLOAT64 OPTIONS(description="Route consolidation potential"),
  
  -- Target variables for ML
  actual_completion_time_next FLOAT64 OPTIONS(description="Actual completion time (target for ETA models)"),
  route_success_next BOOLEAN OPTIONS(description="Route success indicator (target)"),
  customer_satisfaction_next FLOAT64 OPTIONS(description="Customer satisfaction score (target)"),
  
  -- Feature metadata
  calculated_at TIMESTAMP NOT NULL OPTIONS(description="Feature calculation timestamp"),
  feature_version STRING OPTIONS(description="Feature engineering version"),
  model_ready BOOLEAN OPTIONS(description="Ready for model training/inference")
)
PARTITION BY feature_date
CLUSTER BY route_key, time_of_day_bucket, tenant_id
OPTIONS (
  description="Route optimization features for ETA prediction and dynamic routing",
  partition_expiration_days=730,  -- 2 years retention
  labels=[("environment", "production"), ("data_type", "ml_features")]
);

-- =============================================================================
-- 4. Anomaly Detection Features (for Fraud and Misuse Detection)
-- =============================================================================

CREATE OR REPLACE TABLE `intelligent_dataops_analytics.anomaly_detection_features` (
  -- Time and identification
  feature_datetime TIMESTAMP NOT NULL OPTIONS(description="Precise timestamp for anomaly detection"),
  entity_type STRING NOT NULL OPTIONS(description="Entity type: vehicle, driver, route"),
  entity_key STRING NOT NULL OPTIONS(description="Entity identifier"),
  tenant_id STRING NOT NULL OPTIONS(description="Multi-tenant isolation key"),
  
  -- Baseline behavior (rolling 30-day averages)
  baseline_daily_distance FLOAT64 OPTIONS(description="Baseline daily distance"),
  baseline_fuel_consumption FLOAT64 OPTIONS(description="Baseline fuel consumption"),
  baseline_operating_hours FLOAT64 OPTIONS(description="Baseline operating hours"),
  baseline_location_pattern STRING OPTIONS(description="Baseline location pattern hash"),
  
  -- Current period deviations
  distance_deviation_percent FLOAT64 OPTIONS(description="Distance deviation from baseline"),
  fuel_deviation_percent FLOAT64 OPTIONS(description="Fuel consumption deviation"),
  time_deviation_percent FLOAT64 OPTIONS(description="Operating time deviation"),
  location_deviation_score FLOAT64 OPTIONS(description="Location pattern deviation score"),
  
  -- Unusual patterns
  off_hours_usage_minutes INTEGER OPTIONS(description="Usage outside normal hours"),
  weekend_usage_anomaly BOOLEAN OPTIONS(description="Unusual weekend usage pattern"),
  unauthorized_location_visits INTEGER OPTIONS(description="Visits to unauthorized locations"),
  route_deviation_severity FLOAT64 OPTIONS(description="Severity of route deviations"),
  
  -- Fuel and resource anomalies
  fuel_level_anomalies INTEGER OPTIONS(description="Unusual fuel level changes"),
  fuel_efficiency_anomaly_score FLOAT64 OPTIONS(description="Fuel efficiency anomaly severity"),
  suspected_fuel_theft_events INTEGER OPTIONS(description="Suspected fuel theft incidents"),
  
  -- Speed and driving anomalies
  speed_pattern_anomaly_score FLOAT64 OPTIONS(description="Speed pattern anomaly score"),
  aggressive_driving_spike BOOLEAN OPTIONS(description="Unusual aggressive driving increase"),
  idle_time_anomaly_score FLOAT64 OPTIONS(description="Idle time anomaly severity"),
  
  -- Temporal anomalies
  unusual_start_times INTEGER OPTIONS(description="Count of unusual start times"),
  unusual_end_times INTEGER OPTIONS(description="Count of unusual end times"),
  duration_anomaly_score FLOAT64 OPTIONS(description="Trip duration anomaly score"),
  
  -- Cross-entity correlations
  multi_entity_anomaly BOOLEAN OPTIONS(description="Anomaly involving multiple entities"),
  coordinated_behavior_score FLOAT64 OPTIONS(description="Score for coordinated suspicious behavior"),
  
  -- Machine learning anomaly scores
  isolation_forest_score FLOAT64 OPTIONS(description="Isolation Forest anomaly score"),
  autoencoder_reconstruction_error FLOAT64 OPTIONS(description="Autoencoder reconstruction error"),
  statistical_anomaly_score FLOAT64 OPTIONS(description="Statistical anomaly score"),
  
  -- Risk and severity
  overall_anomaly_score FLOAT64 OPTIONS(description="Combined anomaly score (0-1)"),
  risk_level STRING OPTIONS(description="Risk level: low, medium, high, critical"),
  business_impact_score FLOAT64 OPTIONS(description="Potential business impact (0-1)"),
  
  -- Investigation support
  anomaly_type ARRAY<STRING> OPTIONS(description="Types of anomalies detected"),
  investigation_priority INTEGER OPTIONS(description="Investigation priority (1-5)"),
  similar_historical_events INTEGER OPTIONS(description="Count of similar historical events"),
  
  -- Response and resolution
  alert_generated BOOLEAN OPTIONS(description="Whether alert was generated"),
  investigation_status STRING OPTIONS(description="Investigation status"),
  resolution_action STRING OPTIONS(description="Action taken to resolve"),
  false_positive_flag BOOLEAN OPTIONS(description="Marked as false positive"),
  
  -- Feature metadata
  model_version STRING OPTIONS(description="Anomaly detection model version"),
  calculated_at TIMESTAMP NOT NULL OPTIONS(description="Feature calculation timestamp")
)
PARTITION BY DATE(feature_datetime)
CLUSTER BY entity_type, tenant_id, risk_level
OPTIONS (
  description="Anomaly detection features for fraud prevention and misuse detection",
  partition_expiration_days=1095,  -- 3 years retention for compliance
  labels=[("environment", "production"), ("data_type", "ml_features")]
);

-- =============================================================================
-- Create ML Feature Store Views for Easy Model Access
-- =============================================================================

-- Create a unified view for driver features
CREATE OR REPLACE VIEW `intelligent_dataops_analytics.driver_features_latest` AS
SELECT 
  d.*,
  v.avg_engine_temperature,
  v.fuel_efficiency_trend AS vehicle_fuel_trend,
  v.maintenance_frequency_90d
FROM `intelligent_dataops_analytics.driving_behavior_features` d
LEFT JOIN `intelligent_dataops_analytics.vehicle_health_features` v
  ON d.vehicle_key = v.vehicle_key 
  AND d.feature_date = v.feature_date
WHERE d.model_ready = TRUE
  AND d.feature_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY);

-- Create a view for route optimization features
CREATE OR REPLACE VIEW `intelligent_dataops_analytics.route_features_latest` AS
SELECT *
FROM `intelligent_dataops_analytics.route_optimization_features`
WHERE model_ready = TRUE
  AND feature_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY);

-- =============================================================================
-- Create summary information
-- =============================================================================

-- ✅ ML Feature tables created successfully!
-- 🤖 Tables created:
--   - driving_behavior_features (driver safety and performance ML)
--   - vehicle_health_features (predictive maintenance ML)
--   - route_optimization_features (ETA prediction and routing ML)
--   - anomaly_detection_features (fraud and misuse detection ML)
--
-- 📊 Views created:
--   - driver_features_latest (unified driver features)
--   - route_features_latest (latest route optimization features)
--
-- 🎯 Features ready for ML model training and inference
-- 🔄 Automatic feature versioning and model lifecycle support