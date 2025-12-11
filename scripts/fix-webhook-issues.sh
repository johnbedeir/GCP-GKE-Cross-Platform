#!/bin/bash
# NO NEED TO RUN THIS SCRIPT UNLESS YOU FACED AND ISSUE WITH WEBHOOK ISSUES

# Fix webhook issues - find and remove webhooks with unavailable endpoints

set -e

echo "🔍 Checking for webhooks with unavailable endpoints..."

# Function to check and fix webhook issues
check_webhooks() {
    local CLUSTER=$1
    local REGION=$2
    
    echo ""
    echo "=== Checking $CLUSTER ==="
    gcloud container clusters get-credentials $CLUSTER --region=$REGION --project=johnydev --quiet
    
    # Check validating webhooks
    echo ""
    echo "   Validating Webhooks:"
    VALIDATING=$(kubectl get validatingwebhookconfigurations -o json 2>/dev/null || echo '{"items":[]}')
    
    echo "$VALIDATING" | jq -r '.items[] | .metadata.name as $name | .webhooks[]? | 
        select(.clientConfig.service != null) | 
        "\($name) -> \(.clientConfig.service.namespace)/\(.clientConfig.service.name)"' 2>/dev/null | \
    while read webhook_info; do
        if [ -n "$webhook_info" ]; then
            WEBHOOK_NAME=$(echo "$webhook_info" | cut -d' ' -f1)
            SERVICE_PATH=$(echo "$webhook_info" | cut -d' ' -f3)
            NS=$(echo "$SERVICE_PATH" | cut -d'/' -f1)
            SVC=$(echo "$SERVICE_PATH" | cut -d'/' -f2)
            
            # Check if service exists
            if ! kubectl get service "$SVC" -n "$NS" &>/dev/null; then
                echo "     ⚠️  $webhook_info - Service NOT FOUND"
                echo "        Would delete: validatingwebhookconfiguration/$WEBHOOK_NAME"
            else
                echo "     ✅ $webhook_info - Service exists"
            fi
        fi
    done
    
    # Check mutating webhooks
    echo ""
    echo "   Mutating Webhooks:"
    MUTATING=$(kubectl get mutatingwebhookconfigurations -o json 2>/dev/null || echo '{"items":[]}')
    
    echo "$MUTATING" | jq -r '.items[] | .metadata.name as $name | .webhooks[]? | 
        select(.clientConfig.service != null) | 
        "\($name) -> \(.clientConfig.service.namespace)/\(.clientConfig.service.name)"' 2>/dev/null | \
    while read webhook_info; do
        if [ -n "$webhook_info" ]; then
            WEBHOOK_NAME=$(echo "$webhook_info" | cut -d' ' -f1)
            SERVICE_PATH=$(echo "$webhook_info" | cut -d' ' -f3)
            NS=$(echo "$SERVICE_PATH" | cut -d'/' -f1)
            SVC=$(echo "$SERVICE_PATH" | cut -d'/' -f2)
            
            # Check if service exists
            if ! kubectl get service "$SVC" -n "$NS" &>/dev/null; then
                echo "     ⚠️  $webhook_info - Service NOT FOUND"
                echo "        Would delete: mutatingwebhookconfiguration/$WEBHOOK_NAME"
            else
                echo "     ✅ $webhook_info - Service exists"
            fi
        fi
    done
}

# Check both clusters
check_webhooks "gke-prod-production" "us-east1"
check_webhooks "gke-gitops-production" "us-east1"

echo ""
echo "💡 To fix webhooks with unavailable endpoints:"
echo "   1. Identify the webhook name from above"
echo "   2. Delete it: kubectl delete validatingwebhookconfiguration <name>"
echo "   OR: kubectl delete mutatingwebhookconfiguration <name>"
echo ""
echo "   Example:"
echo "   kubectl delete validatingwebhookconfiguration <webhook-name>"

