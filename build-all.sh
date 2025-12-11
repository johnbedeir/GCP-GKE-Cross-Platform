#!/bin/bash

####################################################################################################
###                                                                                              ###
###                              GCP CROSS PLATFORM BUILD SCRIPT                                 ###
###                                                                                              ###
###  This script builds all infrastructure in the correct order:                                ###
###  1. VPC and Networking (VPC, Subnets, NAT, Firewall Rules)                                  ###
###  2. GitOps Cluster (GKE GitOps cluster with ArgoCD)                                         ###
###  3. Production Cluster (GKE Production cluster)                                            ###
###                                                                                              ###
####################################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "main.tf" ] && [ ! -f "vpc.tf" ]; then
    print_error "Please run this script from the GCP_Cross_Platform directory"
    exit 1
fi

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed. Please install it first."
    exit 1
fi

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI is not installed. Please install it first."
    exit 1
fi

print_step "Starting infrastructure build process..."
echo ""

####################################################################################################
### STEP 1: Initialize Terraform                                                                ###
####################################################################################################

print_step "Step 1: Initializing Terraform..."
terraform init
if [ $? -ne 0 ]; then
    print_error "Terraform initialization failed"
    exit 1
fi
echo ""

####################################################################################################
### STEP 2: Create Secrets (must be created before clusters try to read them)                  ###
####################################################################################################

print_step "Step 2: Creating GCP Secret Manager secrets..."
echo "This includes:"
echo "  - Datadog API key secret for Production cluster"
echo "  - Datadog API key secret for GitOps cluster"
echo ""

terraform apply -target=google_secret_manager_secret.datadog_api_key \
                -target=google_secret_manager_secret_version.datadog_api_key \
                -target=google_secret_manager_secret.gitops_datadog_api_key \
                -target=google_secret_manager_secret_version.gitops_datadog_api_key \
                -auto-approve

if [ $? -ne 0 ]; then
    print_error "Secrets creation failed"
    exit 1
fi

echo ""
print_step "Secrets created successfully!"
echo ""

####################################################################################################
### STEP 3: Build VPC and Networking                                                             ###
####################################################################################################

print_step "Step 3: Building VPC and Networking infrastructure..."
echo "This includes:"
echo "  - VPC Network"
echo "  - Public Subnets"
echo "  - Private Subnets (GitOps and Prod)"
echo "  - Cloud NAT"
echo "  - Firewall Rules"
echo ""

terraform apply -target=google_compute_network.main \
                -target=google_compute_subnetwork.public \
                -target=google_compute_subnetwork.private_gke_gitops \
                -target=google_compute_subnetwork.private_gke_prod \
                -target=google_compute_address.nat_gateway \
                -target=google_compute_router.nat_router \
                -target=google_compute_router_nat.main \
                -auto-approve

if [ $? -ne 0 ]; then
    print_error "VPC and Networking build failed"
    exit 1
fi

echo ""
print_step "VPC and Networking infrastructure created successfully!"
echo ""

####################################################################################################
### STEP 4: Build GitOps Cluster                                                                 ###
####################################################################################################

print_step "Step 4: Building GitOps Cluster (GKE GitOps with ArgoCD)..."
echo "This includes:"
echo "  - GKE GitOps Cluster"
echo "  - Node Pool"
echo "  - Service Accounts"
echo "  - ArgoCD"
echo "  - Chartmuseum"
echo "  - Datadog"
echo ""

terraform apply -target=module.gke_gitops \
                -auto-approve

if [ $? -ne 0 ]; then
    print_error "GitOps Cluster build failed"
    exit 1
fi

echo ""
print_step "GitOps Cluster created successfully!"
echo ""

# Wait for ArgoCD to be ready
print_step "Waiting for ArgoCD to be ready (this may take a few minutes)..."
sleep 30

# Get GitOps cluster credentials
print_step "Getting GitOps cluster credentials..."
GITOPS_CLUSTER_NAME=$(terraform output -raw module.gke_gitops.cluster_name 2>/dev/null || echo "gke-gitops-production")
GITOPS_CLUSTER_LOCATION=$(terraform output -raw module.gke_gitops.cluster_location 2>/dev/null || echo "us-east1")
GCP_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "johnydev")

