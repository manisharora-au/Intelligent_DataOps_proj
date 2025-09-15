# Pub/Sub Topics and Subscriptions
# Cost-optimized with retention policies

# IoT Telemetry Data Topic
resource "google_pubsub_topic" "iot_telemetry" {
  name = "iot-telemetry"
  
  labels = local.labels
  
  # Retention policy to control costs
  message_retention_duration = "604800s"  # 7 days
}

resource "google_pubsub_subscription" "iot_telemetry_sub" {
  name  = "iot-telemetry-subscription"
  topic = google_pubsub_topic.iot_telemetry.name
  
  labels = local.labels
  
  # Cost optimization settings
  message_retention_duration = "604800s"  # 7 days
  ack_deadline_seconds       = 20
  
  # Dead letter policy for failed messages
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 5
  }
  
  # Retry policy
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }
}

# Supplier Updates Topic
resource "google_pubsub_topic" "supplier_updates" {
  name = "supplier-updates"
  
  labels = local.labels
  
  message_retention_duration = "604800s"  # 7 days
}

resource "google_pubsub_subscription" "supplier_updates_sub" {
  name  = "supplier-updates-subscription"
  topic = google_pubsub_topic.supplier_updates.name
  
  labels = local.labels
  
  message_retention_duration = "604800s"
  ack_deadline_seconds       = 20
  
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 5
  }
}

# Delivery Events Topic
resource "google_pubsub_topic" "delivery_events" {
  name = "delivery-events"
  
  labels = local.labels
  
  message_retention_duration = "604800s"  # 7 days
}

resource "google_pubsub_subscription" "delivery_events_sub" {
  name  = "delivery-events-subscription"
  topic = google_pubsub_topic.delivery_events.name
  
  labels = local.labels
  
  message_retention_duration = "604800s"
  ack_deadline_seconds       = 20
  
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 5
  }
}

# System Alerts Topic
resource "google_pubsub_topic" "system_alerts" {
  name = "system-alerts"
  
  labels = local.labels
  
  message_retention_duration = "259200s"  # 3 days (shorter for alerts)
}

resource "google_pubsub_subscription" "system_alerts_sub" {
  name  = "system-alerts-subscription"
  topic = google_pubsub_topic.system_alerts.name
  
  labels = local.labels
  
  message_retention_duration = "259200s"
  ack_deadline_seconds       = 10  # Faster processing for alerts
}

# Dead Letter Topic (for failed messages)
resource "google_pubsub_topic" "dead_letter" {
  name = "dead-letter"
  
  labels = local.labels
  
  # Shorter retention for dead letters
  message_retention_duration = "259200s"  # 3 days
}

resource "google_pubsub_subscription" "dead_letter_sub" {
  name  = "dead-letter-subscription"
  topic = google_pubsub_topic.dead_letter.name
  
  labels = local.labels
  
  message_retention_duration = "259200s"
  ack_deadline_seconds       = 600  # Longer for manual review
}