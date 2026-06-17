#!/usr/bin/env bash
#
# Setup script for Scenario 4: Key Vault Secret Volume
#
# This script retrieves deployment outputs and generates the final
# Kubernetes manifests with the correct values substituted in.
#
# Usage:
#   ./setup.sh <resource-group> [deployment-name]   # deploy (intentionally broken)
#   ./setup.sh <resource-group> --fix-dns           # repair the private DNS fault
#
# By design this scenario deploys in a BROKEN state: after seeding the secret it
# injects an incorrect Key Vault private DNS record so the Secrets Store CSI
# driver cannot reach Key Vault and the secret volume fails to mount. Use
# --fix-dns to restore the correct record and resolve the scenario.
#
# Prerequisites:
#   - Azure CLI authenticated
#   - Infrastructure deployed via main.bicep
#   - kubectl configured for the AKS cluster

set -euo pipefail

DNS_ZONE="privatelink.vaultcore.azure.net"
WRONG_IP="10.1.16.250"   # in the PE subnet but with no listener -> mount times out

RESOURCE_GROUP="${1:?Usage: ./setup.sh <resource-group> [deployment-name] [--fix-dns]}"
shift
DEPLOYMENT_NAME="main"
MODE="break"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fix-dns|--fix)     MODE="fix" ;;
    --break-dns|--break) MODE="break" ;;
    *)                   DEPLOYMENT_NAME="$1" ;;
  esac
  shift
done
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Overwrite the Key Vault private DNS A record with a wrong IP (inject the fault).
break_dns() {
  az network private-dns record-set a delete \
    -g "$RESOURCE_GROUP" -z "$DNS_ZONE" -n "$KEY_VAULT_NAME" --yes >/dev/null 2>&1 || true
  # Low TTL so the bad record (and later the fix) propagates quickly for the demo.
  az network private-dns record-set a create \
    -g "$RESOURCE_GROUP" -z "$DNS_ZONE" -n "$KEY_VAULT_NAME" --ttl 10 --output none
  az network private-dns record-set a add-record \
    -g "$RESOURCE_GROUP" -z "$DNS_ZONE" -n "$KEY_VAULT_NAME" -a "$WRONG_IP" --output none
  # Flush the in-cluster DNS cache so nodes don't keep resolving the old good IP.
  kubectl -n kube-system rollout restart deployment/coredns >/dev/null 2>&1 || true
}

# Restore the correct A record from the Key Vault private endpoint (the fix).
fix_dns() {
  local nic_id correct_ip
  nic_id=$(az network private-endpoint show \
    -g "$RESOURCE_GROUP" -n "${KEY_VAULT_NAME}-pe" \
    --query "networkInterfaces[0].id" -o tsv 2>/dev/null)
  if [[ -n "$nic_id" ]]; then
    correct_ip=$(az network nic show --ids "$nic_id" \
      --query "ipConfigurations[0].privateIPAddress" -o tsv 2>/dev/null)
  fi
  if [[ -z "${correct_ip:-}" ]]; then
    echo "ERROR: could not determine the private endpoint IP for ${KEY_VAULT_NAME}-pe." >&2
    exit 1
  fi
  az network private-dns record-set a delete \
    -g "$RESOURCE_GROUP" -z "$DNS_ZONE" -n "$KEY_VAULT_NAME" --yes >/dev/null 2>&1 || true
  az network private-dns record-set a create \
    -g "$RESOURCE_GROUP" -z "$DNS_ZONE" -n "$KEY_VAULT_NAME" --ttl 3600 --output none
  az network private-dns record-set a add-record \
    -g "$RESOURCE_GROUP" -z "$DNS_ZONE" -n "$KEY_VAULT_NAME" -a "$correct_ip" --output none
  echo "  Restored ${KEY_VAULT_NAME} -> ${correct_ip}"
  # Flush DNS cache and force a fresh mount attempt.
  kubectl -n kube-system rollout restart deployment/coredns >/dev/null 2>&1 || true
  kubectl rollout restart deployment/keyvault-demo -n scenario-keyvault >/dev/null 2>&1 || true
}

echo "=== Scenario 4: Key Vault Secret Volume Setup ==="
echo ""

# Get deployment outputs
echo "[1/5] Retrieving deployment outputs..."
OUTPUTS=$(az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --query properties.outputs \
  --output json)

