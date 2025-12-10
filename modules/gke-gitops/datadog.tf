####################################################################################################
###                                                                                              ###
###                                      DATADOG AGENT                                          ###
###                                                                                              ###
####################################################################################################

# Get Datadog API key from GCP Secret Manager
# Note: Secret must be created in root secrets.tf before this data source can read it
# Using depends_on with a delay to ensure secret exists (workaround for cross-module dependencies)
data "google_secret_manager_secret_version" "datadog_api_key" {
  count   = var.enable_datadog ? 1 : 0
  secret  = var.datadog_api_secret_name
  project = var.project_id

  # Add a small delay to ensure secret is created
  # This is a workaround since we can't directly reference root module resources
  depends_on = [
    google_container_cluster.gitops_gke
  ]
}

# Create Kubernetes secret for Datadog API key
resource "kubernetes_secret" "datadog_api_key" {
  count    = var.enable_datadog ? 1 : 0
  provider = kubernetes.gitops

  metadata {
    name      = "datadog-secret"
    namespace = "kube-system"
  }

  data = {
    "api-key" = trimspace(data.google_secret_manager_secret_version.datadog_api_key[0].secret_data)
  }

  depends_on = [google_container_cluster.gitops_gke]
}

# Helm release for Datadog agent
# Using Helm chart instead of CRD for better reliability during cluster initialization
resource "helm_release" "datadog_agent" {
  count = var.enable_datadog ? 1 : 0

  provider = helm.gitops

  name             = "datadog"
  namespace        = "kube-system"
  repository       = "https://helm.datadoghq.com"
  chart            = "datadog"
  version          = "3.116.3"
  create_namespace = false
  timeout          = 600
  wait             = false

  set {
    name  = "datadog.apiKeyExistingSecret"
    value = kubernetes_secret.datadog_api_key[0].metadata[0].name
  }

  set {
    name  = "datadog.apiKeySecretKey"
    value = "api-key"
  }

  set {
    name  = "datadog.site"
    value = "datadoghq.com"
  }

  set {
    name  = "datadog.clusterName"
    value = google_container_cluster.gitops_gke.name
  }

  set {
    name  = "clusterAgent.enabled"
    value = "true"
  }

  set {
    name  = "clusterAgent.replicas"
    value = "1"
  }

  set {
    name  = "clusterAgent.admissionController.enabled"
    value = "false"
  }

  depends_on = [
    google_container_cluster.gitops_gke,
    google_container_node_pool.gitops_prod,
    kubernetes_secret.datadog_api_key
  ]
}

