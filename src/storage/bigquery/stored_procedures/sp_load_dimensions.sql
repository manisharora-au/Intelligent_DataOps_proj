-- =============================================================================
-- BigQuery Stored Procedure - Load Dimension Tables
-- =============================================================================
-- Purpose: Transform and load operational data into dimension tables with SCD Type 2
-- Usage: CALL `intelligent_dataops_analytics.sp_load_dimensions`();
-- =============================================================================

CREATE OR REPLACE PROCEDURE `intelligent_dataops_analytics.sp_load_dimensions`()
BEGIN
  DECLARE start_time TIMESTAMP;
  DECLARE vehicles_processed INT64;
  DECLARE drivers_processed INT64;
  DECLARE routes_processed INT64;
  DECLARE customers_processed INT64;
  DECLARE locations_processed INT64;
  
  SET start_time = CURRENT_TIMESTAMP();
  
  -- =============================================================================
  -- Load Vehicle Dimension with SCD Type 2
  -- =============================================================================
  
  -- Close existing records that have changed
  UPDATE `intelligent_dataops_analytics.vehicle_dim` 
  SET 
    effective_to_date = CURRENT_DATE(),
    is_current = FALSE,
    updated_at = CURRENT_TIMESTAMP(),
    change_reason = 'Data updated in source system'
  WHERE vehicle_id IN (
    SELECT DISTINCT v.vehicle_id 
    FROM `intelligent_dataops_analytics.vehicles` v
    INNER JOIN `intelligent_dataops_analytics.vehicle_dim` vd 
      ON v.vehicle_id = vd.vehicle_id AND vd.is_current = TRUE
    WHERE 
      v.status != vd.current_status OR
      v.driver_id != vd.assigned_driver_id OR  -- Simplified comparison
      v.last_maintenance_date != vd.last_maintenance_date
  )
  AND is_current = TRUE;
  
  -- Insert new and changed records
  INSERT INTO `intelligent_dataops_analytics.vehicle_dim` (
    vehicle_key,
    vehicle_id,
    make,
    model,
    year,
    vin,
    license_plate,
    engine_type,
    transmission_type,
    max_capacity_kg,
    fuel_tank_capacity_liters,
    fuel_efficiency_rating,
    acquisition_date,
    acquisition_cost_usd,
    current_status,
    home_depot_key,
    assigned_region,
    fleet_group,
    monthly_depreciation_usd,
    insurance_cost_monthly_usd,
    registration_expiry_date,
    effective_from_date,
    effective_to_date,
    is_current,
    change_reason,
    tenant_id,
    created_at,
    updated_at,
    created_by
  )
  SELECT 
    GENERATE_UUID() as vehicle_key,
    v.vehicle_id,
    SPLIT(COALESCE(v.make_model, 'Unknown Make Unknown Model'), ' ')[SAFE_OFFSET(0)] as make,
    SPLIT(COALESCE(v.make_model, 'Unknown Make Unknown Model'), ' ')[SAFE_OFFSET(1)] as model,
    2020 as year,  -- Default year, to be enhanced
    CONCAT('VIN', v.vehicle_id) as vin,  -- Generated VIN
    CONCAT('LP-', v.vehicle_id) as license_plate,  -- Generated license plate
    COALESCE(v.fuel_type, 'diesel') as engine_type,
    'automatic' as transmission_type,  -- Default assumption
    COALESCE(v.capacity_kg, 1000) as max_capacity_kg,
    CASE 
      WHEN v.fuel_type = 'diesel' THEN 80.0
      WHEN v.fuel_type = 'gasoline' THEN 60.0
      ELSE 50.0
    END as fuel_tank_capacity_liters,
    12.0 as fuel_efficiency_rating,  -- Default baseline
    DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR) as acquisition_date,  -- Default 2 years ago
    35000.00 as acquisition_cost_usd,  -- Default cost
    v.status as current_status,
    v.fleet_id as home_depot_key,  -- Using fleet_id as depot reference
    'Region_A' as assigned_region,  -- Default region
    v.fleet_id as fleet_group,
    450.00 as monthly_depreciation_usd,  -- Default depreciation
    250.00 as insurance_cost_monthly_usd,  -- Default insurance
    DATE_ADD(CURRENT_DATE(), INTERVAL 1 YEAR) as registration_expiry_date,
    CURRENT_DATE() as effective_from_date,
    NULL as effective_to_date,
    TRUE as is_current,
    'Initial load from operational system' as change_reason,
    'default_tenant' as tenant_id,
    CURRENT_TIMESTAMP() as created_at,
    CURRENT_TIMESTAMP() as updated_at,
    'sp_load_dimensions' as created_by
  FROM `intelligent_dataops_analytics.vehicles` v
  WHERE NOT EXISTS (
    SELECT 1 FROM `intelligent_dataops_analytics.vehicle_dim` vd 
    WHERE vd.vehicle_id = v.vehicle_id AND vd.is_current = TRUE
  )
  OR EXISTS (
    SELECT 1 FROM `intelligent_dataops_analytics.vehicle_dim` vd 
    WHERE vd.vehicle_id = v.vehicle_id AND vd.is_current = FALSE
      AND vd.effective_to_date = CURRENT_DATE()
  );
  
  SET vehicles_processed = @@row_count;
  
  -- =============================================================================
  -- Load Driver Dimension (Extract from telemetry data)
  -- =============================================================================
  
  -- Extract unique drivers from telemetry data and create dimension records
  INSERT INTO `intelligent_dataops_analytics.driver_dim` (
    driver_key,
    driver_id,
    driver_code,
    hire_date,
    employment_type,
    license_class,
    license_number_hash,
    license_issue_date,
    license_expiry_date,
    safety_certifications,
    experience_years,
    safety_score_baseline,
    training_completion_date,
    home_depot_key,
    supervisor_key,
    team_assignment,
    employment_status,
    pay_grade,
    performance_tier,
    contact_phone_hash,
    emergency_contact_hash,
    effective_from_date,
    effective_to_date,
    is_current,
    change_reason,
    tenant_id,
    created_at,
    updated_at,
    created_by
  )
  SELECT 
    GENERATE_UUID() as driver_key,
    driver_id,
    CONCAT('DRV-', RIGHT(driver_id, 4)) as driver_code,
    DATE_SUB(CURRENT_DATE(), INTERVAL 1 YEAR) as hire_date,  -- Default 1 year ago
    'full_time' as employment_type,
    'CDL-A' as license_class,  -- Default commercial license
    TO_BASE64(SHA256(CONCAT('LICENSE-', driver_id))) as license_number_hash,
    DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR) as license_issue_date,
    DATE_ADD(CURRENT_DATE(), INTERVAL 3 YEAR) as license_expiry_date,
    ['Safety Training', 'Defensive Driving'] as safety_certifications,
    CAST(RAND() * 10 + 2 AS INT64) as experience_years,  -- Random 2-12 years
    0.85 as safety_score_baseline,
    DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH) as training_completion_date,
    'DEPOT-001' as home_depot_key,  -- Default depot
    NULL as supervisor_key,
    'Team-A' as team_assignment,
    'active' as employment_status,
    'Grade-2' as pay_grade,
    'silver' as performance_tier,
    TO_BASE64(SHA256(CONCAT('PHONE-', driver_id))) as contact_phone_hash,
    TO_BASE64(SHA256(CONCAT('EMERGENCY-', driver_id))) as emergency_contact_hash,
    CURRENT_DATE() as effective_from_date,
    NULL as effective_to_date,
    TRUE as is_current,
    'Initial load from telemetry data' as change_reason,
    'default_tenant' as tenant_id,
    CURRENT_TIMESTAMP() as created_at,
    CURRENT_TIMESTAMP() as updated_at,
    'sp_load_dimensions' as created_by
  FROM (
    SELECT DISTINCT driver_id
    FROM `intelligent_dataops_analytics.iot_telemetry`
    WHERE driver_id IS NOT NULL
  ) unique_drivers
  WHERE NOT EXISTS (
    SELECT 1 FROM `intelligent_dataops_analytics.driver_dim` dd
    WHERE dd.driver_id = unique_drivers.driver_id AND dd.is_current = TRUE
  );
  
  SET drivers_processed = @@row_count;
  
  -- =============================================================================
  -- Load Route Dimension (Extract from telemetry data)
  -- =============================================================================
  
  INSERT INTO `intelligent_dataops_analytics.route_dim` (
    route_key,
    route_id,
    route_name,
    route_description,
    route_type,
    service_type,
    planned_distance_km,
    estimated_duration_minutes,
    traffic_complexity_score,
    origin_location_key,
    destination_location_key,
    waypoints,
    max_stops,
    vehicle_requirements,
    driver_skill_requirements,
    baseline_fuel_consumption_liters,
    baseline_cost_usd,
    difficulty_rating,
    primary_customer_key,
    customer_sla_minutes,
    revenue_per_stop_usd,
    effective_from_date,
    effective_to_date,
    is_active,
    seasonality_pattern,
    tenant_id,
    created_at,
    updated_at,
    created_by
  )
  SELECT 
    GENERATE_UUID() as route_key,
    route_id,
    CONCAT('Route-', route_id) as route_name,
    CONCAT('Delivery route ', route_id) as route_description,
    'delivery' as route_type,
    'standard' as service_type,
    50.0 + (CAST(RIGHT(route_id, 2) AS INT64) * 2) as planned_distance_km,  -- Estimated distance
    120 + (CAST(RIGHT(route_id, 2) AS INT64) * 5) as estimated_duration_minutes,  -- Estimated duration
    0.6 as traffic_complexity_score,
    'LOC-DEPOT' as origin_location_key,
    CONCAT('LOC-', route_id, '-END') as destination_location_key,
    [
      STRUCT(1 as sequence_number, CONCAT('LOC-', route_id, '-1') as location_key, TIME(9, 0, 0) as planned_arrival_time, 15 as estimated_duration_minutes, 'pickup' as stop_type),
      STRUCT(2 as sequence_number, CONCAT('LOC-', route_id, '-2') as location_key, TIME(10, 30, 0) as planned_arrival_time, 20 as estimated_duration_minutes, 'delivery' as stop_type)
    ] as waypoints,
    5 as max_stops,
    ['standard_truck'] as vehicle_requirements,
    ['commercial_license'] as driver_skill_requirements,
    8.0 as baseline_fuel_consumption_liters,
    85.00 as baseline_cost_usd,
    3 as difficulty_rating,
    CONCAT('CUST-', route_id) as primary_customer_key,
    240 as customer_sla_minutes,
    25.00 as revenue_per_stop_usd,
    CURRENT_DATE() as effective_from_date,
    NULL as effective_to_date,
    TRUE as is_active,
    'standard' as seasonality_pattern,
    'default_tenant' as tenant_id,
    CURRENT_TIMESTAMP() as created_at,
    CURRENT_TIMESTAMP() as updated_at,
    'sp_load_dimensions' as created_by
  FROM (
    SELECT DISTINCT route_id
    FROM `intelligent_dataops_analytics.iot_telemetry`
    WHERE route_id IS NOT NULL
  ) unique_routes
  WHERE NOT EXISTS (
    SELECT 1 FROM `intelligent_dataops_analytics.route_dim` rd
    WHERE rd.route_id = unique_routes.route_id AND rd.is_active = TRUE
  );
  
  SET routes_processed = @@row_count;
  
  -- =============================================================================
  -- Load Location Dimension (Extract GPS coordinates)
  -- =============================================================================
  
  INSERT INTO `intelligent_dataops_analytics.location_dim` (
    location_key,
    location_id,
    latitude,
    longitude,
    elevation_meters,
    street_address,
    city,
    state_province,
    postal_code,
    country,
    location_type,
    location_category,
    operating_hours,
    vehicle_access_restrictions,
    loading_dock_available,
    parking_spaces_available,
    timezone,
    region_code,
    traffic_zone,
    location_contact_phone,
    location_manager,
    is_active,
    verified_date,
    tenant_id,
    created_at,
    updated_at
  )
  SELECT 
    GENERATE_UUID() as location_key,
    CONCAT('LOC-', ROW_NUMBER() OVER (ORDER BY avg_latitude, avg_longitude)) as location_id,
    avg_latitude as latitude,
    avg_longitude as longitude,
    100.0 as elevation_meters,  -- Default elevation
    CONCAT(CAST(ROUND(avg_latitude, 3) AS STRING), ', ', CAST(ROUND(avg_longitude, 3) AS STRING)) as street_address,
    'City' as city,
    'State' as state_province,
    '12345' as postal_code,
    'USA' as country,
    'customer' as location_type,
    'commercial' as location_category,
    STRUCT(
      TIME(8, 0, 0) as monday_open, TIME(17, 0, 0) as monday_close,
      TIME(8, 0, 0) as tuesday_open, TIME(17, 0, 0) as tuesday_close,
      TIME(8, 0, 0) as wednesday_open, TIME(17, 0, 0) as wednesday_close,
      TIME(8, 0, 0) as thursday_open, TIME(17, 0, 0) as thursday_close,
      TIME(8, 0, 0) as friday_open, TIME(17, 0, 0) as friday_close,
      NULL as saturday_open, NULL as saturday_close,
      NULL as sunday_open, NULL as sunday_close
    ) as operating_hours,
    ['truck_accessible'] as vehicle_access_restrictions,
    TRUE as loading_dock_available,
    5 as parking_spaces_available,
    'America/New_York' as timezone,
    'REGION-A' as region_code,
    'ZONE-1' as traffic_zone,
    '+1-555-0100' as location_contact_phone,
    'Location Manager' as location_manager,
    TRUE as is_active,
    CURRENT_DATE() as verified_date,
    'default_tenant' as tenant_id,
    CURRENT_TIMESTAMP() as created_at,
    CURRENT_TIMESTAMP() as updated_at
  FROM (
    SELECT 
      ROUND(latitude, 3) as avg_latitude,
      ROUND(longitude, 3) as avg_longitude,
      COUNT(*) as visit_count
    FROM `intelligent_dataops_analytics.iot_telemetry`
    WHERE latitude IS NOT NULL 
      AND longitude IS NOT NULL
      AND location_valid = TRUE
    GROUP BY ROUND(latitude, 3), ROUND(longitude, 3)
    HAVING COUNT(*) >= 5  -- At least 5 visits to be considered a location
  ) frequent_locations
  WHERE NOT EXISTS (
    SELECT 1 FROM `intelligent_dataops_analytics.location_dim` ld
    WHERE ABS(ld.latitude - frequent_locations.avg_latitude) < 0.001
      AND ABS(ld.longitude - frequent_locations.avg_longitude) < 0.001
  );
  
  SET locations_processed = @@row_count;
  
  -- =============================================================================
  -- Log processing results
  -- =============================================================================
  
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
    'sp_load_dimensions',
    CURRENT_DATE(),
    start_time,
    CURRENT_TIMESTAMP(),
    vehicles_processed + drivers_processed + routes_processed + locations_processed,
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), start_time, SECOND),
    'SUCCESS',
    'SYSTEM',
    JSON_OBJECT(
      'vehicles_processed', vehicles_processed,
      'drivers_processed', drivers_processed,
      'routes_processed', routes_processed,
      'locations_processed', locations_processed
    ),
    CURRENT_TIMESTAMP()
  );
  
  SELECT 
    'sp_load_dimensions' as procedure_name,
    vehicles_processed,
    drivers_processed,
    routes_processed,
    locations_processed,
    vehicles_processed + drivers_processed + routes_processed + locations_processed as total_dimensions_processed,
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), start_time, SECOND) as processing_duration_seconds,
    'SUCCESS' as status;
    
END;