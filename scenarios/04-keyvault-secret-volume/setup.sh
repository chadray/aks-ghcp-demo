#!/usr/bin/env bash
#
# Setup script for Scenario 4: Key Vault Secret Volume
#
# This script retrieves deployment outputs and generates the final
# Kubernetes manifests with the correct values substituted in.
#
# Usage:
#   ./setup.sh <resource-group>
#
# Prerequisites:
#   - Azure CLI authenticated
#   - Infrastructure deployed via main.bicep
#   - kubectl configured for the AKS cluster

set -euo pipefail

RESOURCE_GROUP="${1:?Usage: ./setup.sh <resource-group>}"
DEPLOYMENT_NAME="${2:-main}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Scenario 4: Key Vault Secret Volume Setup ==="
echo ""

# Get deployment outputs
echo "[1/4] Retrieving deployment outputs..."
OUTPUTS=$(az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --query properties.outputs \
  --output json)

KEY_VAULT_NAME=$(echo "$OUTPUTS" | jq -r '.keyVaultName.value')
WORKLOAD_IDENTITY_CLIENT_ID=$(echo "$OUTPUTS" | jq -r '.workloadIdentityClientId.value')
TENANT_ID=$(echo "$OUTPUTS" | jq -r '.tenantId.value')

echo "  Key Vault Name:            $KEY_VAULT_NAME"
echo "  Workload Identity Client:  $WORKLOAD_IDENTITY_CLIENT_ID"
echo "  Tenant ID:                 $TENANT_ID"
echo ""

# Ensure the current user has Key Vault Secrets Officer role to seed secrets
echo "[2/4] Seeding demo secret into Key Vault..."
CURRENT_USER_OID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null)
KV_RESOURCE_ID=$(az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv)

az role assignment create \
  --role "Key Vault Secrets Officer" \
  --assignee-object-id "$CURRENT_USER_OID" \
  --assignee-principal-type User \
  --scope "$KV_RESOURCE_ID" \
  --output none 2>/dev/null || true

# Temporarily allow public access and set default action to Allow to seed the secret
az keyvault update --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" \
  --public-network-access Enabled --default-action Allow --output none 2>/dev/null || true

# Wait for network and RBAC changes to propagate
sleep 15

az keyvault secret set \
  --vault-name "$KEY_VAULT_NAME" \
  --name "demo-secret" \
  --value "SuperSecretValue-$(date +%s)" \
  --output none

# Re-lock: set default action back to Deny and disable public access
az keyvault update --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" \
  --default-action Deny --output none 2>/dev/null || true
az keyvault update --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" \
  --public-network-access Disabled --output none 2>/dev/null || true

echo "  Secret 'demo-secret' created."
echo ""

# Generate the deployment manifest
echo "[3/4] Generating deployment manifest..."
sed -e "s|\${WORKLOAD_IDENTITY_CLIENT_ID}|${WORKLOAD_IDENTITY_CLIENT_ID}|g" \
    -e "s|\${KEY_VAULT_NAME}|${KEY_VAULT_NAME}|g" \
    -e "s|\${TENANT_ID}|${TENANT_ID}|g" \
    "${SCRIPT_DIR}/deployment.yaml" > "${SCRIPT_DIR}/deployment-generated.yaml"

echo "  Generated: deployment-generated.yaml"
echo ""

# Apply the manifests
echo "[4/4] Applying Kubernetes manifests..."
kubectl apply -f "${SCRIPT_DIR}/deployment-generated.yaml"
echo ""

echo "=== Setup Complete ==="
echo ""
echo "Monitor the pod:"
echo "  kubectl get pods -n scenario-keyvault -w"
echo ""
echo "View logs:"
echo "  kubectl logs -n scenario-keyvault -l app=keyvault-demo -f"
echo ""
echo "Troubleshoot with Copilot:"
echo "  copilot -p \"Explain these pod events in plain English and how to fix them:"
echo ""
echo "  \$(kubectl describe pod -n scenario-keyvault -l app=keyvault-demo)\""
