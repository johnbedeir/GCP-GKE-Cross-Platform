####################################################################################################
###                                                                                              ###
###                                  CROSS-CLUSTER COMMUNICATION                                  ###
###                                                                                              ###
####################################################################################################

# Service Account for ArgoCD to manage external clusters
resource "google_service_account" "argocd_cross_cluster_access" {
  count = var.enable_argocd ? 1 : 0
  # Shorten account_id to meet 6-30 character limit
  # "gke-gitops-production" -> "gkgitops-prod" (14 chars) + "-argocd-x" = 23 chars total
  account_id   = "gkgitops-argocd-x"
  display_name = "ArgoCD Cross-Cluster Access Service Account"
  project      = var.project_id
}

# Grant permissions for ArgoCD to access GKE Prod clusters
resource "google_project_iam_member" "argocd_cross_cluster_gke" {
  count   = var.enable_argocd ? 1 : 0
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.argocd_cross_cluster_access[0].email}"
}

# Workload Identity binding for ArgoCD application controller
# NOTE: This must be created AFTER the GKE cluster is created because the Workload Identity pool
# (project-id.svc.id.goog) is automatically created when Workload Identity is enabled on the cluster
resource "google_service_account_iam_member" "argocd_cross_cluster_workload_identity" {
  count              = var.enable_argocd ? 1 : 0
  service_account_id = google_service_account.argocd_cross_cluster_access[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[argocd/argocd-application-controller]"

  depends_on = [
    google_container_cluster.gitops_gke
  ]
}

