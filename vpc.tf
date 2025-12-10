####################################################################################################
###                                                                                              ###
###                                    VPC Network Configuration                                 ###
###                                                                                              ###
####################################################################################################

# Create VPC network
resource "google_compute_network" "main" {
  name                    = "gke-vpc-${var.name_region}"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  description = "VPC network for GKE clusters"

}

# Create private route for NAT Gateway (internet access from private subnets)
resource "google_compute_route" "private_nat" {
  name             = "private-nat-route-${var.name_region}"
  dest_range       = "0.0.0.0/0"
  network          = google_compute_network.main.name
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000

  tags = ["private"]

  depends_on = [google_compute_network.main]
}

# Note: GCP doesn't have Network ACLs like AWS
# Firewall rules are used instead (defined in modules/networking.tf)

