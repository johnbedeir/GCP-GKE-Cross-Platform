####################################################################################################
###                                                                                              ###
###                                      CHARTMUSEUM                                            ###
###                                                                                              ###
####################################################################################################

locals {
  chartmuseum_values = <<EOF
    env:
      open:
        DISABLE_API: false
        STORAGE: local
    service:
      type: LoadBalancer
      annotations:
        cloud.google.com/load-balancer-type: "External"
    persistence:
      enabled: true
      accessMode: ReadWriteOnce
      size: ${var.chartmuseum_storage_size}
      storageClass: ${var.chartmuseum_storage_class}
    EOF
}

resource "helm_release" "chartmuseum" {
  count = var.enable_chartmuseum ? 1 : 0

  provider         = helm.gitops
  name             = "chartmuseum"
  repository       = "https://chartmuseum.github.io/charts"
  chart            = "chartmuseum"
  version          = "3.9.1"
  cleanup_on_fail  = true
  namespace        = "chartmuseum"
  create_namespace = true
  wait             = false
  values           = [local.chartmuseum_values]

  depends_on = [
    google_container_cluster.gitops_gke,
    google_container_node_pool.gitops_prod
  ]
}

data "kubernetes_service" "chartmuseum" {
  count    = var.enable_chartmuseum ? 1 : 0
  provider = kubernetes.gitops

  metadata {
    name      = "chartmuseum"
    namespace = "chartmuseum"
  }

  depends_on = [
    helm_release.chartmuseum,
    google_container_cluster.gitops_gke,
    google_container_node_pool.gitops_prod
  ]
}

