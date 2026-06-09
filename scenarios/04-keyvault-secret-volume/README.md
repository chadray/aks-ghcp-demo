# Scenario 4: Key Vault Secret Volume

## Overview

This scenario demonstrates how to securely mount Azure Key Vault secrets into a Kubernetes pod using:

- **Azure Key Vault** with RBAC authorization and a private endpoint
- **Secrets Store CSI Driver** to mount secrets as volumes
- **Workload Identity** for pod-level authentication (no stored credentials)
- **Private Endpoint** so all Key Vault traffic stays on the Azure backbone network

The pod uses a federated identity credential to authenticate to Key Vault without any passwords or connection strings. The secret is mounted as a file inside the container.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  AKS Cluster                                        │
│                                                     │
│  ┌─────────────────────────────────────────────┐    │
│  │ Pod (keyvault-demo)                         │    │
│  │  - label: azure.workload.identity/use=true  │    │
│  │  - serviceAccount: keyvault-demo-sa         │    │
│  │  - volume: secrets-store (CSI)              │    │
│  │  - mount: /mnt/secrets/demo-secret          │    │
│  └──────────────┬──────────────────────────────┘    │
│                 │                                    │
│  ┌──────────────▼──────────────────────────────┐    │
│  │ Secrets Store CSI Driver                    │    │
│  │  - SecretProviderClass                      │    │
│  │  - Uses workload identity (clientID)        │    │
│  └──────────────┬──────────────────────────────┘    │
│                 │                                    │
└─────────────────┼────────────────────────────────────┘
                  │ Private Endpoint
                  │ (privatelink.vaultcore.azure.net)
                  │
┌─────────────────▼────────────────────────────────────┐
│  Azure Key Vault                                     │
│  - RBAC authorization                                │
│  - Public access disabled                            │
│  - Secret: demo-secret                               │
└──────────────────────────────────────────────────────┘
```

## How It Works

1. The AKS cluster has the **Secrets Store CSI Driver** addon enabled and **workload identity** configured
2. A **User Assigned Managed Identity** is created with the **Key Vault Secrets User** role on the Key Vault
3. A **Federated Identity Credential** links the Kubernetes ServiceAccount to the managed identity
4. The pod's ServiceAccount is annotated with the managed identity's client ID
5. When the pod starts, the CSI driver authenticates to Key Vault using the federated token and mounts the secret as a file
6. All traffic to Key Vault goes through the **private endpoint** in the VNet

## Prerequisites

- Infrastructure deployed via `infrastructure/main.bicep`
- `kubectl` configured for the AKS cluster
- Azure CLI authenticated with access to the resource group
- `jq` installed (for the setup script)

## Quick Start

### 1. Deploy Infrastructure (if not done)

```bash
cd infrastructure
az deployment group create \
  --resource-group ghcp-demo-rg \
  --template-file main.bicep \
  --parameters parameters.json

az aks get-credentials \
  --resource-group ghcp-demo-rg \
  --name aks-ghcp-demo \
  --overwrite-existing
```

**PowerShell equivalent:**

```powershell
cd infrastructure
az deployment group create `
  --resource-group ghcp-demo-rg `
  --template-file main.bicep `
  --parameters parameters.json

az aks get-credentials `
  --resource-group ghcp-demo-rg `
  --name aks-ghcp-demo `
  --overwrite-existing
```

### 2. Run the Setup Script

The setup script retrieves deployment outputs, seeds a secret into Key Vault, and generates/applies the Kubernetes manifests:

```bash
cd scenarios/04-keyvault-secret-volume
chmod +x setup.sh
./setup.sh ghcp-demo-rg
```

**PowerShell equivalent:**

```powershell
cd scenarios/04-keyvault-secret-volume
# If script execution is blocked, allow it for this session:
# Set-ExecutionPolicy -Scope Process Bypass
./setup.ps1 -ResourceGroup ghcp-demo-rg
```

### 3. Monitor the Pod

```bash
kubectl get pods -n scenario-keyvault -w
```

When working correctly, the pod should be in `Running` state with the secret mounted:

```bash
$ kubectl logs -n scenario-keyvault -l app=keyvault-demo
=== Key Vault Secret Volume Demo ===
Process ID: 1
Looking for secret at: /mnt/secrets/demo-secret

