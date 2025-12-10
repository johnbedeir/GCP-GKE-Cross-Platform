####################################################################################################
###                                                                                              ###
###                                       GKE RBAC CONFIG                                        ###
###                                                                                              ###
####################################################################################################

# GKE uses native RBAC with Google Groups or IAM bindings
# This file manages Kubernetes RBAC bindings for admin users

locals {
  admin_user_bindings = [
    for admin_user in var.admin_users :
    {
      userarn  = "user:${admin_user}"
      username = split("@", admin_user)[0]
      groups   = ["system:masters"]
    }
  ]
}

# Create ClusterRoleBinding for admin users
resource "kubernetes_cluster_role_binding" "admin_users" {
  count = var.enable_rbac_config && length(var.admin_users) > 0 ? 1 : 0

  metadata {
    name = "admin-users-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "User"
    name      = var.admin_users[0]
    api_group = "rbac.authorization.k8s.io"
  }

  dynamic "subject" {
    for_each = slice(var.admin_users, 1, length(var.admin_users))
    content {
      kind      = "User"
      name      = subject.value
      api_group = "rbac.authorization.k8s.io"
    }
  }

  depends_on = [google_container_cluster.prod_gke]
}

# ClusterRoleBinding for ArgoCD from GitOps cluster
# This grants the ArgoCD service account cluster-admin permissions on this cluster
# ArgoCD uses the gitops cluster's service account (gkgitops-argocd-x) to authenticate
resource "kubernetes_cluster_role_binding" "argocd_gitops_access" {
  count = var.enable_argocd_access && var.gitops_cluster_name != "" ? 1 : 0

  metadata {
    name = "argocd-gitops-access"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  # Bind the GitOps cluster's GCP service account email
  # This is what ArgoCD actually uses: gkgitops-argocd-x@PROJECT.iam.gserviceaccount.com
  # We need to construct it from the gitops cluster name pattern
  # The gitops module creates: gkgitops-argocd-x@PROJECT.iam.gserviceaccount.com
  subject {
    kind      = "User"
    name      = "gkgitops-argocd-x@${var.project_id}.iam.gserviceaccount.com"
    api_group = "rbac.authorization.k8s.io"
  }

  # Also bind the Workload Identity format (for GKE Workload Identity)
  # Format: serviceAccount:PROJECT_ID.svc.id.goog[NAMESPACE/SERVICE_ACCOUNT]
  subject {
    kind      = "User"
    name      = "serviceAccount:${var.project_id}.svc.id.goog[argocd/argocd-application-controller]"
    api_group = "rbac.authorization.k8s.io"
  }

  # Bind the prod cluster's service account (for completeness)
  subject {
    kind      = "User"
    name      = google_service_account.argocd_gitops_access[0].email
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [
    google_container_cluster.prod_gke,
    google_service_account.argocd_gitops_access
  ]
}

