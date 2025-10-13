-- =============================================================================
-- BigQuery ETL Processing Log Table Creation
-- =============================================================================
-- Purpose: Create table to track all ETL procedure executions and performance
-- Usage: Source this before using any stored procedures
-- =============================================================================

CREATE OR REPLACE TABLE `intelligent_dataops_analytics.etl_processing_log` (
  -- Identification
  log_id STRING NOT NULL OPTIONS(description="Unique log entry identifier"),
  procedure_name STRING NOT NULL OPTIONS(description="Name of executed stored procedure"),
  process_date DATE OPTIONS(description="Business date being processed"),
  
  -- Execution timing
  start_time TIMESTAMP NOT NULL OPTIONS(description="Procedure execution start time"),
  end_time TIMESTAMP NOT NULL OPTIONS(description="Procedure execution end time"),
  processing_duration_seconds INT64 OPTIONS(description="Total processing time in seconds"),
  
  -- Processing metrics
  rows_processed INT64 OPTIONS(description="Number of rows processed"),
  rows_inserted INT64 OPTIONS(description="Number of rows inserted"),
  rows_updated INT64 OPTIONS(description="Number of rows updated"),
  rows_deleted INT64 OPTIONS(description="Number of rows deleted"),
  
  -- Status and error handling
  status STRING NOT NULL OPTIONS(description="Execution status: SUCCESS, FAILED, WARNING"),
  error_message STRING OPTIONS(description="Error message if procedure failed"),
  warning_message STRING OPTIONS(description="Warning message if applicable"),
  
  -- Context and metadata
  tenant_id STRING OPTIONS(description="Multi-tenant isolation key"),
  user_id STRING OPTIONS(description="User who initiated the procedure"),
  session_id STRING OPTIONS(description="Session identifier for grouping related calls"),
  
  -- Additional information
  additional_info JSON OPTIONS(description="Additional procedure-specific information"),
  
  -- Resource usage (for monitoring and optimization)
  bytes_processed INT64 OPTIONS(description="Bytes processed by the procedure"),
  slot_milliseconds INT64 OPTIONS(description="BigQuery slot milliseconds consumed"),
  
  -- Audit fields
  created_at TIMESTAMP NOT NULL OPTIONS(description="Log entry creation timestamp")
)
PARTITION BY DATE(start_time)
CLUSTER BY procedure_name, status, tenant_id
OPTIONS (
  description="ETL procedure execution log for monitoring and troubleshooting",
  partition_expiration_days=365,  -- 1 year retention for logs
  labels=[("environment", "production"), ("data_type", "etl_log")]
);

-- =============================================================================
-- Create supporting views for monitoring
-- =============================================================================

-- View for current day ETL status
CREATE OR REPLACE VIEW `intelligent_dataops_analytics.etl_status_today` AS
SELECT 
  procedure_name,
  COUNT(*) as executions_today,
  SUM(rows_processed) as total_rows_processed,
  AVG(processing_duration_seconds) as avg_duration_seconds,
  MAX(processing_duration_seconds) as max_duration_seconds,
  SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) as successful_runs,
  SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) as failed_runs,
  MAX(end_time) as last_execution_time
FROM `intelligent_dataops_analytics.etl_processing_log`
WHERE DATE(start_time) = CURRENT_DATE()
GROUP BY procedure_name
ORDER BY last_execution_time DESC;

-- View for ETL performance trends
CREATE OR REPLACE VIEW `intelligent_dataops_analytics.etl_performance_trend` AS
SELECT 
  procedure_name,
  DATE(start_time) as execution_date,
  COUNT(*) as daily_executions,
  AVG(processing_duration_seconds) as avg_duration_seconds,
  AVG(rows_processed) as avg_rows_processed,
  SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) / COUNT(*) as failure_rate
FROM `intelligent_dataops_analytics.etl_processing_log`
WHERE DATE(start_time) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY procedure_name, DATE(start_time)
ORDER BY execution_date DESC, procedure_name;

-- View for error monitoring
CREATE OR REPLACE VIEW `intelligent_dataops_analytics.etl_errors_recent` AS
SELECT 
  procedure_name,
  process_date,
  start_time,
  processing_duration_seconds,
  rows_processed,
  error_message,
  warning_message,
  additional_info,
  tenant_id
FROM `intelligent_dataops_analytics.etl_processing_log`
WHERE status IN ('FAILED', 'WARNING')
  AND DATE(start_time) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
ORDER BY start_time DESC;

-- ✅ ETL logging infrastructure created successfully!
-- 📊 Tables and views created:
--   - etl_processing_log (main log table)
--   - etl_status_today (current day status view)
--   - etl_performance_trend (30-day performance trends)
--   - etl_errors_recent (recent errors and warnings)
--
-- 🔍 Ready for ETL procedure monitoring and troubleshooting