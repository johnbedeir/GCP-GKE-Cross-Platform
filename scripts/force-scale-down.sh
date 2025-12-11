#!/bin/bash
# NO NEED TO RUN THIS SCRIPT UNLESS YOU FACED AND ISSUE WITH SCALING ISSUES

# Force scale down nodes to match AWS configuration (1 prod, 2 gitops)

set -e

echo "🔽 Forcing scale down to match AWS configuration..."

scale_down_cluster() {
    local CLUSTER=$1
    local REGION=$2
    local NODE_POOL=$3
    local TARGET_SIZE=$4
    local MIN_SIZE=$5
    local MAX_SIZE=$6
    
    echo ""
    echo "=== Scaling down $CLUSTER ($NODE_POOL) to $TARGET_SIZE nodes ==="
    
    # Get current actual node count
    gcloud container clusters get-credentials $CLUSTER --region=$REGION --project=johnydev --quiet 2>&1 > /dev/null
    CURRENT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
    echo "   Current actual nodes: $CURRENT"
    echo "   Target size: $TARGET_SIZE nodes"
    
    if [ "$CURRENT" = "$TARGET_SIZE" ]; then
        echo "   ✅ Already at target size"
        return
    fi
    
    echo ""
    echo "   Step 1: Disabling autoscaling temporarily..."
    gcloud container node-pools update $NODE_POOL \
        --cluster=$CLUSTER \
        --region=$REGION \
        --project=johnydev \
        --no-enable-autoscaling \
        --quiet 2>&1 || echo "   ⚠️  Failed to disable autoscaling"
    
    echo "   Step 2: Resizing node pool to $TARGET_SIZE nodes..."
    gcloud container clusters resize $CLUSTER \
        --node-pool=$NODE_POOL \
        --num-nodes=$TARGET_SIZE \
        --region=$REGION \
        --project=johnydev \
        --quiet 2>&1 || echo "   ⚠️  Resize command failed"
    
    echo "   Step 3: Re-enabling autoscaling (min=$MIN_SIZE, max=$MAX_SIZE)..."
    gcloud container node-pools update $NODE_POOL \
        --cluster=$CLUSTER \
        --region=$REGION \
        --project=johnydev \
        --enable-autoscaling \
        --min-nodes=$MIN_SIZE \
        --max-nodes=$MAX_SIZE \
        --quiet 2>&1 || echo "   ⚠️  Failed to re-enable autoscaling"
    
    echo "   ✅ Scale down initiated"
    echo "   Note: This may take 5-10 minutes. Nodes will be drained and removed."
}

# Scale down prod to 1 node (matching AWS)
# Args: cluster, region, node_pool, target_size, min_size, max_size
scale_down_cluster "gke-prod-production" "us-east1" "prod" "1" "1" "3"

# Scale down GitOps to 2 nodes (matching AWS)
scale_down_cluster "gke-gitops-production" "us-east1" "gitops-prod" "2" "2" "4"

echo ""
echo "=========================================="
echo "🎉 Scale down initiated!"
echo "=========================================="
echo ""
echo "📝 Next steps:"
echo "   1. Wait for nodes to drain and be removed (5-10 minutes)"
echo "   2. Run 'terraform apply' to update the desired_size in Terraform state"
echo "   3. Verify with: kubectl get nodes"
echo ""
echo "⚠️  Note: If autoscaler keeps adding nodes back, check:"
echo "   - Pod distribution (pods might be preventing consolidation)"
echo "   - DaemonSets (they run on every node)"
echo "   - Pods with PVCs (can't be easily moved)"