[OK] Secret mounted successfully. Value length: 28 chars
[OK] Secret preview: Supe****
[INFO] Next check in 30 seconds...
```

## Diagnosing Issues with Copilot CLI

### The Pod Won't Start

```bash
# Check pod status
kubectl get pods -n scenario-keyvault | gh copilot explain

# Describe the pod for events
kubectl describe pod -n scenario-keyvault -l app=keyvault-demo | gh copilot explain

# Check CSI driver events
kubectl get events -n scenario-keyvault --sort-by='.lastTimestamp' | gh copilot explain
```

### Common Failure Modes

#### SecretProviderClass Auth Failure

If workload identity is misconfigured, you'll see events like:

```
Warning  FailedMount  ... failed to mount secrets store objects ...
```

**Check:**
- ServiceAccount annotation matches the managed identity client ID
- Federated identity credential exists and references the correct SA
- Pod has label `azure.workload.identity/use: "true"`

#### Key Vault Access Denied

If RBAC roles are missing:

```
Warning  FailedMount  ... access denied ...
```

**Check:**
- Managed identity has `Key Vault Secrets User` role on the Key Vault
- The secret name in SecretProviderClass matches the actual secret in Key Vault

#### DNS Resolution Failure

If the private endpoint DNS isn't resolving:

```
Warning  FailedMount  ... could not resolve host ...
```

**Check:**
- Private DNS zone `privatelink.vaultcore.azure.net` exists and is linked to the VNet
- The private endpoint has a DNS zone group configured
- AKS uses Azure-provided DNS (not custom DNS servers)

## Manual Setup (Without Script)

If you prefer to set up manually:

### 1. Get Deployment Outputs

```bash
az deployment group show \
  --resource-group ghcp-demo-rg \
  --name main \
  --query properties.outputs
```

**PowerShell equivalent:**

```powershell
az deployment group show `
  --resource-group ghcp-demo-rg `
  --name main `
  --query properties.outputs
```

### 2. Seed a Secret

```bash
# Temporarily enable public access
az keyvault update --name <kv-name> -g ghcp-demo-rg --public-network-access Enabled

# Create the secret
az keyvault secret set --vault-name <kv-name> --name demo-secret --value "MySecretValue"

# Re-disable public access
az keyvault update --name <kv-name> -g ghcp-demo-rg --public-network-access Disabled
```

### 3. Update deployment.yaml

Replace these placeholders in `deployment.yaml`:

- `${WORKLOAD_IDENTITY_CLIENT_ID}` → managed identity client ID
- `${KEY_VAULT_NAME}` → Key Vault name
- `${TENANT_ID}` → Azure tenant ID

### 4. Apply

```bash
kubectl apply -f deployment.yaml
```

## Cleanup

```bash
kubectl delete namespace scenario-keyvault
rm -f deployment-generated.yaml
```

**PowerShell equivalent:**

```powershell
kubectl delete namespace scenario-keyvault
Remove-Item -Force -ErrorAction SilentlyContinue deployment-generated.yaml
```

## Key Takeaways

- **Workload Identity** eliminates stored credentials — pods authenticate using federated tokens
- **Secrets Store CSI Driver** mounts Key Vault secrets as files, keeping them out of Kubernetes Secrets
- **Private Endpoints** ensure Key Vault traffic never traverses the public internet
- **RBAC on Key Vault** provides fine-grained access control (no access policies needed)
- Copilot CLI can help diagnose CSI mount failures, RBAC issues, and DNS resolution problems
