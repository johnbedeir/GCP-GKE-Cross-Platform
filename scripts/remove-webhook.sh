#!/bin/bash
# NO NEED TO RUN THIS SCRIPT UNLESS YOU FACED AND ISSUE WITH WEBHOOK ISSUES

# Remove the clusterpodmonitorings webhook from GMP operator (RISKY - only if needed)

set -e

echo "⚠️  WARNING: This will remove the clusterpodmonitorings webhook from GMP operator"
echo "   This could break Google Managed Prometheus monitoring!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Removing clusterpodmonitorings webhook from gmp-operator..."

gcloud container clusters get-credentials gke-gitops-production --region=us-east1 --project=johnydev --quiet

# Get current config, remove the webhook, apply
kubectl get validatingwebhookconfigurations gmp-operator.gmp-system.monitoring.googleapis.com -o json | \
    jq 'del(.webhooks[] | select(.name | contains("clusterpodmonitorings")))' | \
    kubectl apply -f -

echo ""
echo "✅ Webhook removed. Check GCP console to see if recommendation is gone."
echo ""
echo "⚠️  If GMP monitoring breaks, you may need to reinstall GMP operator."

