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

  provider = kubernetes.gitops

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

  depends_on = [google_container_cluster.gitops_gke]
}

