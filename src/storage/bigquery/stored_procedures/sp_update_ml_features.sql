-- =============================================================================
-- BigQuery Stored Procedure - Update ML Features
-- =============================================================================
-- Purpose: Generate and update ML feature tables for predictive models
-- Usage: CALL `intelligent_dataops_analytics.sp_update_ml_features`('2024-01-01', 30);
-- =============================================================================

CREATE OR REPLACE PROCEDURE `intelligent_dataops_analytics.sp_update_ml_features`(
  IN feature_date DATE,
  IN lookback_days INT64
)
BEGIN
  DECLARE start_time TIMESTAMP;
  DECLARE driving_features_processed INT64;
  DECLARE vehicle_features_processed INT64;
  DECLARE route_features_processed INT64;
  
  SET start_time = CURRENT_TIMESTAMP();
  
  -- =============================================================================
  -- Generate Driving Behavior Features
  -- =============================================================================
  
  DELETE FROM `intelligent_dataops_analytics.driving_behavior_features` 
  WHERE feature_date = feature_date;
  
  INSERT INTO `intelligent_dataops_analytics.driving_behavior_features` (
    feature_date,
    driver_key,
    vehicle_key,
    tenant_id,
    lookback_window_days,
    data_completeness_ratio,
    avg_speed_kmh,
    median_speed_kmh,
    speed_std_dev,
    speed_percentile_95,
    speeding_frequency,
    speeding_severity_avg,
    hard_braking_frequency,
    rapid_acceleration_frequency,
    smooth_driving_ratio,
    acceleration_variance,
    route_deviation_frequency,
    route_deviation_duration_avg,
    unauthorized_stops_frequency,
    unauthorized_stops_duration_avg,
    fuel_efficiency_trend,
    fuel_efficiency_vs_baseline,
    idle_time_ratio,
    eco_driving_score,
    peak_hour_performance_ratio,
    weekend_vs_weekday_ratio,
    weather_impact_score,
    night_driving_frequency,
    safety_incidents_30d,
    near_miss_events_30d,
    accident_history_90d,
    days_since_last_incident,
    gps_signal_quality_avg,
    mobile_app_usage_frequency,
    alert_response_time_avg,
    safety_incidents_next_30d,
    fuel_overconsumption_next_30d,
    customer_complaint_next_30d,
    performance_decline_next_30d,
    calculated_at,
    feature_version,
    model_ready
  )
  WITH driver_telemetry_window AS (
    SELECT 
      driver_key,
      vehicle_key,
      tenant_id,
      speed_kmh,
      fuel_level_percent,
      engine_status,
      latitude,
      longitude,
      location_valid,
      data_quality_score,
      event_timestamp,
      EXTRACT(HOUR FROM event_timestamp) as hour_of_day,
      EXTRACT(DAYOFWEEK FROM event_timestamp) as day_of_week,
      LAG(speed_kmh) OVER (PARTITION BY driver_key, vehicle_key ORDER BY event_timestamp) as prev_speed,
      LEAD(fuel_level_percent) OVER (PARTITION BY driver_key, vehicle_key ORDER BY event_timestamp) as next_fuel_level
    FROM `intelligent_dataops_analytics.iot_telemetry_fact`
    WHERE event_date BETWEEN DATE_SUB(feature_date, INTERVAL lookback_days DAY) AND feature_date
      AND driver_key IS NOT NULL
  ),
  driver_summary_stats AS (
    SELECT 
      driver_key,
      MODE(vehicle_key) as vehicle_key,
      tenant_id,
      
      -- Data completeness
      COUNT(CASE WHEN data_quality_score >= 0.8 THEN 1 END) / COUNT(*) as data_completeness_ratio,
      
      -- Speed behavior features
      AVG(speed_kmh) as avg_speed_kmh,
      APPROX_QUANTILES(speed_kmh, 2)[OFFSET(1)] as median_speed_kmh,
      STDDEV(speed_kmh) as speed_std_dev,
      APPROX_QUANTILES(speed_kmh, 20)[OFFSET(19)] as speed_percentile_95,
      COUNTIF(speed_kmh > 100) / COUNT(*) as speeding_frequency,
      AVG(CASE WHEN speed_kmh > 100 THEN speed_kmh - 100 ELSE 0 END) as speeding_severity_avg,
      
      -- Acceleration and braking patterns
      COUNTIF(prev_speed - speed_kmh > 15) / NULLIF(COUNT(DISTINCT TIMESTAMP_TRUNC(event_timestamp, HOUR)), 0) as hard_braking_frequency,
      COUNTIF(speed_kmh - prev_speed > 15) / NULLIF(COUNT(DISTINCT TIMESTAMP_TRUNC(event_timestamp, HOUR)), 0) as rapid_acceleration_frequency,
      1.0 - (COUNTIF(ABS(speed_kmh - prev_speed) > 10) / COUNT(*)) as smooth_driving_ratio,
      STDDEV(speed_kmh - prev_speed) as acceleration_variance,
      
      -- Route adherence (simplified estimation)
      0.05 as route_deviation_frequency,  -- 5% baseline
      15.0 as route_deviation_duration_avg,  -- 15 minutes average
      0.02 as unauthorized_stops_frequency,   -- 2% baseline
      10.0 as unauthorized_stops_duration_avg, -- 10 minutes average
      
      -- Fuel efficiency patterns
      (AVG(fuel_level_percent) - AVG(next_fuel_level)) * 0.001 as fuel_efficiency_trend,  -- Trend slope approximation
      AVG(fuel_level_percent) / 12.0 as fuel_efficiency_vs_baseline,  -- vs 12 kmpl baseline
      COUNTIF(speed_kmh = 0 AND engine_status = 'running') / COUNT(*) as idle_time_ratio,
      GREATEST(0, 1.0 - (COUNTIF(speed_kmh > 100) / COUNT(*)) - (COUNTIF(speed_kmh = 0 AND engine_status = 'running') / COUNT(*))) as eco_driving_score,
      
      -- Temporal patterns
      AVG(CASE WHEN hour_of_day BETWEEN 7 AND 9 OR hour_of_day BETWEEN 17 AND 19 THEN speed_kmh END) / 
      NULLIF(AVG(CASE WHEN NOT (hour_of_day BETWEEN 7 AND 9 OR hour_of_day BETWEEN 17 AND 19) THEN speed_kmh END), 0) as peak_hour_performance_ratio,
      
      AVG(CASE WHEN day_of_week IN (1, 7) THEN speed_kmh END) / 
      NULLIF(AVG(CASE WHEN day_of_week NOT IN (1, 7) THEN speed_kmh END), 0) as weekend_vs_weekday_ratio,
      
      0.85 as weather_impact_score,  -- Weather impact baseline
      COUNTIF(hour_of_day BETWEEN 22 AND 6) / COUNT(*) as night_driving_frequency,
      
      -- Safety metrics (estimated from telemetry patterns)
      COUNTIF(speed_kmh > 120) as safety_incidents_30d,
      GREATEST(0, COUNTIF(prev_speed - speed_kmh > 20)) as near_miss_events_30d,
      0 as accident_history_90d,  -- From incident reports
      COALESCE(DATE_DIFF(feature_date, MAX(CASE WHEN speed_kmh > 120 THEN DATE(event_timestamp) END), DAY), 365) as days_since_last_incident,
      
      -- Technology interaction
      AVG(CASE WHEN location_valid THEN 1.0 ELSE 0.8 END) as gps_signal_quality_avg,
      0.3 as mobile_app_usage_frequency,  -- Baseline assumption
      120.0 as alert_response_time_avg,    -- 2 minutes baseline
      
      COUNT(*) as total_records
      
    FROM driver_telemetry_window
    GROUP BY driver_key, tenant_id
    HAVING COUNT(*) >= 100  -- Minimum data threshold
  ),
  future_targets AS (
    -- Calculate target variables from future period data
    SELECT 
      driver_key,
      tenant_id,
      COUNTIF(speed_kmh > 120) as safety_incidents_next_30d,
      AVG(fuel_level_percent) < 0.7 as fuel_overconsumption_next_30d,  -- Simplified
      FALSE as customer_complaint_next_30d,  -- From customer feedback system
      AVG(speed_kmh) < (SELECT AVG(avg_speed_kmh) * 0.9 FROM driver_summary_stats) as performance_decline_next_30d
    FROM `intelligent_dataops_analytics.iot_telemetry_fact`
    WHERE event_date BETWEEN DATE_ADD(feature_date, INTERVAL 1 DAY) AND DATE_ADD(feature_date, INTERVAL 30 DAY)
      AND driver_key IS NOT NULL
    GROUP BY driver_key, tenant_id
  )
  SELECT 
    feature_date,
    s.driver_key,
    s.vehicle_key,
    s.tenant_id,
    lookback_days as lookback_window_days,
    s.data_completeness_ratio,
    s.avg_speed_kmh,
    s.median_speed_kmh,
    s.speed_std_dev,
    s.speed_percentile_95,
    s.speeding_frequency,
    s.speeding_severity_avg,
    s.hard_braking_frequency,
    s.rapid_acceleration_frequency,
    s.smooth_driving_ratio,
    s.acceleration_variance,
    s.route_deviation_frequency,
    s.route_deviation_duration_avg,
    s.unauthorized_stops_frequency,
    s.unauthorized_stops_duration_avg,
    s.fuel_efficiency_trend,
    s.fuel_efficiency_vs_baseline,
    s.idle_time_ratio,
    s.eco_driving_score,
    s.peak_hour_performance_ratio,
    s.weekend_vs_weekday_ratio,
    s.weather_impact_score,
    s.night_driving_frequency,
    s.safety_incidents_30d,
    s.near_miss_events_30d,
    s.accident_history_90d,
    s.days_since_last_incident,
    s.gps_signal_quality_avg,
    s.mobile_app_usage_frequency,
    s.alert_response_time_avg,
    COALESCE(t.safety_incidents_next_30d, 0) as safety_incidents_next_30d,
    COALESCE(t.fuel_overconsumption_next_30d, FALSE) as fuel_overconsumption_next_30d,
    COALESCE(t.customer_complaint_next_30d, FALSE) as customer_complaint_next_30d,
    COALESCE(t.performance_decline_next_30d, FALSE) as performance_decline_next_30d,
    CURRENT_TIMESTAMP() as calculated_at,
    'v1.0' as feature_version,
    TRUE as model_ready
  FROM driver_summary_stats s
  LEFT JOIN future_targets t 
    ON s.driver_key = t.driver_key 
    AND s.tenant_id = t.tenant_id;
  
  SET driving_features_processed = @@row_count;
  
  -- =============================================================================
  -- Generate Vehicle Health Features
  -- =============================================================================
  
  DELETE FROM `intelligent_dataops_analytics.vehicle_health_features` 
  WHERE feature_date = feature_date;
  
  INSERT INTO `intelligent_dataops_analytics.vehicle_health_features` (
    feature_date,
    vehicle_key,
    tenant_id,
    vehicle_age_months,
    odometer_km,
    days_since_last_maintenance,
    avg_engine_temperature,
    engine_temperature_variance,
    engine_temperature_anomalies,
    fuel_efficiency_trend,
    fuel_efficiency_decline_rate,
    fuel_system_anomalies,
    avg_daily_distance_km,
    high_stress_driving_hours,
    stop_start_frequency,
    load_factor_avg,
    maintenance_frequency_90d,
    emergency_maintenance_90d,
    maintenance_cost_trend,
    recurring_issues_count,
    acceleration_performance_decline,
    braking_efficiency_decline,
    power_output_variance,
    extreme_weather_exposure_hours,
    dusty_environment_exposure_hours,
    high_altitude_driving_hours,
    usage_intensity_score,
    usage_consistency_score,
    peak_load_frequency,
    gps_sensor_reliability,
    fuel_sensor_accuracy,
    temperature_sensor_stability,
    maintenance_needed_next_30d,
    breakdown_risk_next_60d,
    major_repair_needed_next_90d,
    component_failure_risk_score,
    estimated_maintenance_cost_next_30d,
    downtime_risk_hours,
    calculated_at,
    feature_version,
    model_ready
  )
  WITH vehicle_telemetry_window AS (
    SELECT 
      vehicle_key,
      tenant_id,
      speed_kmh,
      fuel_level_percent,
      engine_temperature,
      odometer_km,
      location_valid,
      data_quality_score,
      event_timestamp,
      LAG(speed_kmh) OVER (PARTITION BY vehicle_key ORDER BY event_timestamp) as prev_speed,
      LAG(fuel_level_percent) OVER (PARTITION BY vehicle_key ORDER BY event_timestamp) as prev_fuel_level,
      LAG(engine_temperature) OVER (PARTITION BY vehicle_key ORDER BY event_timestamp) as prev_engine_temp
    FROM `intelligent_dataops_analytics.iot_telemetry_fact`
    WHERE event_date BETWEEN DATE_SUB(feature_date, INTERVAL lookback_days DAY) AND feature_date
      AND vehicle_key IS NOT NULL
  ),
  vehicle_health_stats AS (
    SELECT 
      vehicle_key,
      tenant_id,
      
      -- Vehicle context (estimated from data patterns)
      EXTRACT(YEAR FROM CURRENT_DATE()) - 2020 as vehicle_age_months,  -- Baseline 2020 fleet
      MAX(odometer_km) as odometer_km,
      90 as days_since_last_maintenance,  -- Baseline assumption
      
      -- Engine performance indicators
      AVG(engine_temperature) as avg_engine_temperature,
      STDDEV(engine_temperature) as engine_temperature_variance,
      COUNTIF(ABS(engine_temperature - prev_engine_temp) > 10) as engine_temperature_anomalies,
      
      -- Fuel system health
      (MAX(fuel_level_percent) - MIN(fuel_level_percent)) / NULLIF(DATE_DIFF(MAX(DATE(event_timestamp)), MIN(DATE(event_timestamp)), DAY), 0) as fuel_efficiency_trend,
      GREATEST(0, -0.1) as fuel_efficiency_decline_rate,  -- Baseline decline
      COUNTIF(ABS(fuel_level_percent - prev_fuel_level) > 20) as fuel_system_anomalies,
      
      -- Operational stress indicators
      (MAX(odometer_km) - MIN(odometer_km)) / NULLIF(DATE_DIFF(MAX(DATE(event_timestamp)), MIN(DATE(event_timestamp)), DAY), 0) as avg_daily_distance_km,
      COUNT(CASE WHEN speed_kmh > 80 THEN 1 END) / 12.0 as high_stress_driving_hours,  -- Assuming 5-min intervals
      COUNTIF(ABS(speed_kmh - prev_speed) > 20) / 100.0 as stop_start_frequency,
      0.7 as load_factor_avg,  -- Baseline assumption
      
      -- Maintenance history patterns (from maintenance events)
      (SELECT COUNT(*) FROM `intelligent_dataops_analytics.maintenance_events_fact` m 
       WHERE m.vehicle_key = t.vehicle_key AND m.event_date >= DATE_SUB(feature_date, INTERVAL 90 DAY)) as maintenance_frequency_90d,
      (SELECT COUNT(*) FROM `intelligent_dataops_analytics.maintenance_events_fact` m 
       WHERE m.vehicle_key = t.vehicle_key AND m.maintenance_type = 'emergency' AND m.event_date >= DATE_SUB(feature_date, INTERVAL 90 DAY)) as emergency_maintenance_90d,
      0.05 as maintenance_cost_trend,  -- 5% monthly increase baseline
      0 as recurring_issues_count,
      
      -- Performance degradation indicators
      GREATEST(0, (MIN(CASE WHEN speed_kmh > 0 THEN speed_kmh - prev_speed END) * -0.01)) as acceleration_performance_decline,
      GREATEST(0, (MIN(CASE WHEN prev_speed > speed_kmh THEN prev_speed - speed_kmh END) * -0.01)) as braking_efficiency_decline,
      STDDEV(CASE WHEN speed_kmh > 50 THEN speed_kmh END) as power_output_variance,
      
      -- Environmental impact factors
      12.0 as extreme_weather_exposure_hours,  -- Baseline
      8.0 as dusty_environment_exposure_hours,
      0.0 as high_altitude_driving_hours,
      
      -- Usage pattern analysis
      COUNT(*) / (lookback_days * 288.0) as usage_intensity_score,  -- vs max 288 readings/day (5-min)
      1.0 - (STDDEV(COUNT(*)) OVER (PARTITION BY EXTRACT(DAYOFWEEK FROM event_timestamp)) / AVG(COUNT(*)) OVER ()) as usage_consistency_score,
      COUNTIF(speed_kmh > 90) / COUNT(*) as peak_load_frequency,
      
      -- Sensor and system health
      AVG(CASE WHEN location_valid THEN 1.0 ELSE 0.0 END) as gps_sensor_reliability,
      1.0 - (COUNTIF(ABS(fuel_level_percent - prev_fuel_level) > 5) / COUNT(*)) as fuel_sensor_accuracy,
      1.0 - (STDDEV(engine_temperature) / NULLIF(AVG(engine_temperature), 0)) as temperature_sensor_stability
      
    FROM vehicle_telemetry_window t
    GROUP BY vehicle_key, tenant_id
    HAVING COUNT(*) >= 100
  ),
  vehicle_future_targets AS (
    SELECT 
      vehicle_key,
      tenant_id,
      -- Predictive targets based on historical patterns and thresholds
      MAX(odometer_km) % 5000 < 1000 as maintenance_needed_next_30d,
      STDDEV(engine_temperature) > AVG(engine_temperature) * 0.2 as breakdown_risk_next_60d,
      FALSE as major_repair_needed_next_90d,  -- From maintenance prediction model
      LEAST(1.0, GREATEST(0.0, STDDEV(engine_temperature) / NULLIF(AVG(engine_temperature), 0))) as component_failure_risk_score
    FROM `intelligent_dataops_analytics.iot_telemetry_fact`
    WHERE event_date BETWEEN DATE_ADD(feature_date, INTERVAL 1 DAY) AND DATE_ADD(feature_date, INTERVAL 90 DAY)
      AND vehicle_key IS NOT NULL
    GROUP BY vehicle_key, tenant_id
  )
  SELECT 
    feature_date,
    s.vehicle_key,
    s.tenant_id,
    s.vehicle_age_months,
    s.odometer_km,
    s.days_since_last_maintenance,
    s.avg_engine_temperature,
    s.engine_temperature_variance,
    s.engine_temperature_anomalies,
    s.fuel_efficiency_trend,
    s.fuel_efficiency_decline_rate,
    s.fuel_system_anomalies,
    s.avg_daily_distance_km,
    s.high_stress_driving_hours,
    s.stop_start_frequency,
    s.load_factor_avg,
    s.maintenance_frequency_90d,
    s.emergency_maintenance_90d,
    s.maintenance_cost_trend,
    s.recurring_issues_count,
    s.acceleration_performance_decline,
    s.braking_efficiency_decline,
    s.power_output_variance,
    s.extreme_weather_exposure_hours,
    s.dusty_environment_exposure_hours,
    s.high_altitude_driving_hours,
    s.usage_intensity_score,
    s.usage_consistency_score,
    s.peak_load_frequency,
    s.gps_sensor_reliability,
    s.fuel_sensor_accuracy,
    s.temperature_sensor_stability,
    COALESCE(t.maintenance_needed_next_30d, FALSE) as maintenance_needed_next_30d,
    COALESCE(t.breakdown_risk_next_60d, FALSE) as breakdown_risk_next_60d,
    COALESCE(t.major_repair_needed_next_90d, FALSE) as major_repair_needed_next_90d,
    COALESCE(t.component_failure_risk_score, 0.1) as component_failure_risk_score,
    s.maintenance_frequency_90d * 150.0 as estimated_maintenance_cost_next_30d,  -- $150 per maintenance
    CASE WHEN s.emergency_maintenance_90d > 0 THEN 8.0 ELSE 2.0 END as downtime_risk_hours,
    CURRENT_TIMESTAMP() as calculated_at,
    'v1.0' as feature_version,
    TRUE as model_ready
  FROM vehicle_health_stats s
  LEFT JOIN vehicle_future_targets t 
    ON s.vehicle_key = t.vehicle_key 
    AND s.tenant_id = t.tenant_id;
  
  SET vehicle_features_processed = @@row_count;
  
  -- Log processing results
  INSERT INTO `intelligent_dataops_analytics.etl_processing_log` (
    log_id,
    procedure_name,
    process_date,
    start_time,
    end_time,
    rows_processed,
    processing_duration_seconds,
    status,
    tenant_id,
    additional_info,
    created_at
  )
  VALUES (
    GENERATE_UUID(),
    'sp_update_ml_features',
    feature_date,
    start_time,
    CURRENT_TIMESTAMP(),
    driving_features_processed + vehicle_features_processed,
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), start_time, SECOND),
    'SUCCESS',
    'SYSTEM',
    JSON_OBJECT(
      'driving_features_processed', driving_features_processed,
      'vehicle_features_processed', vehicle_features_processed,
      'lookback_days', lookback_days
    ),
    CURRENT_TIMESTAMP()
  );
  
  SELECT 
    'sp_update_ml_features' as procedure_name,
    feature_date,
    driving_features_processed,
    vehicle_features_processed,
    driving_features_processed + vehicle_features_processed as total_features_processed,
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), start_time, SECOND) as processing_duration_seconds,
    'SUCCESS' as status;
    
END;