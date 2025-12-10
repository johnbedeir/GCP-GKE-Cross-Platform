####################################################################################################
###                                                                                              ###
###                                       GKE NODE POOL                                          ###
###                                                                                              ###
####################################################################################################

resource "google_container_node_pool" "gitops_prod" {
  name       = "gitops-prod"
  location   = var.region
  cluster    = google_container_cluster.gitops_gke.name
  project    = var.project_id
  node_count = var.node_pool_desired_size

  autoscaling {
    min_node_count = var.node_pool_min_size
    max_node_count = var.node_pool_max_size
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.node_pool_machine_type[0]
    disk_size_gb = 30
    disk_type    = "pd-standard"
    image_type   = "COS_CONTAINERD"

    service_account = google_service_account.node_service_account.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      # GCP node labels must begin and end with alphanumeric characters
      # Use underscores instead of slashes for cluster-autoscaler labels
      "cluster_autoscaler_enabled" = "true"
      "cluster_autoscaler_owned"   = google_container_cluster.gitops_gke.name
      "budget"                     = var.proc_budget
    }

    tags = [
      "${local.cluster_name}-nodes"
    ]
  }

  depends_on = [
    google_container_cluster.gitops_gke,
    google_service_account.node_service_account
  ]

  lifecycle {
    ignore_changes = [
      node_count
    ]
  }
}

