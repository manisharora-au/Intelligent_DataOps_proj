# BigQuery Datasets and Tables
# Cost-optimized with partitioning and clustering

# Main analytics dataset
resource "google_bigquery_dataset" "analytics" {
  dataset_id  = "intelligent_dataops_analytics"
  location    = var.region
  description = "Main analytics dataset for intelligent dataops platform"
  
  labels = local.labels
  
  # Cost control settings
  default_table_expiration_ms = 7776000000  # 90 days default expiration
  # Access control in BigQuery datasets is managed using the `access` block.
  # This block specifies who can access the dataset and with what role.
  # Common roles include OWNER, WRITER, and READER, and access can be granted to users, groups, domains, or special groups.
  # Example:
  # access {
  #   role          = "READER"
  #   user_by_email = "user@example.com"
  # }
  # Access control - use your actual email or remove this block
  # access {
  #   role          = "OWNER"
  #   user_by_email = "your-email@domain.com"
  # }
}

# Real-time operational dataset  
resource "google_bigquery_dataset" "realtime" {
  dataset_id  = "intelligent_dataops_realtime" 
  location    = var.region
  description = "Real-time operational data"
  # `local.labels` is a local value (usually defined in a `locals` block elsewhere in your Terraform configuration)
  # that contains a map of labels (key-value pairs) to be applied to resources for organization, cost tracking, or identification.
  # Example definition (typically in locals.tf or at the top of a .tf file):
  # locals {
  #   labels = {
  #     environment = var.environment
  #     project     = var.project
  #     owner       = "dataops-team"
  #   }
  # }
  labels = local.labels
  
  # Shorter retention for real-time data
  default_table_expiration_ms = 2592000000  # 30 days
}

# IoT telemetry table (partitioned for cost optimization)
resource "google_bigquery_table" "iot_telemetry" {
  dataset_id = google_bigquery_dataset.analytics.dataset_id
  table_id   = "iot_telemetry"
  
  labels = local.labels
  
  # Partition by date for cost optimization
  time_partitioning {
    type  = "DAY"
    field = "timestamp"
  }
  
  # Cluster for query performance
  clustering = ["vehicle_id", "device_type"]
  
  schema = jsonencode([
    {
      name        = "timestamp"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "Event timestamp"
    },
    {
      name        = "vehicle_id"
      type        = "STRING"
      mode        = "REQUIRED" 
      description = "Vehicle identifier"
    },
    {
      name        = "device_type"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "IoT device type"
    },
    {
      name        = "latitude"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "GPS latitude"
    },
    {
      name        = "longitude"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "GPS longitude" 
    },
    {
      name        = "speed_kmh"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Vehicle speed in km/h"
    },
    {
      name        = "fuel_level"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Fuel level percentage"
    },
    {
      name        = "engine_status"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Engine status"
    },
    {
      name        = "raw_data"
      type        = "JSON"
      mode        = "NULLABLE"
      description = "Raw telemetry data"
    }
  ])
}

# Deliveries table
resource "google_bigquery_table" "deliveries" {
  dataset_id = google_bigquery_dataset.analytics.dataset_id
  table_id   = "deliveries"
  
  labels = local.labels
  
  # Partition by delivery date
  time_partitioning {
    type  = "DAY"
    field = "scheduled_delivery_date"
  }
  
  # Cluster for common query patterns
  clustering = ["status", "route_id"]
  
  schema = jsonencode([
    {
      name        = "delivery_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Unique delivery identifier"
    },
    {
      name        = "customer_id" 
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Customer identifier"
    },
    {
      name        = "vehicle_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Assigned vehicle"
    },
    {
      name        = "route_id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Delivery route identifier"
    },
    {
      name        = "status"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Delivery status"
    },
    {
      name        = "scheduled_delivery_date"
      type        = "DATE"
      mode        = "REQUIRED"
      description = "Scheduled delivery date"
    },
    {
      name        = "estimated_delivery_time"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "Estimated delivery time"
    },
    {
      name        = "actual_delivery_time"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "Actual delivery time"
    },
    {
      name        = "pickup_location"
      type        = "GEOGRAPHY"
      mode        = "NULLABLE"
      description = "Pickup location coordinates"
    },
    {
      name        = "delivery_location"
      type        = "GEOGRAPHY"
      mode        = "NULLABLE"
      description = "Delivery location coordinates"
    },
    {
      name        = "priority"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Delivery priority level"
    }
  ])
}

# Vehicles table
resource "google_bigquery_table" "vehicles" {
  dataset_id = google_bigquery_dataset.analytics.dataset_id
  table_id   = "vehicles"
  
  labels = local.labels
  
  # No partitioning needed for relatively static vehicle data
  clustering = ["fleet_id", "vehicle_type"]
  
  schema = jsonencode([
    {
      name        = "vehicle_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Unique vehicle identifier"
    },
    {
      name        = "fleet_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Fleet identifier"
    },
    {
      name        = "vehicle_type"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Vehicle type (truck, van, etc.)"
    },
    {
      name        = "make_model"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Vehicle make and model"
    },
    {
      name        = "capacity_kg"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Cargo capacity in kg"
    },
    {
      name        = "fuel_type"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Fuel type"
    },
    {
      name        = "driver_id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Assigned driver ID"
    },
    {
      name        = "status"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Vehicle status"
    },
    {
      name        = "last_maintenance_date"
      type        = "DATE"
      mode        = "NULLABLE"
      description = "Last maintenance date"
    }
  ])
}

# Data source for current user (commented out - not needed without access block)
# data "google_client_config" "default" {}