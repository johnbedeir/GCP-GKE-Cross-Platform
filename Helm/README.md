# Training Helm Chart

A simple Helm chart for training purposes that deploys an nginx web server.

## ChartMuseum Operations

### Step 1: Package the Chart

First, package the Helm chart into a `.tgz` file:

```bash
# Navigate to the Helm directory
cd Helm

# Package the chart
helm package .

# This creates: training-chart-0.1.0.tgz
```

### Step 2: Get ChartMuseum LoadBalancer IP

Get the external IP address of the ChartMuseum service:

```bash
# Get the LoadBalancer IP
kubectl get svc chartmuseum -n chartmuseum

# Or extract just the IP
CHARTMUSEUM_IP=$(kubectl get svc chartmuseum -n chartmuseum -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "ChartMuseum IP: $CHARTMUSEUM_IP"
```

The default ChartMuseum port is `8080`.

### Step 3: Upload Chart to ChartMuseum

Upload the packaged chart to ChartMuseum using the LoadBalancer IP:

```bash
# Upload the chart
curl -X POST --data-binary "@training-chart-0.1.0.tgz" http://${CHARTMUSEUM_IP}:8080/api/charts

# Expected response: {"saved":true}
```

### Step 4: Verify Chart Upload

List all charts in ChartMuseum:

```bash
# List all charts
curl http://${CHARTMUSEUM_IP}:8080/api/charts

# Get specific chart info
curl http://${CHARTMUSEUM_IP}:8080/api/charts/training-chart/0.1.0
```

### Step 5: Delete Chart from ChartMuseum

To remove a chart from ChartMuseum:

```bash
# Delete a specific chart version
curl -X DELETE http://${CHARTMUSEUM_IP}:8080/api/charts/training-chart/0.1.0

# Expected response: {"deleted":true}
```

## Connecting ChartMuseum to ArgoCD

### Step 1: Get ChartMuseum LoadBalancer IP

```bash
# Get the ChartMuseum LoadBalancer IP
CHARTMUSEUM_IP=$(kubectl get svc chartmuseum -n chartmuseum -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "ChartMuseum URL: http://${CHARTMUSEUM_IP}:8080"
```

### Step 2: Add ChartMuseum as Helm Repository in ArgoCD

#### Option A: Using ArgoCD CLI

```bash
# Login to ArgoCD (get the ArgoCD server LoadBalancer IP first)
ARGOCD_IP=$(kubectl get svc -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
argocd login ${ARGOCD_IP} --insecure --username admin

# Get the initial admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login ${ARGOCD_IP} --insecure --username admin --password ${ARGOCD_PASSWORD}

# Add ChartMuseum as a Helm repository
argocd repo add http://${CHARTMUSEUM_IP}:8080 \
  --type helm \
  --name chartmuseum \
  --enable-oci
```

#### Option B: Using ArgoCD UI

1. Access ArgoCD UI:

   ```bash
   # Get ArgoCD LoadBalancer IP
   ARGOCD_IP=$(kubectl get svc -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
   echo "ArgoCD UI: http://${ARGOCD_IP}"
   ```

2. Login to ArgoCD UI:

   - Username: `admin`
   - Password: Get it with:
     ```bash
     kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
     ```

3. Navigate to **Settings** → **Repositories** → **Connect Repo**

4. Fill in the repository details:
   - **Type**: `Helm`
   - **Name**: `chartmuseum`
   - **URL**: `http://<CHARTMUSEUM_IP>:8080`
   - Click **Connect**

#### Option C: Using Kubernetes Secret (Declarative)

Create a Kubernetes secret for the Helm repository:

```bash
# Create a secret for ChartMuseum repository
kubectl create secret generic chartmuseum-repo \
  --from-literal=type=helm \
  --from-literal=url=http://${CHARTMUSEUM_IP}:8080 \
  -n argocd \
  --dry-run=client -o yaml | kubectl label --local -f - -o yaml argocd.argoproj.io/secret-type=repository | kubectl apply -f -
```
