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

# Blue-Green Node Pool Variables
variable "node_pool_new_machine_type" {
  description = "Machine types for the new node pool (blue-green migration)"
  type        = list(string)
  default     = []
}

variable "node_pool_new_desired_size" {
  description = "Desired number of nodes in the new node pool"
  type        = number
  default     = 0
}

variable "node_pool_new_min_size" {
  description = "Minimum number of nodes in the new node pool"
  type        = number
  default     = 0
}

variable "node_pool_new_max_size" {
  description = "Maximum number of nodes in the new node pool"
  type        = number
  default     = 25
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

variable "enable_argocd_access" {
  description = "Enable ArgoCD access from GitOps cluster"
  type        = bool
  default     = false
}

variable "gitops_cluster_name" {
  description = "Name of the GitOps cluster for ArgoCD access"
  type        = string
  default     = ""
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

variable "network" {
  description = "VPC network name where GKE resources are created"
  type        = string
}

variable "subnetwork" {
  description = "Subnetwork name for the GKE control plane and node pools"
  type        = string
}

