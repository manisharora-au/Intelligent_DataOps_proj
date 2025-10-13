-- =============================================================================
-- BigQuery Stored Procedure - Load IoT Telemetry Data
-- =============================================================================
-- Purpose: Transform and load raw IoT telemetry data into fact table
-- Usage: CALL `intelligent_dataops_analytics.sp_load_iot_telemetry`('2024-01-01', 100);
-- =============================================================================

CREATE OR REPLACE PROCEDURE `intelligent_dataops_analytics.sp_load_iot_telemetry`(
  IN process_date DATE,
  IN batch_size INT64
)
BEGIN
  DECLARE rows_processed INT64;
  DECLARE start_time TIMESTAMP;
  DECLARE end_time TIMESTAMP;
  
  SET start_time = CURRENT_TIMESTAMP();
  
  -- Data quality validation and transformation
  CREATE OR REPLACE TEMP TABLE telemetry_staging AS
  SELECT 
    -- Time dimensions
    DATE(timestamp) as event_date,
    timestamp as event_timestamp,
    
    -- Location data with validation (already validated in existing table)
    latitude,
    longitude,
    NULL as location_accuracy,  -- Not available in source
    
    -- Vehicle metrics (already processed in existing table)
    vehicle_id,
    speed_kmh,
    fuel_level as fuel_level_percent,
    engine_status,
    odometer as odometer_km,
    temperature as engine_temperature,
    
    -- Contextual data
    driver_id,
    route_id,
    
    -- Data quality scoring (use existing scores where available)
    COALESCE(data_quality_score, 
      CASE 
        WHEN latitude IS NOT NULL AND longitude IS NOT NULL 
             AND speed_kmh IS NOT NULL AND fuel_level IS NOT NULL 
        THEN 1.0
        WHEN (latitude IS NULL OR longitude IS NULL) AND speed_kmh IS NOT NULL 
        THEN 0.7
        ELSE 0.3
      END) as data_quality_score,
    
    -- Location validation (use existing validation)
    COALESCE(location_valid, 
      (latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180)) as location_valid,
    
    -- Metadata
    device_type as source_system,
    'default_tenant' as tenant_id,  -- Default tenant for Phase 1 data
    COALESCE(processed_at, CURRENT_TIMESTAMP()) as processed_at
    
  FROM `intelligent_dataops_analytics.iot_telemetry`
  WHERE DATE(timestamp) = process_date
    AND timestamp IS NOT NULL
    AND vehicle_id IS NOT NULL
  LIMIT batch_size;
  
  -- Join with dimension tables to get surrogate keys
  INSERT INTO `intelligent_dataops_analytics.iot_telemetry_fact` (
    event_date,
    event_timestamp,
    latitude,
    longitude,
    location_accuracy,
    vehicle_key,
    speed_kmh,
    fuel_level_percent,
    engine_status,
    odometer_km,
    engine_temperature,
    driver_key,
    route_key,
    data_quality_score,
    location_valid,
    source_system,
    processed_at,
    tenant_id
  )
  SELECT 
    s.event_date,
    s.event_timestamp,
    s.latitude,
    s.longitude,
    s.location_accuracy,
    COALESCE(v.vehicle_key, GENERATE_UUID()) as vehicle_key,
    s.speed_kmh,
    s.fuel_level_percent,
    s.engine_status,
    s.odometer_km,
    s.engine_temperature,
    d.driver_key,
    r.route_key,
    s.data_quality_score,
    s.location_valid,
    s.source_system,
    s.processed_at,
    s.tenant_id
  FROM telemetry_staging s
  LEFT JOIN `intelligent_dataops_analytics.vehicle_dim` v 
    ON s.vehicle_id = v.vehicle_id 
    AND v.is_current = TRUE
    AND s.tenant_id = v.tenant_id
  LEFT JOIN `intelligent_dataops_analytics.driver_dim` d 
    ON s.driver_id = d.driver_id 
    AND d.is_current = TRUE
    AND s.tenant_id = d.tenant_id
  LEFT JOIN `intelligent_dataops_analytics.route_dim` r 
    ON s.route_id = r.route_id 
    AND r.is_active = TRUE
    AND s.tenant_id = r.tenant_id;
  
  -- Get row count for logging
  SET rows_processed = (SELECT COUNT(*) FROM telemetry_staging);
  SET end_time = CURRENT_TIMESTAMP();
  
  -- Log processing statistics
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
    created_at
  )
  VALUES (
    GENERATE_UUID(),
    'sp_load_iot_telemetry',
    process_date,
    start_time,
    end_time,
    rows_processed,
    TIMESTAMP_DIFF(end_time, start_time, SECOND),
    'SUCCESS',
    'SYSTEM',
    CURRENT_TIMESTAMP()
  );
  
  -- Clean up staging table
  DROP TABLE telemetry_staging;
  
  -- Return processing summary
  SELECT 
    'sp_load_iot_telemetry' as procedure_name,
    process_date,
    rows_processed,
    TIMESTAMP_DIFF(end_time, start_time, SECOND) as processing_duration_seconds,
    'SUCCESS' as status;
    
END;