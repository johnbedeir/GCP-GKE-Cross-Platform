#!/bin/bash

####################################################################################################
###                                                                                              ###
###                              GCP CROSS PLATFORM DESTROY SCRIPT                                ###
###                                                                                              ###
###  This script destroys all infrastructure in the correct order:                                ###
###  1. Cross-Cluster Resources (ArgoCD cluster secrets)                                          ###
###  2. Production Cluster (GKE Production cluster and its components)                          ###
###  3. GitOps Cluster (GKE GitOps cluster and its components)                                  ###
###  4. VPC and Networking (VPC, Subnets, NAT, Firewall Rules)                                   ###
###  5. Secrets (Datadog API keys)                                                                ###
###  6. Final Destroy (Catch any remaining resources)                                             ###
###                                                                                              ###
####################################################################################################

set -e # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print steps
print_step() {
    echo -e "\n${GREEN}====================================================================================${NC}"
    echo -e "${GREEN}[STEP]${NC} $1"
    echo -e "${GREEN}====================================================================================${NC}"
}

# Function to print errors
print_error() {
    echo -e "\n${RED}[ERROR]${NC} $1" >&2
}

# Function to print warnings
print_warning() {
    echo -e "\n${YELLOW}[WARNING]${NC} $1"
}

# Change to the Terraform directory
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
cd "$SCRIPT_DIR"

# Confirmation prompt
echo -e "${RED}====================================================================================${NC}"
echo -e "${RED}⚠️  WARNING: This will DESTROY ALL GCP infrastructure!${NC}"
echo -e "${RED}====================================================================================${NC}"
echo ""
echo "This includes:"
echo "  - GKE Production cluster and all its resources"
echo "  - GKE GitOps cluster and all its resources"
echo "  - VPC, Subnets, NAT Gateway, Firewall Rules"
echo "  - All Datadog secrets"
echo "  - All ArgoCD configurations"
echo ""
read -p "Are you sure you want to continue? Type 'yes' to confirm: " confirm

if [ "$confirm" != "yes" ]; then
    echo "Destroy cancelled."
    exit 0
fi

####################################################################################################
### STEP 1: Destroy Cross-Cluster Resources                                                      ###
####################################################################################################

print_step "Step 1: Destroying ArgoCD cross-cluster resources..."
echo "This includes:"
echo "  - ArgoCD cluster secret for Production cluster"
echo ""

terraform destroy -target=module.gke_gitops.kubernetes_secret.argocd_prod_cluster \
                  -auto-approve 2>&1 || print_warning "ArgoCD secret may not exist or already destroyed"
echo ""

####################################################################################################
### STEP 2: Destroy Production Cluster                                                           ###
####################################################################################################

print_step "Step 2: Destroying GKE Production Cluster and its components..."
echo "This includes:"
echo "  - GKE Production Cluster"
echo "  - Node Pools for Production"
echo "  - Service Accounts and Workload Identity for Production"
echo "  - Datadog Helm release for Production"
echo "  - RBAC configurations"
echo ""

terraform destroy -target=module.gke \
                  -auto-approve
if [ $? -ne 0 ]; then
    print_error "Production Cluster destroy failed"
    print_warning "You may need to manually clean up resources in GCP console"
    exit 1
fi
echo ""

####################################################################################################
### STEP 3: Destroy GitOps Cluster                                                               ###
####################################################################################################

print_step "Step 3: Destroying GKE GitOps Cluster and its components..."
echo "This includes:"
echo "  - GKE GitOps Cluster"
echo "  - Node Pools for GitOps"
echo "  - Service Accounts and Workload Identity for GitOps"
echo "  - ArgoCD, Chartmuseum, Datadog Helm releases"
echo ""

terraform destroy -target=module.gke_gitops \
                  -auto-approve
if [ $? -ne 0 ]; then
    print_error "GitOps Cluster destroy failed"
    print_warning "You may need to manually clean up resources in GCP console"
    exit 1
fi
echo ""

####################################################################################################
### STEP 4: Destroy VPC and Networking                                                            ###
####################################################################################################

print_step "Step 4: Destroying VPC and Networking infrastructure..."
echo "This includes:"
echo "  - Firewall Rules"
echo "  - Cloud Router and Cloud NAT"
echo "  - Private Subnets for GKE Prod and GitOps"
echo "  - Public Subnets"
echo "  - VPC Network"
echo ""

