####################################################################################################
###                                                                                              ###
###                                      GKE MODULE OUTPUTS                                      ###
###                                                                                              ###
####################################################################################################

output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.gitops_gke.name
}

output "cluster_endpoint" {
  description = "Endpoint for the GKE cluster API server"
  value       = google_container_cluster.gitops_gke.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = google_container_cluster.gitops_gke.master_auth[0].cluster_ca_certificate
}

output "cluster_location" {
  description = "Location of the GKE cluster"
  value       = google_container_cluster.gitops_gke.location
}

output "chartmuseum_loadbalancer_url" {
  description = "LoadBalancer URL for ChartMuseum"
  value       = var.enable_chartmuseum && length(data.kubernetes_service.chartmuseum) > 0 && data.kubernetes_service.chartmuseum[0].status != null && length(data.kubernetes_service.chartmuseum[0].status) > 0 && data.kubernetes_service.chartmuseum[0].status[0].load_balancer != null && length(data.kubernetes_service.chartmuseum[0].status[0].load_balancer) > 0 && data.kubernetes_service.chartmuseum[0].status[0].load_balancer[0].ingress != null && length(data.kubernetes_service.chartmuseum[0].status[0].load_balancer[0].ingress) > 0 ? "http://${data.kubernetes_service.chartmuseum[0].status[0].load_balancer[0].ingress[0].ip}:8080" : null
}

