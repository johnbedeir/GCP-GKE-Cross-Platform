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
  host                   = "https://${google_container_cluster.prod_gke.endpoint}"
  cluster_ca_certificate = base64decode(google_container_cluster.prod_gke.master_auth[0].cluster_ca_certificate)
  token                  = data.google_client_config.provider.access_token
}

provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.prod_gke.endpoint}"
    cluster_ca_certificate = base64decode(google_container_cluster.prod_gke.master_auth[0].cluster_ca_certificate)
    token                  = data.google_client_config.provider.access_token
  }
}

resource "google_container_cluster" "prod_gke" {
  name     = local.cluster_name
  location = var.region
  project  = var.project_id

  # Use the latest stable version or specify a version
  min_master_version = var.gke_version

  # Enable private cluster
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.16/28"
  }

  # Network configuration
  # Implicit dependency: network and subnetwork must exist before cluster creation
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

  # Enable master auth for Terraform Kubernetes provider access
  # This is required for the Kubernetes provider to authenticate
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # Note: Cluster autoscaler is enabled via the autoscaling block in node pools
  # See node_pool.tf for autoscaling configuration (min_node_count, max_node_count)
  # GKE's built-in autoscaler automatically works when node pools have autoscaling configured

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

  # node_config is required even when remove_default_node_pool = true
  # It's used for the temporary default pool that gets created and removed
  # We must use a custom service account, not the default compute service account
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

  # Lifecycle: Ignore changes to default node pool settings after cluster creation
  # Once the default pool is removed, we don't want Terraform to try to update these fields
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

