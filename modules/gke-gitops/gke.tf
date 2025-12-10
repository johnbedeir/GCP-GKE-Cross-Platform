####################################################################################################
###                                                                                              ###
###                                       GKE CLUSTER                                            ###
###                                                                                              ###
####################################################################################################

locals {
  cluster_name = "${var.name_prefix}-${var.environment}"
}

# Get current GCP client config for authentication
data "google_client_config" "provider" {}

provider "kubernetes" {
  alias = "gitops"

  host                   = "https://${google_container_cluster.gitops_gke.endpoint}"
  cluster_ca_certificate = base64decode(google_container_cluster.gitops_gke.master_auth[0].cluster_ca_certificate)
  token                  = data.google_client_config.provider.access_token
}

provider "helm" {
  alias = "gitops"
  kubernetes {
    host                   = "https://${google_container_cluster.gitops_gke.endpoint}"
    cluster_ca_certificate = base64decode(google_container_cluster.gitops_gke.master_auth[0].cluster_ca_certificate)
    token                  = data.google_client_config.provider.access_token
  }
}

resource "google_container_cluster" "gitops_gke" {
  name     = local.cluster_name
  location = var.region
  project  = var.project_id

  # Use the latest stable version or specify a version
  min_master_version = var.gke_version

  # Enable private cluster
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Network configuration
  # GKE uses a single subnetwork (unlike EKS which uses multiple subnets)
  network    = var.network
  subnetwork = var.subnetwork

  # Enable IP aliasing (required for VPC-native clusters)
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  # Enable Workload Identity for IAM integration
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # Enable network policy
  network_policy {
    enabled = true
  }

  # Enable binary authorization (optional)
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Resource labels (keys must start with lowercase letter)
  resource_labels = {
    budget = var.proc_budget
  }

  # Master authorized networks - allow access from anywhere (0.0.0.0/0) for k9s and kubectl access
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "Allow All (External Access)"
    }
  }

  # Set disk size for default pool to reduce quota usage during creation
  node_config {
    service_account = google_service_account.node_service_account.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    disk_size_gb = 30
    disk_type    = "pd-standard"
  }

  depends_on = [
    google_project_service.container,
    google_service_account.cluster_service_account,
    google_service_account.node_service_account
  ]

  lifecycle {
    ignore_changes = [
      remove_default_node_pool,
      initial_node_count,
      node_config
    ]
  }
}

# Enable required GCP APIs
resource "google_project_service" "container" {
  project = var.project_id
  service = "container.googleapis.com"

  disable_on_destroy = false
}

