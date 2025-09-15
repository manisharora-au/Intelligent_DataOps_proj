# Terraform Outputs
# Display important resource information

output "project_info" {
  description = "Project configuration"
  value = {
    project_id = var.project_id
    region     = var.region
    zone       = var.zone
    environment = var.environment
  }
}

output "storage_buckets" {
  description = "Created storage buckets"
  value = {
    raw_data_lake  = google_storage_bucket.raw_data_lake.url
    processed_data = google_storage_bucket.processed_data.url
    dataflow_temp  = google_storage_bucket.dataflow_temp.url
  }
}

output "pubsub_topics" {
  description = "Created Pub/Sub topics"
  value = {
    iot_telemetry    = google_pubsub_topic.iot_telemetry.name
    supplier_updates = google_pubsub_topic.supplier_updates.name
    delivery_events  = google_pubsub_topic.delivery_events.name
    system_alerts    = google_pubsub_topic.system_alerts.name
    dead_letter      = google_pubsub_topic.dead_letter.name
  }
}

output "pubsub_subscriptions" {
  description = "Created Pub/Sub subscriptions"
  value = {
    iot_telemetry    = google_pubsub_subscription.iot_telemetry_sub.name
    supplier_updates = google_pubsub_subscription.supplier_updates_sub.name
    delivery_events  = google_pubsub_subscription.delivery_events_sub.name
    system_alerts    = google_pubsub_subscription.system_alerts_sub.name
    dead_letter      = google_pubsub_subscription.dead_letter_sub.name
  }
}

output "bigquery_datasets" {
  description = "Created BigQuery datasets"
  value = {
    analytics = google_bigquery_dataset.analytics.dataset_id
    realtime  = google_bigquery_dataset.realtime.dataset_id
  }
}

output "bigquery_tables" {
  description = "Created BigQuery tables"
  value = {
    iot_telemetry = "${google_bigquery_dataset.analytics.dataset_id}.${google_bigquery_table.iot_telemetry.table_id}"
    deliveries    = "${google_bigquery_dataset.analytics.dataset_id}.${google_bigquery_table.deliveries.table_id}"
    vehicles      = "${google_bigquery_dataset.analytics.dataset_id}.${google_bigquery_table.vehicles.table_id}"
  }
}

output "monitoring_resources" {
  description = "Monitoring and alerting resources"
  value = {
    cost_dashboard = google_monitoring_dashboard.cost_overview.id
    storage_alert  = google_monitoring_alert_policy.storage_alert.name
    pubsub_alert   = google_monitoring_alert_policy.pubsub_alert.name
  }
}

output "estimated_monthly_cost" {
  description = "Estimated monthly costs (USD)"
  value = {
    storage_standard = "~$5-10 (depends on data volume)"
    pubsub          = "~$2-5 (first 10GB free)" 
    bigquery        = "~$5-15 (depends on queries)"
    monitoring      = "~$1-3"
    total_estimated = "~$13-33/month for Phase 1"
    budget_limit    = "$100/month"
  }
}

output "next_steps" {
  description = "Next steps after infrastructure deployment"
  value = [
    "1. Verify all resources are created successfully",
    "2. Test Pub/Sub message publishing and consumption",
    "3. Load sample data into BigQuery tables",
    "4. Set up basic Dataflow pipeline",
    "5. Configure monitoring dashboards",
    "6. Proceed to Phase 2: Data Processing & ML Models"
  ]
}