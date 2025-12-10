####################################################################################################
###                                                                                              ###
###                            Public Subnet Definitions                                          ###
###                                                                                              ###
####################################################################################################

# Create public subnets for Cloud NAT and Internet Gateway
# These are needed for outbound internet access from private subnets
# Using for_each to create subnets from list variable

locals {
  # Map availability zones to subnet indices
  public_azs = [
    var.az_primary,
    var.az_secondary
  ]
}

resource "google_compute_subnetwork" "public" {
  for_each = {
    for idx, cidr in var.public_subnets : idx => {
      cidr   = cidr
      region = var.region
    }
  }

  name          = "public-subnet-${var.name_region}-${format("%02d", each.key)}"
  ip_cidr_range = each.value.cidr
  network       = google_compute_network.main.id
  region        = each.value.region

  description = "Public subnet for Cloud NAT and Load Balancers"

  depends_on = [google_compute_network.main]
}

####################################################################################################
###                                                                                              ###
###                            Cloud NAT (equivalent to AWS NAT Gateway)                        ###
###                                                                                              ###
####################################################################################################

# Reserve static IP for Cloud NAT
resource "google_compute_address" "nat_gateway" {
  name         = "nat-gateway-ip-${var.name_region}"
  address_type = "EXTERNAL"
  region       = var.region

  description = "Static IP for Cloud NAT Gateway"

}

# Cloud Router for Cloud NAT
resource "google_compute_router" "nat_router" {
  name    = "nat-router-${var.name_region}"
  region  = var.region
  network = google_compute_network.main.id

  bgp {
    asn = 64514
  }

  description = "Cloud Router for NAT Gateway"

  depends_on = [google_compute_network.main]
}

# Cloud NAT Gateway (single NAT Gateway for cost efficiency)
# Private subnets route through this for internet access
resource "google_compute_router_nat" "main" {
  name                               = "nat-gateway-${var.name_region}"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.nat_gateway.self_link]
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  depends_on = [
    google_compute_address.nat_gateway,
    google_compute_router.nat_router
  ]
}

####################################################################################################
###                                                                                              ###
###                                       Outputs                                               ###
###                                                                                              ###
####################################################################################################

# Output public subnet IDs
output "public_subnet_ids" {
  description = "List of public subnet names"
  value       = [for subnet in google_compute_subnetwork.public : subnet.name]
}

# Output public subnet CIDRs
output "public_subnet_cidrs" {
  description = "List of public subnet CIDRs"
  value       = [for subnet in google_compute_subnetwork.public : subnet.ip_cidr_range]
}

