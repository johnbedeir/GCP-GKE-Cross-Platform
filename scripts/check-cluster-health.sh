#!/bin/bash
# Comprehensive cluster health check

set -e

echo "🏥 Checking cluster health..."

check_cluster_health() {
    local CLUSTER=$1
    local REGION=$2
    
    echo ""
    echo "=========================================="
    echo "=== $CLUSTER ==="
    echo "=========================================="
    
    # Get cluster status
    echo ""
    echo "📊 Cluster Status:"
    STATUS=$(gcloud container clusters describe $CLUSTER --region=$REGION --project=johnydev --format="value(status)" 2>/dev/null)
    echo "   Status: $STATUS"
    
    if [ "$STATUS" = "RUNNING" ]; then
        echo "   ✅ Cluster is RUNNING (healthy)"
    else
        echo "   ⚠️  Cluster status: $STATUS"
    fi
    
    # Get credentials
    gcloud container clusters get-credentials $CLUSTER --region=$REGION --project=johnydev --quiet 2>&1 > /dev/null
    
    # Check nodes
    echo ""
    echo "🖥️  Node Status:"
    kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,READY:.status.conditions[-1].status 2>/dev/null | tail -n +2 | while read line; do
        if echo "$line" | grep -q "True"; then
            echo "   ✅ $line"
        else
            echo "   ⚠️  $line"
        fi
    done
    
    # Check for NotReady nodes
    NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready " | wc -l | tr -d ' ')
    if [ "$NOT_READY" -gt 0 ]; then
        echo "   ⚠️  $NOT_READY node(s) not ready"
        kubectl get nodes | grep -v " Ready "
    else
        echo "   ✅ All nodes are Ready"
    fi
    
    # Check pods
    echo ""
    echo "📦 Pod Status:"
    TOTAL_PODS=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l | tr -d ' ')
    RUNNING_PODS=$(kubectl get pods --all-namespaces --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
    FAILED_PODS=$(kubectl get pods --all-namespaces --field-selector=status.phase=Failed --no-headers 2>/dev/null | wc -l | tr -d ' ')
    PENDING_PODS=$(kubectl get pods --all-namespaces --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l | tr -d ' ')
    
    echo "   Total pods: $TOTAL_PODS"
    echo "   Running: $RUNNING_PODS"
    if [ "$FAILED_PODS" -gt 0 ]; then
        echo "   ⚠️  Failed: $FAILED_PODS"
        kubectl get pods --all-namespaces --field-selector=status.phase=Failed 2>/dev/null | head -5
    fi
    if [ "$PENDING_PODS" -gt 0 ]; then
        echo "   ⚠️  Pending: $PENDING_PODS"
        kubectl get pods --all-namespaces --field-selector=status.phase=Pending 2>/dev/null | head -5
    fi
    
    # Check for orphaned pods (blocking scale down)
    echo ""
    echo "🔍 Orphaned Pods (blocking scale down):"
    ORPHANED=$(kubectl get pods --all-namespaces -o json 2>/dev/null | \
        jq -r '.items[] | select((.metadata.ownerReferences // []) | length == 0 and .metadata.namespace != "kube-system") | "\(.metadata.namespace)/\(.metadata.name)"' 2>/dev/null || echo "")
    
    if [ -n "$ORPHANED" ]; then
        echo "   ⚠️  Found orphaned pods:"
        echo "$ORPHANED" | while read pod; do
            echo "     - $pod"
        done
    else
        echo "   ✅ No orphaned pods found"
    fi
    
    # Node pool info
    echo ""
    echo "📈 Node Pool Info:"
    gcloud container node-pools list --cluster=$CLUSTER --region=$REGION --project=johnydev \
        --format="table(name,autoscaling.minNodeCount,autoscaling.maxNodeCount,initialNodeCount,autoscaling.enabled)" 2>/dev/null
    
    # Check if at minimum (explains "can't scale down" message)
    echo ""
    echo "💡 Scaling Status:"
    CURRENT_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
    MIN_NODES=$(gcloud container node-pools list --cluster=$CLUSTER --region=$REGION --project=johnydev \
        --format="value(autoscaling.minNodeCount)" 2>/dev/null | head -1)
    
    echo "   Current nodes: $CURRENT_NODES"
    echo "   Minimum nodes: $MIN_NODES"
    
    if [ "$CURRENT_NODES" -le "$MIN_NODES" ]; then
        echo "   ℹ️  At or below minimum - 'can't scale down' message is normal"
    fi
}

# Check both clusters
check_cluster_health "gke-prod-production" "us-east1"
check_cluster_health "gke-gitops-production" "us-east1"

echo ""
echo "=========================================="
echo "🎉 Health check complete!"
echo "=========================================="
echo ""
echo "📝 Note: GCP console 'Health: 0%' is based on recommendations,"
echo "   not actual cluster health. If clusters show 'RUNNING' status,"
echo "   they are healthy. The percentage reflects recommendation compliance."

