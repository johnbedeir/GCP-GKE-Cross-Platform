#!/bin/bash
# NO NEED TO RUN THIS SCRIPT UNLESS YOU FACED AND ISSUE WITH WEBHOOK ENDPOINTS

# Fix webhook endpoints per Google documentation
# https://docs.cloud.google.com/kubernetes-engine/docs/how-to/optimize-webhooks#no-available-endpoints

set -e

echo "🔍 Troubleshooting webhook endpoints per Google documentation..."

fix_webhook_endpoints() {
    local CLUSTER=$1
    local REGION=$2
    
    echo ""
    echo "=========================================="
    echo "=== $CLUSTER ==="
    echo "=========================================="
    
    gcloud container clusters get-credentials $CLUSTER --region=$REGION --project=johnydev --quiet
    
    echo ""
    echo "Step 1: Checking Service (per Google docs)..."
    kubectl describe svc gmp-operator -n gmp-system 2>/dev/null | grep -A 5 "Endpoints:" || echo "   ⚠️  Service or namespace not found"
    
    echo ""
    echo "Step 2: Checking Deployment and Pods (per Google docs)..."
    kubectl get deployment -n gmp-system 2>/dev/null | grep gmp-operator || echo "   ⚠️  Deployment not found"
    
    echo ""
    echo "Step 3: Checking Pod status..."
    kubectl get pods -n gmp-system -o wide 2>/dev/null | grep gmp-operator || echo "   ⚠️  Pods not found"
    
    echo ""
    echo "Step 4: Checking Service Endpoints..."
    ENDPOINTS=$(kubectl get endpoints gmp-operator -n gmp-system -o jsonpath='{.subsets[*].addresses[*].targetRef.name}' 2>/dev/null || echo "")
    
    if [ -z "$ENDPOINTS" ]; then
        echo "   ⚠️  No endpoints found - this is the problem!"
        echo ""
        echo "   Checking why pods aren't backing the service..."
        kubectl get pods -n gmp-system -l app=gmp-operator 2>/dev/null || \
        kubectl get pods -n gmp-system | grep gmp-operator 2>/dev/null || \
        echo "   No gmp-operator pods found"
        
        echo ""
        echo "   Checking pod logs for errors..."
        kubectl logs -n gmp-system -l app=gmp-operator --tail=10 2>/dev/null | tail -5 || echo "   Could not retrieve logs"
    else
        echo "   ✅ Endpoints found: $ENDPOINTS"
        echo ""
        echo "   According to Google docs, if endpoints exist but GCP still shows"
        echo "   the warning, it should resolve within 24 hours."
        echo ""
        echo "   To force a refresh, restarting gmp-operator pods..."
        kubectl rollout restart deployment gmp-operator -n gmp-system 2>/dev/null || \
        kubectl delete pod -n gmp-system -l app=gmp-operator 2>/dev/null || \
        echo "   Could not restart pods"
        
        echo "   Waiting 10 seconds for pods to restart..."
        sleep 10
        
        echo ""
        echo "   Verifying endpoints after restart..."
        kubectl get endpoints gmp-operator -n gmp-system 2>/dev/null | grep -v "NAME" || echo "   Still no endpoints"
    fi
}

# Fix both clusters
fix_webhook_endpoints "gke-prod-production" "us-east1"
fix_webhook_endpoints "gke-gitops-production" "us-east1"

echo ""
echo "=========================================="
echo "🎉 Troubleshooting complete!"
echo "=========================================="
echo ""
echo "📝 According to Google documentation:"
echo "   https://docs.cloud.google.com/kubernetes-engine/docs/how-to/optimize-webhooks#no-available-endpoints"
echo ""
echo "   'After you implement the instructions and the webhooks are correctly"
echo "   configured, the recommendation is resolved within 24 hours and no"
echo "   longer appears in the console.'"
echo ""
echo "   If endpoints exist and pods are running, the recommendation should"
echo "   auto-resolve. You can also dismiss it in the console."