terraform destroy -target=google_compute_firewall.gke_gitops_to_prod_api \
                  -target=google_compute_firewall.gke_master_to_nodes \
                  -target=google_compute_firewall.gke_cluster_internal \
                  -target=google_compute_router_nat.main \
                  -target=google_compute_router.nat_router \
                  -target=google_compute_address.nat_gateway \
                  -target=google_compute_subnetwork.private_gke_gitops \
                  -target=google_compute_subnetwork.private_gke_prod \
                  -target=google_compute_subnetwork.public \
                  -target=google_compute_network.main \
                  -auto-approve
if [ $? -ne 0 ]; then
    print_error "VPC and Networking destroy failed"
    print_warning "You may need to manually clean up resources in GCP console"
    print_warning "Check for:"
    print_warning "  - Firewall rules blocking VPC deletion"
    print_warning "  - Load balancers using subnets"
    exit 1
fi
echo ""

####################################################################################################
### STEP 5: Destroy Secrets                                                                      ###
####################################################################################################

print_step "Step 5: Destroying GCP Secret Manager secrets..."
echo "This includes:"
echo "  - Datadog API key secret for Production cluster"
echo "  - Datadog API key secret for GitOps cluster"
echo ""

terraform destroy -target=google_secret_manager_secret_version.gitops_datadog_api_key \
                  -target=google_secret_manager_secret.gitops_datadog_api_key \
                  -target=google_secret_manager_secret_version.datadog_api_key \
                  -target=google_secret_manager_secret.datadog_api_key \
                  -auto-approve 2>&1 || print_warning "Secrets may not exist or already destroyed"
echo ""

####################################################################################################
### STEP 6: Final Destroy (Catch any remaining resources)                                        ###
####################################################################################################

print_step "Step 6: Performing final 'terraform destroy' to catch any remaining resources..."
terraform destroy -auto-approve
if [ $? -ne 0 ]; then
    print_error "Final 'terraform destroy' failed"
    print_warning "Some resources may still exist. Check GCP console for remaining resources."
    exit 1
fi
echo ""

####################################################################################################
### STEP 7: Cleanup Verification                                                                 ###
####################################################################################################

print_step "Step 7: Verifying cleanup..."

# Check for remaining clusters
REMAINING_CLUSTERS=$(gcloud container clusters list --project=johnydev --format="value(name)" 2>/dev/null | wc -l | tr -d ' ')
if [ "$REMAINING_CLUSTERS" != "0" ]; then
    print_warning "Found $REMAINING_CLUSTERS remaining cluster(s):"
    gcloud container clusters list --project=johnydev --format="table(name,location,status)" 2>/dev/null
    echo ""
    print_warning "You may need to manually delete these clusters:"
    print_warning "  gcloud container clusters delete <cluster-name> --region=<region> --project=johnydev"
else
    echo "✅ No remaining clusters found"
fi

# Check for remaining VPC networks
REMAINING_NETWORKS=$(gcloud compute networks list --project=johnydev --format="value(name)" 2>/dev/null | wc -l | tr -d ' ')
if [ "$REMAINING_NETWORKS" != "0" ]; then
    print_warning "Found $REMAINING_NETWORKS remaining network(s):"
    gcloud compute networks list --project=johnydev --format="table(name)" 2>/dev/null
    echo ""
    print_warning "You may need to manually delete these networks:"
    print_warning "  gcloud compute networks delete <network-name> --project=johnydev"
else
    echo "✅ No remaining networks found"
fi

# Check for remaining firewall rules
REMAINING_FIREWALLS=$(gcloud compute firewall-rules list --project=johnydev --filter="network:gke-vpc-us-east1" --format="value(name)" 2>/dev/null | wc -l | tr -d ' ')
if [ "$REMAINING_FIREWALLS" != "0" ]; then
    print_warning "Found $REMAINING_FIREWALLS remaining firewall rule(s):"
    gcloud compute firewall-rules list --project=johnydev --filter="network:gke-vpc-us-east1" --format="table(name)" 2>/dev/null
    echo ""
    print_warning "You may need to manually delete these firewall rules:"
    print_warning "  gcloud compute firewall-rules delete <rule-name> --project=johnydev"
else
    echo "✅ No remaining firewall rules found"
fi

echo ""
print_step "Destroy process completed!"
echo ""
echo "📝 Next steps:"
echo "  1. Verify all resources are deleted in GCP console"
echo "  2. Check for any remaining resources and delete manually if needed"
echo "  3. Run 'terraform init' if you want to rebuild"
echo ""

