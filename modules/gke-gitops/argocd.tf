####################################################################################################
###                                                                                              ###
###                                      ARGOCD                                                  ###
###                                                                                              ###
####################################################################################################

locals {
  argocd_values = <<EOF
    server:
      service:
        type: LoadBalancer
        port: 80
        targetPort: 8080
        annotations:
          cloud.google.com/load-balancer-type: "External"
      extraArgs:
        - --insecure
      serviceAccount:
        create: true
        name: argocd-server
    repoServer:
      service:
        port: 8081
      resources:
        limits:
          cpu: 500m
          memory: 512Mi
        requests:
          cpu: 250m
          memory: 256Mi
      serviceAccount:
        create: true
        name: argocd-repo-server
        annotations:
          iam.gke.io/gcp-service-account: ${var.enable_argocd ? google_service_account.argocd_repo_access[0].email : ""}
    applicationController:
      resources:
        limits:
          cpu: 500m
          memory: 512Mi
        requests:
          cpu: 250m
          memory: 256Mi
      serviceAccount:
        create: true
        name: argocd-application-controller
        annotations:
          iam.gke.io/gcp-service-account: ${var.enable_argocd && var.target_cluster_name != "" ? google_service_account.argocd_cross_cluster_access[0].email : ""}
      configs:
        params:
          server.insecure: true
    rbac:
      create: true
    EOF
}

resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  provider         = helm.gitops
  name             = "${local.cluster_name}-argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "8.2.4"
  cleanup_on_fail  = true
  namespace        = "argocd"
  create_namespace = true
  timeout          = 1200
  wait             = false

  values = [local.argocd_values]

  depends_on = [
    google_container_cluster.gitops_gke,
    google_container_node_pool.gitops_prod
  ]
}

# Create ArgoCD cluster secret for production cluster
resource "kubernetes_secret" "argocd_prod_cluster" {
  # Use for_each with a static key to avoid "unknown at plan time" errors
  # The key is static, so Terraform can determine the map structure even when values are unknown
  # The condition in the value will be evaluated at apply time
  for_each = var.enable_argocd ? { "prod-cluster" = true } : {}

  provider = kubernetes.gitops

  metadata {
    name      = "${replace(var.target_cluster_name != "" ? var.target_cluster_name : "prod-cluster", "-", "")}-cluster"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }

  type = "Opaque"

  data = {
    # Cluster name (friendly name shown in ArgoCD UI)
    # Kubernetes secrets automatically base64 encode, so we provide plain text
    name = var.target_cluster_name != "" ? var.target_cluster_name : "prod-cluster"

    # Production cluster endpoint
    # Must be full HTTPS URL (e.g., https://34.23.25.60)
    # Kubernetes secrets automatically base64 encode, so we provide plain text
    server = var.target_cluster_endpoint != "" ? "https://${replace(var.target_cluster_endpoint, "https://", "")}" : ""

    # Cluster configuration - ArgoCD v2+ format
    # ArgoCD will use GCP service account authentication via Workload Identity
    # Workload Identity is configured on the argocd-application-controller service account
    # The service account has the annotation: iam.gke.io/gcp-service-account
    # Kubernetes secrets automatically base64 encode, so we provide JSON string directly
    config = jsonencode({
      # TLS configuration
      # ArgoCD will use the pod's service account token automatically via Workload Identity
      # No explicit auth config needed - GKE handles this via the service account annotation
      tlsClientConfig = {
        # CA certificate for the production cluster (base64 encoded)
        caData = var.target_cluster_ca_data != "" ? var.target_cluster_ca_data : ""
        # Insecure skip TLS verify (set to false for production)
        insecure = false
      }
    })
  }

  depends_on = [
    helm_release.argocd,
    google_service_account.argocd_cross_cluster_access,
    google_service_account_iam_member.argocd_cross_cluster_workload_identity
  ]
}

