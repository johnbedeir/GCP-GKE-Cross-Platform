# GCP-GKE-Cross-Platform

<img src=cover.png>

A Terraform-based infrastructure as code project for deploying Google Kubernetes Engine (GKE) clusters with GitOps capabilities using ArgoCD. This project creates two GKE clusters: a Production cluster and a GitOps cluster for managing deployments.

## 🏗️ Architecture

- **Production Cluster (`gke-prod-production`)**: Main cluster for running production workloads
- **GitOps Cluster (`gke-gitops-production`)**: Cluster running ArgoCD for GitOps-based deployments
- **VPC Network**: Private networking with Cloud NAT for outbound internet access
- **Workload Identity**: GCP IAM integration for secure service account authentication
- **ArgoCD**: GitOps tool for continuous deployment from Git repositories

## 📋 Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [Google Cloud SDK (gcloud)](https://cloud.google.com/sdk/docs/install)
- GCP Project with billing enabled
- Required GCP APIs enabled:
  - Container API (GKE)
  - Compute Engine API
  - Secret Manager API
  - IAM API

## 🚀 Quick Start

### 1. Configure Terraform Variables

Copy the example variables file and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and update:

- `project_id`: Your GCP Project ID
- `admin_users`: Your GCP user email(s)
- `datadog_api_key_value`: Your Datadog API key (if using Datadog)

### 2. Deploy Infrastructure

Run the build script to deploy all infrastructure in the correct order:

```bash
./build-all.sh
```

This script will:

1. Initialize Terraform
2. Create GCP Secret Manager secrets (Datadog API keys)
3. Build VPC and networking infrastructure
4. Deploy GitOps cluster with ArgoCD, Chartmuseum, and Datadog
5. Deploy Production cluster with Datadog
6. Configure cross-cluster communication for ArgoCD
7. Get cluster credentials and display cluster information

**Expected time:** 15-20 minutes

### 3. Configure ArgoCD Cross-Cluster Access

After the build completes, configure ArgoCD to access the Production cluster:

```bash
./add-cluster-kubectl.sh
```

This script will:

- Get the Production cluster endpoint and CA certificate
- Create a bearer token from the ArgoCD service account
- Create a Kubernetes secret in the GitOps cluster for ArgoCD to connect to Production
- Restart the ArgoCD controller to pick up the new cluster configuration

**Wait 30 seconds** for the ArgoCD controller to restart.

### 4. Access ArgoCD UI

Get the ArgoCD LoadBalancer IP:

```bash
kubectl get svc -n argocd argocd-server
```

Get the ArgoCD admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Access ArgoCD UI at `https://<LOADBALANCER_IP>` (use the password from above, username is `admin`)

## 🧪 Testing with Hello World Helm Chart

### Step 1: Authenticate with Clusters

Authenticate with both clusters to verify access:

```bash
# Authenticate with Production cluster
gcloud container clusters get-credentials gke-prod-production --region us-east1 --project YOUR_PROJECT_ID

# Authenticate with GitOps cluster
gcloud container clusters get-credentials gke-gitops-production --region us-east1 --project YOUR_PROJECT_ID
```

### Step 2: Create Namespace on Production Cluster

Switch to the Production cluster context and create a test namespace:

```bash
# Ensure you're using the prod cluster
gcloud container clusters get-credentials gke-gitops-production --region us-east1 --project YOUR_PROJECT_ID

# Create test namespace
kubectl create namespace test
```

### Step 3: Add Helm Repository in ArgoCD

1. Open ArgoCD UI (from Step 4 above)
2. Go to **Settings** → **Repositories**
3. Click **Connect Repo**
4. Fill in:
   - **Type**: Helm
   - **Name**: `hello-world` (or any name)
   - **URL**: `https://charts.bitnami.com/bitnami` (Bitnami charts repository)
   - **Enable OCI**: Leave unchecked
5. Click **Connect**

### Step 4: Create Application in ArgoCD

1. In ArgoCD UI, click **New App** or the **+** button
2. Fill in the application details:

   **General:**

   - **Application Name**: `hello-world`
   - **Project Name**: `default`
   - **Sync Policy**: `Manual` or `Automatic`

   **Source:**

   - **Repository**: Select the repository you just added in Step 3 from the dropdown (e.g., `hello-world` or the name you used)
     - The repository should appear in the dropdown since you connected it in Step 3
     - If it doesn't appear, go back to **Settings** → **Repositories** and verify it's connected
   - **Chart**: `nginx` (or any chart from Bitnami)
   - **Version**: `*` (latest) or specific version like `15.0.0`
   - **Helm**: Leave default values or add custom values

   **Destination:**

   - **Cluster URL**: Select the Production cluster (`gke-prod-production` or its Public endpoint IP) from the dropdown
     - If the Production cluster doesn't appear in the dropdown:
       - Go to **Settings** → **Clusters**
       - Verify `gke-prod-production` cluster is listed and shows as "Connected"
       - If not connected, run `./add-cluster-kubectl.sh` again
   - **Namespace**: `test` (the namespace you created on Production cluster)

