# Cloud Storage Buckets with Lifecycle Management
# Cost-optimized with automatic cleanup

# Raw data lake bucket
resource "google_storage_bucket" "raw_data_lake" {
  name     = "${var.project_id}-raw-data-lake"
  location = var.region
  
  # Cost optimization settings
  storage_class = "STANDARD"
  
  # Prevent accidental deletion (remove for dev if needed)
  force_destroy = true
  
  labels = local.labels
  
  # Lifecycle management to control costs
  lifecycle_rule {
    condition {
      age = 30  # Delete after 30 days
    }
    action {
      type = "Delete"
    }
  }
  
  lifecycle_rule {
    condition {
      age = 7  # Move to nearline after 7 days
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }
  
  # Enable versioning but limit to save costs
  versioning {
    enabled = true
  }
  
  lifecycle_rule {
    condition {
      num_newer_versions = 3
    }
    action {
      type = "Delete"
    }
  }
}

# Processed data bucket
resource "google_storage_bucket" "processed_data" {
  name     = "${var.project_id}-processed-data"
  location = var.region
  
  storage_class = "STANDARD"
  force_destroy = true
  
  labels = local.labels
  
  # Shorter retention for processed data
  lifecycle_rule {
    condition {
      age = 90  # Keep processed data for 90 days
    }
    action {
      type = "Delete"
    }
  }
  
  lifecycle_rule {
    condition {
      age = 14  # Move to nearline after 14 days
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }
}

# Temporary/staging bucket for pipelines
resource "google_storage_bucket" "dataflow_temp" {
  name     = "${var.project_id}-dataflow-temp"
  location = var.region
  
  storage_class = "STANDARD"
  force_destroy = true
  
  labels = local.labels
  
  # Aggressive cleanup for temp data
  lifecycle_rule {
    condition {
      age = 1  # Delete temp files after 1 day
    }
    action {
      type = "Delete"
    }
  }
}