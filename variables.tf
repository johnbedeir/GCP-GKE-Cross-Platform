###
# Declare all variables, without values, environment specific values are loaded later.
###

###
# Region related settings.
###

variable "project_id" {
  description = "The GCP Project ID."
  type        = string
}

variable "region" {
  description = "The GCP region to work in."
  type        = string
}

variable "az_primary" {
  description = "The primary availability zone to use."
  type        = string
}

variable "az_secondary" {
  description = "The secondary availability zone to use."
  type        = string
}

###
# IP settings. (ranges)
###

variable "vpc_cidr" {
  description = "VPC IP Range in CIDR notation."
  type        = string
}

###
# Budget tag values.
###

variable "networking_budget" {
  description = "Value for the Budget label for networking resources."
  type        = string
}

variable "proc_budget" {
  description = "Value for the Budget label for processing resources."
  type        = string
}

###
# Other tag values
###

variable "env_tag" {
  description = "Value of the env tag, probably 'prod' or 'dev'."
  type        = string
}

variable "replicated_region" {
  description = "The GCP region used for replication."
  type        = string
}

###
# Things that make other things pretty.
###

variable "name_region" {
  description = "The name of the region. Used to name things. eg: us-east-1"
  type        = string
}

####################################################################################################
###                                                                                              ###
###                                       GKE VARIABLES                                          ###
###                                                                                              ###
####################################################################################################

variable "name_prefix" {
  description = "The prefix for the name of the GKE cluster."
  type        = string
}

variable "environment" {
  description = "The environment for the GKE cluster."
  type        = string
}

variable "admin_users" {
  type        = list(string)
  description = "List of Kubernetes admins (GCP user emails)."
}

variable "gke_version" {
  description = "The version of the GKE cluster."
  type        = string
}

# Blue-Green Node Pool Variables
variable "node_pool_new_machine_type" {
  description = "Machine types for the new node pool (blue-green migration)"
  type        = list(string)
}

variable "node_pool_new_desired_size" {
  description = "Desired number of nodes in the new node pool"
  type        = number
}

variable "node_pool_new_min_size" {
  description = "Minimum number of nodes in the new node pool"
  type        = number
}

variable "node_pool_new_max_size" {
  description = "Maximum number of nodes in the new node pool"
  type        = number
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "datadog_api_secret_name" {
  description = "The name of the Datadog API key secret in GCP Secret Manager."
  type        = string
}

variable "datadog_api_key_value" {
  description = "The Datadog API key value (will be stored in GCP Secret Manager)."
  type        = string
  sensitive   = true
}

# GitOps GKE Cluster Variables
variable "gitops_name_prefix" {
  description = "Name prefix for the GitOps GKE cluster"
  type        = string
}

variable "gitops_environment" {
  description = "Environment name for the GitOps GKE cluster"
  type        = string
}

variable "gitops_cluster_name" {
  description = "Name of the GitOps GKE cluster"
  type        = string
}

variable "gitops_gke_version" {
  description = "Kubernetes version for the GitOps GKE cluster"
  type        = string
}

variable "gitops_admin_users" {
  description = "List of admin users for the GitOps GKE cluster (GCP user emails)"
  type        = list(string)
}

variable "gitops_node_pool_machine_type" {
  description = "Machine types for the GitOps GKE node pool"
  type        = list(string)
}

variable "gitops_node_pool_desired_size" {
  description = "Desired size of the GitOps GKE node pool"
  type        = number
}

variable "gitops_node_pool_min_size" {
  description = "Minimum size of the GitOps GKE node pool"
  type        = number
}

variable "gitops_node_pool_max_size" {
  description = "Maximum size of the GitOps GKE node pool"
  type        = number
}

variable "gitops_datadog_api_secret_name" {
  description = "The name of the Datadog API key secret for GitOps cluster in GCP Secret Manager."
  type        = string
}

variable "gitops_datadog_api_key_value" {
  description = "The Datadog API key value for GitOps cluster (will be stored in GCP Secret Manager)."
  type        = string
  sensitive   = true
}

# GKE Production Subnet Variables
variable "private_gke_prod_subnets" {
  description = "List of IP ranges for GKE production subnets in CIDR notation."
  type        = list(string)
}

# GKE GitOps Management Subnet Variables
variable "private_gke_gitops_subnets" {
  description = "List of IP ranges for GKE GitOps management subnets in CIDR notation."
  type        = list(string)
}

# Public Subnet Variables
variable "public_subnets" {
  description = "List of IP ranges for public subnets in CIDR notation."
  type        = list(string)
}

