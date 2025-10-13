-- =============================================================================
-- BigQuery Stored Procedure - Generate Daily Summaries
-- =============================================================================
-- Purpose: Generate daily aggregation summaries for vehicles, drivers, and routes
-- Usage: CALL `intelligent_dataops_analytics.sp_generate_daily_summaries`('2024-01-01');
-- =============================================================================

CREATE OR REPLACE PROCEDURE `intelligent_dataops_analytics.sp_generate_daily_summaries`(
  IN summary_date DATE
)
BEGIN
  DECLARE start_time TIMESTAMP;
  DECLARE vehicles_processed INT64;
  DECLARE drivers_processed INT64;
  
  SET start_time = CURRENT_TIMESTAMP();
  
  -- =============================================================================
  -- Generate Vehicle Daily Summary
  -- =============================================================================
  
  DELETE FROM `intelligent_dataops_analytics.vehicle_daily_summary` 
  WHERE summary_date = summary_date;
  
  INSERT INTO `intelligent_dataops_analytics.vehicle_daily_summary` (
    summary_date,
    vehicle_key,
    driver_key,
    tenant_id,
    total_distance_km,
    total_driving_hours,
    total_idle_hours,
    total_stopped_hours,
    average_speed_kmh,
    max_speed_kmh,
    speed_variance,
    time_over_speed_limit_minutes,
    fuel_consumed_liters,
    fuel_efficiency_kmpl,
    fuel_cost_usd,
    idle_fuel_consumption_liters,
    deliveries_completed,
    pickups_completed,
    on_time_deliveries,
    failed_deliveries,
    hard_braking_events,
    rapid_acceleration_events,
    speed_violations,
    unauthorized_stops,
    unique_locations_visited,
    total_stops,
    route_deviation_minutes,
    safety_score,
    efficiency_score,
    customer_service_score,
    overall_performance_score,
    co2_emissions_kg,
    engine_health_score,
    total_operational_cost_usd,
    cost_per_km_usd,
    cost_per_delivery_usd,
    data_completeness_percent,
    gps_signal_quality_avg,
    calculated_at,
    data_source_version
  )
  SELECT 
    summary_date as summary_date,
    vehicle_key,
    MODE(driver_key) as driver_key,  -- Most frequent driver
    tenant_id,
    
    -- Distance and movement metrics
    ROUND(MAX(odometer_km) - MIN(odometer_km), 2) as total_distance_km,
    ROUND(COUNT(DISTINCT CASE WHEN speed_kmh > 5 THEN TIMESTAMP_TRUNC(event_timestamp, HOUR) END), 2) as total_driving_hours,
    ROUND(COUNT(DISTINCT CASE WHEN speed_kmh = 0 AND engine_status = 'running' THEN TIMESTAMP_TRUNC(event_timestamp, MINUTE) END) / 60.0, 2) as total_idle_hours,
    ROUND(COUNT(DISTINCT CASE WHEN speed_kmh = 0 AND engine_status = 'off' THEN TIMESTAMP_TRUNC(event_timestamp, MINUTE) END) / 60.0, 2) as total_stopped_hours,
    
    -- Speed analytics
    ROUND(AVG(CASE WHEN speed_kmh > 0 THEN speed_kmh END), 2) as average_speed_kmh,
    ROUND(MAX(speed_kmh), 2) as max_speed_kmh,
    ROUND(STDDEV(speed_kmh), 2) as speed_variance,
    COUNTIF(speed_kmh > 100) * 5 as time_over_speed_limit_minutes,  -- Assuming 5-minute intervals
    
    -- Fuel efficiency metrics (estimated)
    ROUND((MAX(fuel_level_percent) - MIN(fuel_level_percent)) * 50 / 100, 2) as fuel_consumed_liters,  -- Assuming 50L tank
    ROUND((MAX(odometer_km) - MIN(odometer_km)) / GREATEST((MAX(fuel_level_percent) - MIN(fuel_level_percent)) * 0.5, 1), 2) as fuel_efficiency_kmpl,
    ROUND((MAX(fuel_level_percent) - MIN(fuel_level_percent)) * 50 * 1.2, 2) as fuel_cost_usd,  -- $1.2 per liter
    ROUND(COUNT(CASE WHEN speed_kmh = 0 AND engine_status = 'running' THEN 1 END) * 0.8 / 60, 2) as idle_fuel_consumption_liters,
    
    -- Operational performance (from delivery events)
    COALESCE(delivery_stats.deliveries_completed, 0) as deliveries_completed,
    COALESCE(delivery_stats.pickups_completed, 0) as pickups_completed,
    COALESCE(delivery_stats.on_time_deliveries, 0) as on_time_deliveries,
    COALESCE(delivery_stats.failed_deliveries, 0) as failed_deliveries,
    
    -- Safety and behavior metrics (simulated from telemetry patterns)
    COUNTIF(LAG(speed_kmh) OVER (PARTITION BY vehicle_key ORDER BY event_timestamp) - speed_kmh > 15) as hard_braking_events,
    COUNTIF(speed_kmh - LAG(speed_kmh) OVER (PARTITION BY vehicle_key ORDER BY event_timestamp) > 15) as rapid_acceleration_events,
    COUNTIF(speed_kmh > 100) as speed_violations,
    0 as unauthorized_stops,  -- To be calculated from route deviation logic
    
    -- Location and coverage
    APPROX_COUNT_DISTINCT(CONCAT(CAST(ROUND(latitude, 3) AS STRING), ',', CAST(ROUND(longitude, 3) AS STRING))) as unique_locations_visited,
    COUNT(DISTINCT CASE WHEN speed_kmh = 0 AND LAG(speed_kmh) OVER (PARTITION BY vehicle_key ORDER BY event_timestamp) > 5 THEN event_timestamp END) as total_stops,
    0 as route_deviation_minutes,  -- To be calculated with route comparison
    
    -- Calculated performance scores (0.0 - 1.0)
    ROUND(1.0 - (COUNTIF(speed_kmh > 100) / GREATEST(COUNT(*), 1)), 3) as safety_score,
    ROUND(GREATEST(0, 1.0 - ABS(AVG(CASE WHEN speed_kmh > 0 THEN speed_kmh END) - 60) / 60), 3) as efficiency_score,
    ROUND(COALESCE(delivery_stats.on_time_deliveries / GREATEST(delivery_stats.deliveries_completed, 1), 0.5), 3) as customer_service_score,
    ROUND((1.0 - (COUNTIF(speed_kmh > 100) / GREATEST(COUNT(*), 1)) + 
           GREATEST(0, 1.0 - ABS(AVG(CASE WHEN speed_kmh > 0 THEN speed_kmh END) - 60) / 60) +
           COALESCE(delivery_stats.on_time_deliveries / GREATEST(delivery_stats.deliveries_completed, 1), 0.5)) / 3, 3) as overall_performance_score,
    
    -- Environmental metrics
    ROUND((MAX(fuel_level_percent) - MIN(fuel_level_percent)) * 50 * 2.31 / 100, 2) as co2_emissions_kg,  -- 2.31 kg CO2 per liter
    ROUND(1.0 - (STDDEV(engine_temperature) / GREATEST(AVG(engine_temperature), 1)), 3) as engine_health_score,
    
    -- Cost allocation (estimated)
    ROUND((MAX(fuel_level_percent) - MIN(fuel_level_percent)) * 50 * 1.2 + 
          (MAX(odometer_km) - MIN(odometer_km)) * 0.15, 2) as total_operational_cost_usd,
    ROUND(((MAX(fuel_level_percent) - MIN(fuel_level_percent)) * 50 * 1.2 + 
           (MAX(odometer_km) - MIN(odometer_km)) * 0.15) / 
          GREATEST(MAX(odometer_km) - MIN(odometer_km), 1), 4) as cost_per_km_usd,
    ROUND(((MAX(fuel_level_percent) - MIN(fuel_level_percent)) * 50 * 1.2 + 
           (MAX(odometer_km) - MIN(odometer_km)) * 0.15) / 
          GREATEST(COALESCE(delivery_stats.deliveries_completed, 1), 1), 2) as cost_per_delivery_usd,
    
    -- Data quality and completeness
    ROUND(COUNT(CASE WHEN data_quality_score >= 0.8 THEN 1 END) * 100.0 / COUNT(*), 1) as data_completeness_percent,
    ROUND(AVG(CASE WHEN location_valid THEN 1.0 ELSE 0.0 END), 3) as gps_signal_quality_avg,
    
    -- Calculation metadata
    CURRENT_TIMESTAMP() as calculated_at,
    'v1.0' as data_source_version
    
  FROM `intelligent_dataops_analytics.iot_telemetry_fact` t
  
  -- Join with delivery events for operational metrics
  LEFT JOIN (
    SELECT 
      vehicle_key,
      tenant_id,
      COUNT(CASE WHEN event_type = 'delivery' AND event_status = 'completed' THEN 1 END) as deliveries_completed,
      COUNT(CASE WHEN event_type = 'pickup' AND event_status = 'completed' THEN 1 END) as pickups_completed,
      COUNT(CASE WHEN event_type = 'delivery' AND event_status = 'completed' AND delay_minutes <= 15 THEN 1 END) as on_time_deliveries,
      COUNT(CASE WHEN event_status = 'failed' THEN 1 END) as failed_deliveries
    FROM `intelligent_dataops_analytics.delivery_events_fact`
    WHERE event_date = summary_date
    GROUP BY vehicle_key, tenant_id
  ) delivery_stats ON t.vehicle_key = delivery_stats.vehicle_key AND t.tenant_id = delivery_stats.tenant_id
  
  WHERE t.event_date = summary_date
  GROUP BY vehicle_key, tenant_id;
  
  SET vehicles_processed = @@row_count;
  
  -- =============================================================================
  -- Generate Driver Performance Summary
  -- =============================================================================
  
  DELETE FROM `intelligent_dataops_analytics.driver_performance_summary` 
  WHERE summary_date = summary_date;
  
  INSERT INTO `intelligent_dataops_analytics.driver_performance_summary` (
    summary_date,
    driver_key,
    primary_vehicle_key,
    tenant_id,
    total_working_hours,
    driving_hours,
    break_hours,
    overtime_hours,
    deliveries_per_hour,
    miles_per_hour,
    fuel_efficiency_vs_baseline,
    safety_violations,
    accident_incidents,
    near_miss_events,
    safety_score,
    aggressive_driving_events,
    smooth_driving_percentage,
    speed_compliance_percentage,
    on_time_percentage,
    route_adherence_percentage,
    customer_satisfaction_score,
    vehicle_idle_time_percentage,
    unauthorized_use_minutes,
    total_revenue_generated_usd,
    operational_cost_allocated_usd,
    profit_margin_usd,
    training_hours_completed,
    compliance_violations,
    certifications_expiring,
    safety_rank,
    efficiency_rank,
    customer_service_rank,
    calculated_at,
    peer_group_size
  )
  SELECT 
    summary_date,
    driver_key,
    MODE(vehicle_key) as primary_vehicle_key,
    tenant_id,
    
    -- Working hours and productivity
    ROUND(COUNT(DISTINCT TIMESTAMP_TRUNC(event_timestamp, HOUR)), 2) as total_working_hours,
    ROUND(COUNT(DISTINCT CASE WHEN speed_kmh > 5 THEN TIMESTAMP_TRUNC(event_timestamp, HOUR) END), 2) as driving_hours,
    2.0 as break_hours,  -- Standard assumption
    GREATEST(0, COUNT(DISTINCT TIMESTAMP_TRUNC(event_timestamp, HOUR)) - 8) as overtime_hours,
    
    -- Performance metrics
    ROUND(COALESCE(delivery_stats.total_deliveries / GREATEST(COUNT(DISTINCT TIMESTAMP_TRUNC(event_timestamp, HOUR)), 1), 0), 2) as deliveries_per_hour,
    ROUND(COALESCE((vehicle_stats.total_distance_km) / GREATEST(COUNT(DISTINCT CASE WHEN speed_kmh > 5 THEN TIMESTAMP_TRUNC(event_timestamp, HOUR) END), 1), 0), 2) as miles_per_hour,
    ROUND(COALESCE(vehicle_stats.fuel_efficiency_kmpl / 12.0, 1.0), 3) as fuel_efficiency_vs_baseline,  -- Baseline 12 kmpl
    
    -- Safety performance
    COUNTIF(speed_kmh > 100) as safety_violations,
    0 as accident_incidents,  -- From separate incident table
    0 as near_miss_events,    -- From separate incident table
    ROUND(1.0 - (COUNTIF(speed_kmh > 100) / GREATEST(COUNT(*), 1)), 3) as safety_score,
    
    -- Driving behavior analysis
    vehicle_stats.hard_braking_events + vehicle_stats.rapid_acceleration_events as aggressive_driving_events,
    ROUND(100.0 * (1.0 - (vehicle_stats.hard_braking_events + vehicle_stats.rapid_acceleration_events) / GREATEST(COUNT(*) / 100, 1)), 1) as smooth_driving_percentage,
    ROUND(100.0 * (1.0 - COUNTIF(speed_kmh > 100) / GREATEST(COUNT(*), 1)), 1) as speed_compliance_percentage,
    
    -- Route and navigation performance
    ROUND(100.0 * COALESCE(delivery_stats.on_time_deliveries / GREATEST(delivery_stats.total_deliveries, 1), 0.8), 1) as on_time_percentage,
    95.0 as route_adherence_percentage,  -- To be calculated with route comparison
    4.2 as customer_satisfaction_score,   -- From customer feedback system
    
    -- Vehicle utilization
    ROUND(100.0 * vehicle_stats.total_idle_hours / GREATEST(vehicle_stats.total_driving_hours + vehicle_stats.total_idle_hours, 1), 1) as vehicle_idle_time_percentage,
    0 as unauthorized_use_minutes,       -- From after-hours usage detection
    
    -- Cost and revenue impact
    COALESCE(delivery_stats.total_deliveries * 25.0, 0) as total_revenue_generated_usd,  -- $25 per delivery
    vehicle_stats.total_operational_cost_usd as operational_cost_allocated_usd,
    COALESCE(delivery_stats.total_deliveries * 25.0, 0) - vehicle_stats.total_operational_cost_usd as profit_margin_usd,
    
    -- Training and compliance
    0 as training_hours_completed,       -- From training system
    0 as compliance_violations,          -- From compliance monitoring
    0 as certifications_expiring,       -- From certification tracking
    
    -- Performance rankings (calculated later)
    0 as safety_rank,
    0 as efficiency_rank, 
    0 as customer_service_rank,
    
    -- Calculation metadata
    CURRENT_TIMESTAMP() as calculated_at,
    (SELECT COUNT(DISTINCT driver_key) FROM `intelligent_dataops_analytics.iot_telemetry_fact` WHERE event_date = summary_date AND tenant_id = t.tenant_id) as peer_group_size
    
  FROM `intelligent_dataops_analytics.iot_telemetry_fact` t
  
  -- Join with vehicle daily summary
  LEFT JOIN `intelligent_dataops_analytics.vehicle_daily_summary` vehicle_stats 
    ON t.vehicle_key = vehicle_stats.vehicle_key 
    AND vehicle_stats.summary_date = summary_date
    AND t.tenant_id = vehicle_stats.tenant_id
  
  -- Join with delivery events
  LEFT JOIN (
    SELECT 
      driver_key,
      tenant_id,
      COUNT(CASE WHEN event_status = 'completed' THEN 1 END) as total_deliveries,
      COUNT(CASE WHEN event_status = 'completed' AND delay_minutes <= 15 THEN 1 END) as on_time_deliveries
    FROM `intelligent_dataops_analytics.delivery_events_fact`
    WHERE event_date = summary_date
    GROUP BY driver_key, tenant_id
  ) delivery_stats ON t.driver_key = delivery_stats.driver_key AND t.tenant_id = delivery_stats.tenant_id
  
  WHERE t.event_date = summary_date
    AND t.driver_key IS NOT NULL
  GROUP BY driver_key, tenant_id;
  
  SET drivers_processed = @@row_count;
  
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
    'sp_generate_daily_summaries',
    summary_date,
    start_time,
    CURRENT_TIMESTAMP(),
    vehicles_processed + drivers_processed,
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), start_time, SECOND),
    'SUCCESS',
    'SYSTEM',
    JSON_OBJECT(
      'vehicles_processed', vehicles_processed,
      'drivers_processed', drivers_processed
    ),
    CURRENT_TIMESTAMP()
  );
  
  SELECT 
    'sp_generate_daily_summaries' as procedure_name,
    summary_date,
    vehicles_processed,
    drivers_processed,
    vehicles_processed + drivers_processed as total_rows_processed,
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), start_time, SECOND) as processing_duration_seconds,
    'SUCCESS' as status;
    
END;