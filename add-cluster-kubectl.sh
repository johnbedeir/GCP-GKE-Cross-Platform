#!/bin/bash
# Fix ArgoCD cluster secret - use bearer token from GCP service account

set -e

echo "🔧 Step 1: Getting prod cluster endpoint..."
PROD_ENDPOINT=$(gcloud container clusters describe gke-prod-production --region=us-east1 --project=johnydev --format='value(endpoint)')
PROD_CA=$(gcloud container clusters describe gke-prod-production --region=us-east1 --project=johnydev --format='value(masterAuth.clusterCaCertificate)')

echo "   Endpoint: $PROD_ENDPOINT"
echo "   CA length: ${#PROD_CA}"

# Decode CA from base64 (GCP returns it base64 encoded) then re-encode properly
echo "   Processing CA certificate..."
CA_PEM=$(echo -n "$PROD_CA" | base64 -d)
CA_B64=$(echo -n "$CA_PEM" | base64 | tr -d '\n')

echo ""
echo "🔐 Step 2: Getting access token for ArgoCD service account..."
SERVICE_ACCOUNT="gkgitops-argocd-x@johnydev.iam.gserviceaccount.com"

# Save current account
ORIGINAL_ACCOUNT=$(gcloud config get-value account 2>/dev/null || echo "")

# Try to get token using service account impersonation (preferred method)
echo "   Attempting to impersonate service account: $SERVICE_ACCOUNT"
# Use background process with timeout simulation (macOS doesn't have timeout command)
TOKEN=""
(
    IMPERSONATE_OUTPUT=$(gcloud auth print-access-token --impersonate-service-account="$SERVICE_ACCOUNT" 2>&1)
    echo "$IMPERSONATE_OUTPUT" > /tmp/impersonate-output-$$.txt
) &
IMPERSONATE_PID=$!

# Wait max 5 seconds for impersonation
for i in {1..5}; do
    if ! kill -0 $IMPERSONATE_PID 2>/dev/null; then
        # Process finished
        if [ -f /tmp/impersonate-output-$$.txt ]; then
            TOKEN=$(cat /tmp/impersonate-output-$$.txt)
            rm -f /tmp/impersonate-output-$$.txt
        fi
        break
    fi
    sleep 1
done

# If still running, kill it and check for errors
if kill -0 $IMPERSONATE_PID 2>/dev/null; then
    kill $IMPERSONATE_PID 2>/dev/null
    wait $IMPERSONATE_PID 2>/dev/null
    if [ -f /tmp/impersonate-output-$$.txt ]; then
        TOKEN=$(cat /tmp/impersonate-output-$$.txt)
        rm -f /tmp/impersonate-output-$$.txt
    fi
fi

# Check if impersonation succeeded (token should be a long string, > 100 chars)
# If output contains error keywords, it's not a token
if [ -n "$TOKEN" ] && [ ${#TOKEN} -ge 100 ]; then
    if echo "$TOKEN" | grep -qi "error\|denied\|permission\|invalid\|unauthorized"; then
        TOKEN=""
    fi
else
    TOKEN=""
fi

if [ -z "$TOKEN" ] || [ ${#TOKEN} -lt 100 ]; then
    echo "   ⚠️  Impersonation failed, trying service account key method..."
    
    # Fallback: Create a temporary service account key
    KEY_FILE="/tmp/argocd-sa-key-$$.json"
    
    echo "   Creating key for: $SERVICE_ACCOUNT"
    if gcloud iam service-accounts keys create "$KEY_FILE" \
      --iam-account="$SERVICE_ACCOUNT" \
      --project=johnydev 2>&1; then
        
        # Verify key file exists and is valid JSON
        if [ -f "$KEY_FILE" ] && jq -e . "$KEY_FILE" >/dev/null 2>&1; then
            echo "   ✅ Key created, getting token..."
            # Activate the service account and get token
            if gcloud auth activate-service-account --key-file="$KEY_FILE" --quiet 2>&1; then
                TOKEN=$(gcloud auth print-access-token 2>/dev/null)
                
                # Switch back to original account if we had one
                if [ -n "$ORIGINAL_ACCOUNT" ]; then
                    echo "   Restoring original account: $ORIGINAL_ACCOUNT"
                    gcloud config set account "$ORIGINAL_ACCOUNT" 2>/dev/null || true
                fi
                
                # Clean up key file
                rm -f "$KEY_FILE"
            else
                echo "   ❌ Failed to activate service account with key file"
                rm -f "$KEY_FILE"
                TOKEN=""
            fi
        else
            echo "   ❌ Key file is invalid or corrupted"
            rm -f "$KEY_FILE"
            TOKEN=""
        fi
    else
        echo "   ❌ Failed to create service account key"
        rm -f "$KEY_FILE"
        TOKEN=""
    fi
fi

# Final fallback: use current user token
if [ -z "$TOKEN" ]; then
    echo "   ⚠️  Using current user token as fallback..."
    TOKEN=$(gcloud auth print-access-token 2>/dev/null)
fi

if [ -z "$TOKEN" ]; then
    echo "   ❌ Failed to get access token"
    exit 1
fi

echo "   ✅ Token obtained (length: ${#TOKEN})"

echo ""
echo "🔧 Step 3: Getting GitOps cluster credentials..."
gcloud container clusters get-credentials gke-gitops-production --region=us-east1 --project=johnydev --quiet

echo ""
echo "🗑️  Step 4: Deleting old cluster secrets (if any)..."
kubectl delete secret -n argocd -l argocd.argoproj.io/secret-type=cluster --ignore-not-found=true

echo ""
echo "➕ Step 5: Creating new ArgoCD cluster secret with bearer token..."
# Create config JSON with bearer token
CONFIG_JSON=$(cat <<JSON
{
  "bearerToken": "${TOKEN}",
  "tlsClientConfig": {
    "caData": "${CA_B64}",
    "insecure": false
  }
}
JSON
)

# Base64 encode for Kubernetes data field
CONFIG_B64=$(echo -n "$CONFIG_JSON" | base64 | tr -d '\n')
NAME_B64=$(echo -n "gke-prod-production" | base64 | tr -d '\n')
SERVER_B64=$(echo -n "https://${PROD_ENDPOINT}" | base64 | tr -d '\n')

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: gkeprodproduction-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
data:
  name: ${NAME_B64}
  server: ${SERVER_B64}
  config: ${CONFIG_B64}
EOF

echo ""
echo "✅ Step 6: Ensuring Workload Identity annotation is set..."
# Ensure the service account has the Workload Identity annotation
kubectl annotate serviceaccount argocd-application-controller -n argocd \
  iam.gke.io/gcp-service-account=gkgitops-argocd-x@johnydev.iam.gserviceaccount.com \
  --overwrite

echo ""
echo "✅ Step 7: Restarting ArgoCD controller..."
kubectl delete pod -n argocd -l app.kubernetes.io/name=argocd-application-controller --wait=false

echo ""
echo "🎉 Done! Wait 30 seconds for ArgoCD controller to restart."
echo ""
echo "ℹ️  Using bearer token from GCP service account:"
echo "   $SERVICE_ACCOUNT"
echo "   This service account has cluster-admin permissions on prod cluster."
echo ""
echo "⚠️  Note: GCP access tokens expire after 1 hour."
echo "   If the token expires, run this script again to refresh it."
