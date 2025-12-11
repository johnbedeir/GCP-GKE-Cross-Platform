#!/bin/bash
set -e

PROJECT="johnydev"
REGION="us-east1"

echo "Checking cluster status..."
gcloud container clusters describe gke-prod-production --region=$REGION --project=$PROJECT --format="value(status)" 2>&1

echo ""
echo "If cluster is stuck, you may need to:"
echo "1. Wait for current operation to complete"
echo "2. Or delete and recreate with smaller disk sizes (30GB instead of 100GB)"
echo ""
echo "Current disk usage calculation:"
echo "- Gitops: 6 nodes × 100GB = 600GB (exceeds quota)"
echo "- Prod default pool: 3 nodes × 100GB = 300GB"
echo "- Total: ~900GB (way over 500GB limit)"
echo ""
echo "After fix (30GB disks):"
echo "- Gitops: 6 nodes × 30GB = 180GB"
echo "- Prod: 2 nodes × 30GB = 60GB"
echo "- Total: 240GB (within 500GB quota)"
