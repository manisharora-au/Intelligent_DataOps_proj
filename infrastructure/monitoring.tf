# Monitoring and Logging Configuration
# Cost-optimized monitoring setup

# Log sink for cost monitoring
resource "google_logging_project_sink" "cost_monitoring" {
  name        = "cost-monitoring-sink"
  destination = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${google_bigquery_dataset.analytics.dataset_id}"
  
  # Filter for billing and cost-related logs
  filter = <<EOF
    resource.type="billing_account" OR
    resource.type="gce_instance" OR
    resource.type="cloud_function" OR
    resource.type="dataflow_job" OR
    protoPayload.methodName="storage.objects.create" OR
    protoPayload.methodName="storage.objects.delete"
  EOF
  
  # Create BigQuery dataset if it doesn't exist
  unique_writer_identity = true
}

# Basic monitoring dashboard for cost tracking
resource "google_monitoring_dashboard" "cost_overview" {
  dashboard_json = jsonencode({
    displayName = "Intelligent DataOps - Cost Overview"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          xPos = 0
          yPos = 0
          width = 6
          height = 4
          widget = {
            title = "Storage Usage"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"storage.googleapis.com/storage/total_bytes\" AND resource.type=\"gcs_bucket\""
                    aggregation = {
                      alignmentPeriod = "3600s"
                      perSeriesAligner = "ALIGN_MEAN"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          xPos = 6
          yPos = 0
          width = 6
          height = 4  
          widget = {
            title = "Pub/Sub Messages"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"pubsub.googleapis.com/topic/send_message_operation_count\" AND resource.type=\"pubsub_topic\""
                    aggregation = {
                      alignmentPeriod = "3600s"
                      perSeriesAligner = "ALIGN_RATE"
                    }
                  }
                }
              }]
            }
          }
        }
      ]
    }
  })
}

# Alert policy for high storage usage
resource "google_monitoring_alert_policy" "storage_alert" {
  display_name = "High Storage Usage Alert"
  combiner     = "OR"
  
  conditions {
    display_name = "Storage Usage Threshold"
    
    condition_threshold {
      filter         = "metric.type=\"storage.googleapis.com/storage/total_bytes\" AND resource.type=\"gcs_bucket\""
      duration       = "300s"
      comparison     = "COMPARISON_GT"
      threshold_value = 1000000000  # 1GB threshold
      
      aggregations {
        alignment_period   = "3600s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }
  
  notification_channels = []
  
  alert_strategy {
    auto_close = "1800s"
  }
}

# Simple Pub/Sub message count alert (working alternative)
resource "google_monitoring_alert_policy" "pubsub_alert" {
  display_name = "High Pub/Sub Message Volume Alert"
  combiner     = "OR"
  
  conditions {
    display_name = "Message Volume Threshold"
    
    condition_threshold {
      filter         = "metric.type=\"pubsub.googleapis.com/topic/send_message_operation_count\" AND resource.type=\"pubsub_topic\""
      duration       = "300s"
      comparison     = "COMPARISON_GT"
      threshold_value = 1000  # Alert if more than 1000 messages in 5 minutes
      
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }
  
  notification_channels = []
  
  alert_strategy {
    auto_close = "3600s"
  }
}