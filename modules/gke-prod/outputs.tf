####################################################################################################
###                                                                                              ###
###                                      GKE MODULE OUTPUTS                                      ###
###                                                                                              ###
####################################################################################################

output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.prod_gke.name
}

output "cluster_endpoint" {
  description = "Endpoint for the GKE cluster API server"
  value       = google_container_cluster.prod_gke.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = google_container_cluster.prod_gke.master_auth[0].cluster_ca_certificate
}

output "cluster_location" {
  description = "Location of the GKE cluster"
  value       = google_container_cluster.prod_gke.location
}

