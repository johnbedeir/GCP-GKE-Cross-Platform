####################################################################################################
###                                                                                              ###
###                                    GKE GitOps Module                                          ###
###                                                                                              ###
####################################################################################################

# Call the GKE GitOps module using the new subnets from subnet_gke_gitops.tf
module "gke_gitops" {
  source = "./modules/gke-gitops"

  # General
  name_prefix  = var.gitops_name_prefix
  environment  = var.gitops_environment
  cluster_name = var.gitops_cluster_name
  gke_version  = var.gitops_gke_version

  # GCP account
  region     = var.region
  project_id = var.project_id

  # Networking
  network_cidr = var.vpc_cidr
  network      = google_compute_network.main.name
  # CRITICAL: Node subnets MUST match the subnets with secondary IP ranges
  # GKE requires secondary IP ranges for pods and services in VPC-native clusters
  subnetwork = google_compute_subnetwork.private_gke_gitops[0].name

  # Public subnetwork for internet-facing LoadBalancers (ArgoCD, Chartmuseum)
  public_subnetwork = google_compute_subnetwork.public[0].name

  # Node pool - smaller instances for GitOps management
  node_pool_machine_type = var.gitops_node_pool_machine_type
  node_pool_desired_size = var.gitops_node_pool_desired_size
  node_pool_min_size     = var.gitops_node_pool_min_size
  node_pool_max_size     = var.gitops_node_pool_max_size

  # Auth - same admin users as production
  admin_users = var.gitops_admin_users

  # Tags
  proc_budget = var.proc_budget

  # Datadog
  datadog_api_secret_name = var.gitops_datadog_api_secret_name
  # NOTE: Secrets must be created first. They are created in secrets.tf at the root level.

  # Cross-cluster communication
  target_cluster_name       = module.gke.cluster_name
  target_cluster_endpoint   = module.gke.cluster_endpoint
  target_cluster_ca_data    = module.gke.cluster_certificate_authority_data
  target_cluster_location   = module.gke.cluster_location
  target_cluster_project_id = var.project_id

  # Enable GitOps-specific components
  enable_rbac_config        = true
  enable_datadog            = true
  enable_cluster_autoscaler = true
  enable_chartmuseum        = true
  enable_argocd             = true
}