3. Click **Create**
4. Click **Sync** to deploy the application to the Production cluster

### Step 5: Verify Deployment

Check the application status in ArgoCD UI or via CLI:

```bash
# Switch to GitOps cluster
gcloud container clusters get-credentials gke-prod-production --region us-east1 --project YOUR_PROJECT_ID

# Check application status
kubectl get application hello-world -n argocd

# Switch to Production cluster and verify pods
gcloud container clusters get-credentials gke-gitops-production --region us-east1 --project YOUR_PROJECT_ID
kubectl get pods -n test
kubectl get svc -n test
```

## 🗑️ Destroy Infrastructure

To destroy all infrastructure:

```bash
./destroy-all.sh
```

This script will:

1. Ask for confirmation (type `yes` to confirm)
2. Destroy ArgoCD cross-cluster resources
3. Destroy Production cluster
4. Destroy GitOps cluster
5. Destroy VPC and networking
6. Destroy secrets
7. Perform final cleanup
8. Verify all resources are deleted

**Warning:** This will delete all resources. Make sure you have backups if needed.

## 📁 Project Structure

```
GCP_Cross_Platform/
├── modules/
│   ├── gke-prod/          # Production GKE cluster module
│   │   ├── gke.tf         # GKE cluster definition
│   │   ├── node_pool.tf   # Node pool configuration
│   │   ├── service_accounts.tf  # GCP service accounts
│   │   ├── rbac_config.tf # Kubernetes RBAC
│   │   ├── datadog.tf     # Datadog agent
│   │   └── ...
│   └── gke-gitops/        # GitOps GKE cluster module
│       ├── gke.tf         # GKE cluster definition
│       ├── node_pool.tf   # Node pool configuration
│       ├── argocd.tf     # ArgoCD Helm release
│       ├── chartmuseum.tf # Chartmuseum Helm release
│       ├── datadog.tf     # Datadog agent
│       └── ...
├── vpc.tf                 # VPC network definition
├── subnet-*.tf           # Subnet definitions
├── gke.tf                # Production cluster module call
├── gke-gitops.tf         # GitOps cluster module call
├── secrets.tf            # GCP Secret Manager secrets
├── terraform.tfvars       # Variable values (not in git)
├── terraform.tfvars.example  # Example variables file
├── build-all.sh          # Build script
├── destroy-all.sh         # Destroy script
└── add-cluster-kubectl.sh # ArgoCD cluster configuration script
```

## 🔧 Configuration

### Node Pool Sizes

Default configuration (matching AWS setup):

- **Production**: 1 node (e2-medium: 2 vCPU, 4GB RAM)
- **GitOps**: 2 nodes (e2-standard-2: 2 vCPU, 8GB RAM per node)

Adjust in `terraform.tfvars`:

- `node_pool_new_desired_size`: Production desired nodes
- `gitops_node_pool_desired_size`: GitOps desired nodes

### Networking

- **VPC CIDR**: `10.0.0.0/16`
- **Production Subnets**: `10.0.20.0/22`, `10.0.24.0/22` (1024 IPs each)
- **GitOps Subnets**: `10.0.32.0/22`, `10.0.36.0/22` (1024 IPs each)
- **Public Subnets**: `10.0.101.0/24`, `10.0.102.0/24` (for NAT and LoadBalancers)

### Cluster Access

Clusters are accessible from `0.0.0.0/0` (all IPs) for tools like `k9s` and `kubectl`. This is configured via `master_authorized_networks_config` in the cluster definitions.

## 🔐 Security

- **Private Clusters**: Nodes have private IPs only
- **Workload Identity**: Kubernetes Service Accounts mapped to GCP Service Accounts
- **Network Policies**: Enabled via Calico
- **RBAC**: Kubernetes RBAC configured for admin users and ArgoCD access
- **Secrets**: Datadog API keys stored in GCP Secret Manager

## 📊 Monitoring

- **Datadog**: Monitoring agent deployed on both clusters
- **Google Managed Prometheus (GMP)**: Automatic monitoring via GCP
- **Cloud Logging**: Automatic log collection via Fluent Bit

## 🔗 Useful Commands

```bash
# Get cluster endpoints
gcloud container clusters describe gke-prod-production --region us-east1 --project YOUR_PROJECT_ID --format='value(endpoint)'
gcloud container clusters describe gke-gitops-production --region us-east1 --project YOUR_PROJECT_ID --format='value(endpoint)'

# List all nodes
kubectl get nodes

# Check ArgoCD applications
kubectl get applications -n argocd

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Switch cluster context
gcloud container clusters get-credentials gke-gitops-production --region us-east1 --project YOUR_PROJECT_ID
gcloud container clusters get-credentials gke-prod-production --region us-east1 --project YOUR_PROJECT_ID
```
