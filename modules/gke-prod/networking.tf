####################################################################################################
###                                                                                              ###
###                                   GKE NETWORKING/FIREWALL                                    ###
###                                                                                              ###
####################################################################################################

# GCP uses firewall rules instead of security groups
# This file defines firewall rules for the GKE cluster

# Allow internal cluster communication
resource "google_compute_firewall" "gke_cluster_internal" {
  name    = "${local.cluster_name}-internal"
  network = var.network
  project = var.project_id

  depends_on = [google_container_cluster.prod_gke]

  allow {
    protocol = "tcp"
    ports    = ["443", "10250", "10255", "10256"]
  }

  allow {
    protocol = "udp"
    ports    = ["4789"]
  }

  source_ranges = [var.network_cidr]
  target_tags   = ["${local.cluster_name}-nodes"]

  description = "Allow internal GKE cluster communication"
}

# Allow master to nodes communication
resource "google_compute_firewall" "gke_master_to_nodes" {
  name    = "${local.cluster_name}-master-to-nodes"
  network = var.network
  project = var.project_id

  depends_on = [google_container_cluster.prod_gke]

  allow {
    protocol = "tcp"
    ports    = ["10250", "10255"]
  }

  source_ranges = ["172.16.0.16/28"] # Master IP range
  target_tags   = ["${local.cluster_name}-nodes"]

  description = "Allow GKE master to nodes communication"
}

# Allow gitops cluster to access prod cluster API server
resource "google_compute_firewall" "gke_gitops_to_prod_api" {
  name    = "${local.cluster_name}-allow-gitops-api"
  network = var.network
  project = var.project_id

  depends_on = [google_container_cluster.prod_gke]

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  # Allow from gitops cluster network (gitops nodes can access prod API)
  source_ranges = [var.network_cidr]
  target_tags   = []

  description = "Allow gitops cluster to access prod cluster API server"
}

