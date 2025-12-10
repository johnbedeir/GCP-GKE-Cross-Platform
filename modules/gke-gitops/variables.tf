####################################################################################################
###                                                                                              ###
###                                     GKE MODULE VARIABLES                                     ###
###                                                                                              ###
####################################################################################################

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "gke_version" {
  description = "Kubernetes version for the GKE cluster"
  type        = string
}

variable "region" {
  description = "GCP region (used by autoscaler and other components)"
  type        = string
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "network_cidr" {
  description = "CIDR block of the VPC network (used for firewall rules)"
  type        = string
}

variable "node_pool_machine_type" {
  description = "Machine type for the node pool"
  type        = list(string)
}

variable "node_pool_desired_size" {
  description = "Desired number of nodes in the node pool"
  type        = number
}

variable "node_pool_min_size" {
  description = "Minimum number of nodes in the node pool"
  type        = number
}

variable "node_pool_max_size" {
  description = "Maximum number of nodes in the node pool"
  type        = number
}

variable "admin_users" {
  description = "GCP user emails to grant cluster-admin access (system:masters)"
  type        = list(string)
  default     = []
}

variable "proc_budget" {
  description = "Budget label value to apply across GKE resources"
  type        = string
}

variable "datadog_api_secret_name" {
  description = "Name of the Secret in GCP Secret Manager for the Datadog API key"
  type        = string
}

variable "enable_rbac_config" {
  description = "Whether to manage RBAC configuration via Terraform"
  type        = bool
  default     = false
}

variable "enable_metrics_server" {
  description = "Whether to install Metrics Server via Helm"
  type        = bool
  default     = false
}

variable "enable_datadog" {
  description = "Whether to install Datadog agent via Helm"
  type        = bool
  default     = false
}

variable "enable_cluster_autoscaler" {
  description = "Whether to enable Cluster Autoscaler (GKE native)"
  type        = bool
  default     = false
}

variable "enable_chartmuseum" {
  description = "Whether to install ChartMuseum via Helm"
  type        = bool
  default     = false
}

variable "chartmuseum_storage_size" {
  description = "Size of the persistent volume for ChartMuseum storage"
  type        = string
  default     = "8Gi"
}

variable "chartmuseum_storage_class" {
  description = "Storage class for ChartMuseum persistent volume"
  type        = string
  default     = "standard"
}

variable "enable_argocd" {
  description = "Whether to install ArgoCD via Helm"
  type        = bool
  default     = false
}

variable "network" {
  description = "VPC network name where GKE resources are created"
  type        = string
}

variable "subnetwork" {
  description = "Subnetwork name for the GKE control plane and node pools"
  type        = string
}

variable "public_subnetwork" {
  description = "Public subnetwork name for internet-facing LoadBalancers"
  type        = string
  default     = ""
}

# Cross-cluster communication variables
variable "target_cluster_name" {
  description = "Name of the target cluster that this GitOps cluster will manage"
  type        = string
  default     = ""
}

variable "target_cluster_endpoint" {
  description = "Endpoint of the target cluster for cross-cluster communication"
  type        = string
  default     = ""
}

variable "target_cluster_ca_data" {
  description = "Certificate authority data of the target cluster"
  type        = string
  default     = ""
}

variable "target_cluster_location" {
  description = "Location (region) of the target cluster"
  type        = string
  default     = ""
}

variable "target_cluster_project_id" {
  description = "GCP Project ID of the target cluster"
  type        = string
  default     = ""
}

