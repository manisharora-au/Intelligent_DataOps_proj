# Intelligent DataOps Platform - Phase 1 Infrastructure
# Cost-optimized setup for $100/month budget

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Configure the Google Cloud Provider with Service Account
provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}

# Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "manish-sandpit"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"  # Cost-effective region
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "credentials_file" {
  description = "Path to the service account credentials JSON file"
  type        = string
  default     = "~/.gcp/credentials/terraform-dataops-key.json"
}

# Local values
locals {
  labels = {
    environment = var.environment
    project     = "intelligent-dataops"
    phase       = "1-foundation"
    cost_center = "learning"
  }
}