gcloud container clusters get-credentials "$GITOPS_CLUSTER_NAME" \
    --region="$GITOPS_CLUSTER_LOCATION" \
    --project="$GCP_PROJECT" \
    --quiet 2>/dev/null || print_warning "Could not get GitOps cluster credentials automatically. You may need to run: gcloud container clusters get-credentials $GITOPS_CLUSTER_NAME --region=$GITOPS_CLUSTER_LOCATION"

echo ""

####################################################################################################
### STEP 5: Build Production Cluster                                                             ###
####################################################################################################

print_step "Step 5: Building Production Cluster (GKE Prod)..."
echo "This includes:"
echo "  - GKE Production Cluster"
echo "  - Node Pool"
echo "  - Service Accounts"
echo "  - Datadog"
echo "  - Cross-cluster access configuration"
echo ""

terraform apply -target=module.gke \
                -auto-approve

if [ $? -ne 0 ]; then
    print_error "Production Cluster build failed"
    exit 1
fi

echo ""
print_step "Production Cluster created successfully!"
echo ""

####################################################################################################
### STEP 6: Configure Cross-Cluster Communication                                               ###
####################################################################################################

print_step "Step 6: Configuring cross-cluster communication for ArgoCD..."
echo "This includes:"
echo "  - ArgoCD cluster secret for production cluster"
echo "  - Workload Identity bindings"
echo ""

terraform apply -target=module.gke_gitops.kubernetes_secret.argocd_prod_cluster \
                -auto-approve

if [ $? -ne 0 ]; then
    print_warning "Cross-cluster configuration had issues, but continuing..."
fi

echo ""
print_step "Cross-cluster communication configured!"
echo ""

####################################################################################################
### STEP 7: Final Apply (Catch any remaining resources)                                         ###
####################################################################################################

print_step "Step 7: Final apply to catch any remaining resources..."
terraform apply -auto-approve

if [ $? -ne 0 ]; then
    print_warning "Final apply had some issues, but main infrastructure should be built"
fi

echo ""

####################################################################################################
### STEP 8: Get Cluster Information                                                              ###
####################################################################################################

print_step "Build completed successfully!"
echo ""
echo "Cluster Information:"
echo "===================="

# GitOps Cluster
GITOPS_CLUSTER=$(terraform output -raw module.gke_gitops.cluster_name 2>/dev/null || echo "gke-gitops-production")
GITOPS_LOCATION=$(terraform output -raw module.gke_gitops.cluster_location 2>/dev/null || echo "us-east1")
GITOPS_ENDPOINT=$(terraform output -raw module.gke_gitops.cluster_endpoint 2>/dev/null || echo "N/A")

echo ""
echo "GitOps Cluster:"
echo "  Name: $GITOPS_CLUSTER"
echo "  Location: $GITOPS_LOCATION"
echo "  Endpoint: $GITOPS_ENDPOINT"
echo ""

# Production Cluster
PROD_CLUSTER=$(terraform output -raw module.gke.cluster_name 2>/dev/null || echo "gke-prod-production")
PROD_LOCATION=$(terraform output -raw module.gke.cluster_location 2>/dev/null || echo "us-east1")
PROD_ENDPOINT=$(terraform output -raw module.gke.cluster_endpoint 2>/dev/null || echo "N/A")

echo "Production Cluster:"
echo "  Name: $PROD_CLUSTER"
echo "  Location: $PROD_LOCATION"
echo "  Endpoint: $PROD_ENDPOINT"
echo ""

# ArgoCD LoadBalancer
print_step "Getting ArgoCD LoadBalancer information..."
kubectl get svc -n argocd argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null && echo "" || print_warning "ArgoCD service not ready yet or not accessible"

echo ""
print_step "To access ArgoCD, wait for the LoadBalancer IP and then:"
echo "  kubectl get svc -n argocd argocd-server"
echo ""
echo "To get ArgoCD admin password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
echo ""

print_step "Build process completed!"
echo ""
echo "Next steps:"
echo "  1. Wait for ArgoCD LoadBalancer to get an external IP"
echo "  2. Access ArgoCD UI using the LoadBalancer IP"
echo "  3. Verify the production cluster appears in ArgoCD (Settings > Clusters)"
echo "  4. Start deploying applications!"
echo ""

