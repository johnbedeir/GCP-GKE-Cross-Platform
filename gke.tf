####################################################################################################
###                                                                                              ###
###                                       GKE MODULE                                             ###
###                                                                                              ###
####################################################################################################

# Call the GKE module using the existing subnets from subnet-gke.tf
module "gke" {
  source = "./modules/gke-prod"

  # General
  name_prefix  = var.name_prefix
  environment  = var.environment
  cluster_name = var.cluster_name
  gke_version  = var.gke_version

  # GCP account
  region     = var.region
  project_id = var.project_id

  # Networking
  network_cidr = var.vpc_cidr
  network      = google_compute_network.main.name
  # CRITICAL: Node subnets MUST match the subnets with secondary IP ranges
  # GKE requires secondary IP ranges for pods and services in VPC-native clusters
  subnetwork = google_compute_subnetwork.private_gke_prod[0].name

  # Node pool (blue-green migration support)
  node_pool_new_machine_type = var.node_pool_new_machine_type
  node_pool_new_desired_size = var.node_pool_new_desired_size
  node_pool_new_min_size     = var.node_pool_new_min_size
  node_pool_new_max_size     = var.node_pool_new_max_size

  # Auth
  admin_users = var.admin_users

  # Tags
  proc_budget = var.proc_budget

  # Datadog
  datadog_api_secret_name = var.datadog_api_secret_name
  # NOTE: Secrets must be created first. They are created in secrets.tf at the root level.

  # ArgoCD GitOps access
  # Pass the actual cluster name that matches the GitOps module's var.cluster_name
  # The GitOps module constructs cluster name as: ${name_prefix}-${environment}
  enable_argocd_access = true
  gitops_cluster_name  = "${var.gitops_name_prefix}-${var.gitops_environment}"

  # Enable optional components to match existing infrastructure
  enable_rbac_config        = true
  enable_datadog            = true
  enable_cluster_autoscaler = true
}

