####################################################################################################
###                                                                                              ###
###                                   GKE SERVICE ACCOUNTS                                        ###
###                                                                                              ###
####################################################################################################

# Service account for the GKE cluster
resource "google_service_account" "cluster_service_account" {
  account_id   = "${replace(local.cluster_name, "-", "")}-cluster"
  display_name = "GKE Cluster Service Account for ${local.cluster_name}"
  project      = var.project_id
}

# Service account for GKE worker nodes
resource "google_service_account" "node_service_account" {
  account_id   = "${replace(local.cluster_name, "-", "")}-nodes"
  display_name = "GKE Node Service Account for ${local.cluster_name}"
  project      = var.project_id
}

# Grant the node service account necessary permissions
resource "google_project_iam_member" "node_service_account_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.node_service_account.email}"
}

resource "google_project_iam_member" "node_service_account_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.node_service_account.email}"
}

resource "google_project_iam_member" "node_service_account_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.node_service_account.email}"
}

resource "google_project_iam_member" "node_service_account_gcr" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.node_service_account.email}"
}

# Service account for GKE CSI driver (GCP Persistent Disk CSI)
resource "google_service_account" "gce_pd_csi" {
  account_id   = "${replace(local.cluster_name, "-", "")}-gce-pd-csi"
  display_name = "GCE PD CSI Driver Service Account for ${local.cluster_name}"
  project      = var.project_id
}

# Grant permissions for GCE PD CSI driver
resource "google_project_iam_member" "gce_pd_csi_service_agent" {
  project = var.project_id
  role    = "roles/compute.storageAdmin"
  member  = "serviceAccount:${google_service_account.gce_pd_csi.email}"
}

# Service account for ArgoCD GitOps access from external clusters
resource "google_service_account" "argocd_gitops_access" {
  count = var.enable_argocd_access ? 1 : 0
  # Shorten account_id to meet 6-30 character limit
  # "gke-prod-production" -> "gkeprod-prod" (13 chars) + "-argocd-gitops" = 28 chars total
  account_id   = "gkeprod-argocd-gitops"
  display_name = "ArgoCD GitOps Access Service Account"
  project      = var.project_id
}

# Grant permissions for ArgoCD to access GKE cluster
resource "google_project_iam_member" "argocd_gitops_gke" {
  count   = var.enable_argocd_access ? 1 : 0
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.argocd_gitops_access[0].email}"
}

# Workload Identity binding for ArgoCD from GitOps cluster
# This allows the GitOps cluster's ArgoCD to assume this service account
# NOTE: This must be created AFTER the GKE cluster is created because the Workload Identity pool
# (project-id.svc.id.goog) is automatically created when Workload Identity is enabled on the cluster
resource "google_service_account_iam_member" "argocd_gitops_workload_identity" {
  count              = var.enable_argocd_access && var.gitops_cluster_name != "" ? 1 : 0
  service_account_id = google_service_account.argocd_gitops_access[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[argocd/argocd-application-controller]"

  depends_on = [
    google_container_cluster.prod_gke
  ]
}

