####################################################################################################
###                                                                                              ###
###                                   Terraform  Configuration                                   ###
###                                                                                              ###
####################################################################################################

terraform {
  # Latest version on the registry when I refreshed this.
  # Remember to keep modules up to date with this.
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.37.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17.0"
    }
  }
  # Terraform version requirement - supports 1.5.7 and above
  required_version = ">= 1.5.7"

  # Backend configuration removed for new project
  # To use GCS backend, uncomment and configure:
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "terraform/state"
  # }
}

####################################################################################################
###                                                                                              ###
###                                    Provider Configuration                                    ###
###                                                                                              ###
####################################################################################################

# Configure Google Cloud provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Configure Google Cloud provider for replication region (if needed)
provider "google" {
  alias   = "replication_target"
  project = var.project_id
  region  = var.replicated_region
}

# Kubernetes and Helm providers are configured inside the GKE modules
# This avoids circular dependencies where providers would need data sources
# that depend on modules that need providers

####################################################################################################
###                                                                                              ###
###                                     Misc & Data sources                                      ###
###                                                                                              ###
####################################################################################################

# Get the current GCP project
data "google_project" "current" {
  project_id = var.project_id
}

# GKE cluster data sources for external access (if needed)
# Note: These are optional and only needed if you want to access clusters from outside the modules
# The modules configure their own providers internally
data "google_container_cluster" "cluster" {
  name     = module.gke.cluster_name
  location = module.gke.cluster_location
  project  = var.project_id

  depends_on = [
    module.gke
  ]
}

data "google_container_cluster" "gitops_cluster" {
  name     = module.gke_gitops.cluster_name
  location = module.gke_gitops.cluster_location
  project  = var.project_id

  depends_on = [
    module.gke_gitops
  ]
}

####################################################################################################
###                                                                                              ###
###                                    GKE-Only Configuration                                    ###
###                                                                                              ###
###  This project is configured for GKE-only deployment. All legacy modules (IAM, CICD,        ###
###  databases, CDN, API clusters, etc.) have been removed. Only GKE production and GitOps     ###
###  clusters are managed by this Terraform configuration.                                      ###
###                                                                                              ###
####################################################################################################

