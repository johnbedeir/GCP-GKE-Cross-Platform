####################################################################################################
###                                                                                              ###
###                            GKE Production Subnet Definitions                                 ###
###                                                                                              ###
####################################################################################################

# Create dedicated GKE production subnets for application deployment
# Using for_each to create subnets from list variable

locals {
  # Map availability zones to subnet indices (2 AZs for high availability)
  gke_prod_azs = [
    var.az_primary,
    var.az_secondary
  ]
}

resource "google_compute_subnetwork" "private_gke_prod" {
  for_each = {
    for idx, cidr in var.private_gke_prod_subnets : idx => {
      cidr   = cidr
      region = var.region
    }
  }

  name          = "private-gke-prod-subnet-${var.name_region}-${format("%02d", each.key)}"
  ip_cidr_range = each.value.cidr
  network       = google_compute_network.main.id
  region        = each.value.region

  depends_on = [google_compute_network.main]

  # Enable private Google access for GKE nodes
  private_ip_google_access = true

  # Secondary IP ranges for pods and services (required for VPC-native clusters)
  # Use /20 ranges (4096 IPs each) for pods and services
  # For 10.0.0.0/16 VPC: pods use 10.1.0.0/16, services use 10.2.0.0/16
  # Each subnet gets a /20 slice from these /16 ranges
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = cidrsubnet("10.1.0.0/16", 4, each.key) # Split 10.1.0.0/16 into /20 ranges
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = cidrsubnet("10.2.0.0/16", 4, each.key) # Split 10.2.0.0/16 into /20 ranges
  }

  description = "Private subnet for GKE production cluster"

}

####################################################################################################
###                                                                                              ###
###                                       Outputs                                               ###
###                                                                                              ###
####################################################################################################

# Output subnet IDs for use in GKE configuration
output "gke_prod_subnet_ids" {
  description = "List of GKE production subnet names"
  value       = [for subnet in google_compute_subnetwork.private_gke_prod : subnet.name]
}

output "gke_prod_subnet_cidrs" {
  description = "List of GKE production subnet CIDRs"
  value       = [for subnet in google_compute_subnetwork.private_gke_prod : subnet.ip_cidr_range]
}

