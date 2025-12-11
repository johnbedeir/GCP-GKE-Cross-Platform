#!/bin/bash
# NO NEED TO RUN THIS SCRIPT UNLESS YOU FACED AND ISSUE WITH SCALING ISSUES

# Fix scaling issues in GKE clusters

set -e

echo "🔍 Checking for scaling issues..."

# Function to find and clean orphaned pods
fix_orphaned_pods() {
    local CLUSTER=$1
    local REGION=$2
    
    echo ""
    echo "=== Checking $CLUSTER for orphaned pods ==="
    gcloud container clusters get-credentials $CLUSTER --region=$REGION --project=johnydev --quiet
    
    # Find pods without owner references (orphaned pods)
    ORPHANED=$(kubectl get pods --all-namespaces -o json 2>/dev/null | \
        jq -r '.items[] | select((.metadata.ownerReferences // []) | length == 0 and .metadata.namespace != "kube-system") | "\(.metadata.namespace)/\(.metadata.name)"' 2>/dev/null || echo "")
    
    if [ -n "$ORPHANED" ]; then
        echo "   ⚠️  Found orphaned pods (pods without controllers):"
        echo "$ORPHANED" | while read pod; do
            NS=$(echo $pod | cut -d'/' -f1)
            NAME=$(echo $pod | cut -d'/' -f2)
            echo "     - $pod"
            echo "       Deleting..."
            kubectl delete pod "$NAME" -n "$NS" --grace-period=0 --force 2>/dev/null || true
        done
        echo "   ✅ Orphaned pods cleaned up"
    else
        echo "   ✅ No orphaned pods found"
    fi
}

# Function to show node pool recommendations
show_recommendations() {
    local CLUSTER=$1
    local REGION=$2
    
    echo ""
    echo "=== $CLUSTER Node Pool Status ==="
    gcloud container node-pools list --cluster=$CLUSTER --region=$REGION --project=johnydev \
        --format="table(name,autoscaling.minNodeCount,autoscaling.maxNodeCount,initialNodeCount)" 2>/dev/null
    
    echo ""
    echo "   💡 Recommendations:"
    echo "      - 'Can't scale down when node group size exceeded minimum' is normal"
    echo "      - This means the cluster is at or above minimum node count"
    echo "      - To allow more aggressive scale-down, reduce min_node_count in terraform.tfvars"
    echo "      - Current settings are good for production (min=1 for prod, min=2 for gitops)"
}

# Fix orphaned pods in both clusters
fix_orphaned_pods "gke-prod-production" "us-east1"
fix_orphaned_pods "gke-gitops-production" "us-east1"

# Show recommendations
show_recommendations "gke-prod-production" "us-east1"
show_recommendations "gke-gitops-production" "us-east1"

echo ""
echo "🎉 Done! Scaling issues should be resolved."
echo ""
echo "📝 Note: The 'can't scale down' message is informational and normal"
echo "   when current node count is at or above the minimum."