KEY_VAULT_NAME=$(echo "$OUTPUTS" | jq -r '.keyVaultName.value')
WORKLOAD_IDENTITY_CLIENT_ID=$(echo "$OUTPUTS" | jq -r '.workloadIdentityClientId.value')
TENANT_ID=$(echo "$OUTPUTS" | jq -r '.tenantId.value')
ACR_LOGIN_SERVER=$(echo "$OUTPUTS" | jq -r '.acrLoginServer.value // empty')

# Fall back to discovering the registry if the deployment predates the ACR output.
if [[ -z "$ACR_LOGIN_SERVER" ]]; then
  ACR_LOGIN_SERVER=$(az acr list -g "$RESOURCE_GROUP" --query "[0].loginServer" -o tsv)
fi

echo "  Key Vault Name:            $KEY_VAULT_NAME"
echo "  Workload Identity Client:  $WORKLOAD_IDENTITY_CLIENT_ID"
echo "  Tenant ID:                 $TENANT_ID"
echo "  ACR Login Server:          $ACR_LOGIN_SERVER"
echo ""

# Fix mode: restore the correct private DNS record and exit.
if [[ "$MODE" == "fix" ]]; then
  echo "[fix] Restoring the Key Vault private DNS record..."
  fix_dns
  echo ""
  echo "=== DNS repaired. The pod should mount the secret on its next attempt. ==="
  echo "Watch it recover:"
  echo "  kubectl get pods -n scenario-keyvault -w"
  exit 0
fi

# Ensure the current user has Key Vault Secrets Officer role to seed secrets
echo "[2/5] Seeding demo secret into Key Vault..."
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

# ─── Inject the fault: break the Key Vault private DNS record ─────────────────
# The infrastructure is otherwise healthy. We overwrite the private DNS A record
# for the Key Vault so its FQDN resolves to a WRONG private IP that has no
# listener. The Secrets Store CSI driver can no longer reach Key Vault, so the
# secret volume fails to mount and the pod is stuck in ContainerCreating with a
# FailedMount event. This simulates a common Azure misconfiguration: an
# incorrect / stale private DNS entry for a private endpoint.
echo "[3/5] Breaking Key Vault private DNS (injecting the fault)..."
break_dns
echo "  Record '${KEY_VAULT_NAME}' in ${DNS_ZONE} now points to ${WRONG_IP} (wrong)."
echo ""

# Generate the deployment manifest
echo "[4/5] Generating deployment manifest..."
sed -e "s|\${WORKLOAD_IDENTITY_CLIENT_ID}|${WORKLOAD_IDENTITY_CLIENT_ID}|g" \
    -e "s|\${KEY_VAULT_NAME}|${KEY_VAULT_NAME}|g" \
    -e "s|\${TENANT_ID}|${TENANT_ID}|g" \
    -e "s|\${ACR_LOGIN_SERVER}|${ACR_LOGIN_SERVER}|g" \
    "${SCRIPT_DIR}/deployment.yaml" > "${SCRIPT_DIR}/deployment-generated.yaml"

echo "  Generated: deployment-generated.yaml"
echo ""

# Apply and force a fresh mount attempt so the broken DNS takes effect
echo "[5/5] Applying Kubernetes manifests..."
kubectl apply -f "${SCRIPT_DIR}/deployment-generated.yaml"
# Delete any existing pod so a brand-new mount attempt hits the broken DNS
# (an already-running pod would keep its working mount and cached resolution).
kubectl delete pods -n scenario-keyvault -l app=keyvault-demo --ignore-not-found --wait=false >/dev/null 2>&1 || true
kubectl rollout restart deployment/keyvault-demo -n scenario-keyvault >/dev/null 2>&1 || true
echo ""

echo "=== Setup Complete (the pod will FAIL to mount the secret) ==="
echo ""
echo "Expected: the pod stays in ContainerCreating with a FailedMount event because"
echo "${KEY_VAULT_NAME}.vault.azure.net now resolves to the wrong IP (${WRONG_IP})."
echo ""
echo "Monitor the pod:"
echo "  kubectl get pods -n scenario-keyvault -w"
echo ""
echo "Troubleshoot with Copilot:"
echo "  POD=\$(kubectl get pods -n scenario-keyvault -l app=keyvault-demo -o jsonpath='{.items[0].metadata.name}')"
echo "  copilot -p \"Explain these pod events in plain English and how to fix them:"
echo ""
echo "  \$(kubectl describe pod \"\$POD\" -n scenario-keyvault)\""
echo ""
echo "When you are ready to FIX it (restore the correct private DNS record):"
echo "  ./setup.sh ${RESOURCE_GROUP} --fix-dns"
