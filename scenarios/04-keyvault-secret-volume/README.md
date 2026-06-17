# Scenario 4: Key Vault Secret Volume

## Overview

This scenario demonstrates how to securely mount Azure Key Vault secrets into a Kubernetes pod using:

- **Azure Key Vault** with RBAC authorization and a private endpoint
- **Secrets Store CSI Driver** to mount secrets as volumes
- **Workload Identity** for pod-level authentication (no stored credentials)
- **Private Endpoint** so all Key Vault traffic stays on the Azure backbone network

The pod uses a federated identity credential to authenticate to Key Vault without any passwords or connection strings. The secret is mounted as a file inside the container.

> **This scenario deploys broken on purpose.** The infrastructure (workload
> identity, RBAC, CSI driver, private endpoint) is all healthy, but `setup.sh` /
> `setup.ps1` inject a realistic Azure misconfiguration after seeding the secret:
> the Key Vault **private DNS A record is overwritten with the wrong IP**. The
> Key Vault FQDN then resolves to an address with no listener, the Secrets Store
> CSI driver cannot reach Key Vault, and the secret volume fails to mount — the
> pod is stuck in `ContainerCreating` with a `FailedMount` event. The goal is to
> diagnose this DNS/private-endpoint issue and fix it.

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
7. The Key Vault FQDN (`<vault>.vault.azure.net`) resolves to the private
   endpoint's private IP via the `privatelink.vaultcore.azure.net` **private DNS
   zone**. If that A record is wrong, every step above is healthy but the CSI
   driver still can't reach Key Vault — which is exactly the fault this scenario
   injects.

## The Injected Fault (and the fix)

`setup.sh` overwrites the Key Vault A record in the
`privatelink.vaultcore.azure.net` zone with an unused in-subnet IP
(`10.1.16.250`). Resolution succeeds but connections hang, so the CSI mount
times out with `context deadline exceeded`.

To resolve the scenario, restore the correct record (read back from the Key
Vault private endpoint) with the fix mode:

```bash
./setup.sh ghcp-demo-rg --fix-dns          # PowerShell: ./setup.ps1 -ResourceGroup ghcp-demo-rg -FixDns
```

## Prerequisites

- Infrastructure deployed via `infrastructure/main.bicep`
- `kubectl` configured for the AKS cluster
- Azure CLI authenticated with access to the resource group
- `jq` installed (for the setup script)

> **Container image:** The pod runs `<your-acr>.azurecr.io/keyvault-demo:v1`,
> built from [app.py](app.py). The manifest uses a `${ACR_LOGIN_SERVER}`
> placeholder which `setup.sh` / `setup.ps1` resolve from the Bicep
> `acrLoginServer` output, so it is not tied to a specific registry name.
> To (re)build the image into your registry (default `ghcpdemoacr`):
>
> ```bash
> az acr build --registry $(az deployment group show -g ghcp-demo-rg -n main --query properties.outputs.acrName.value -o tsv) --image keyvault-demo:v1 scenarios/04-keyvault-secret-volume
> ```

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

Because the scenario is broken on purpose, the pod will **stay in
`ContainerCreating`** and never become `Ready`:

```
NAME                             READY   STATUS              RESTARTS   AGE
keyvault-demo-7d9c8b6f4-abcde    0/1     ContainerCreating   0          2m
```

That is the expected starting point — work through the diagnosis below. Once you
restore the DNS record (`./setup.sh ghcp-demo-rg --fix-dns`), the pod mounts the
secret and logs:

```bash
$ kubectl logs -n scenario-keyvault -l app=keyvault-demo
=== Key Vault Secret Volume Demo ===
Process ID: 1
Looking for secret at: /mnt/secrets/demo-secret

[OK] Secret mounted successfully. Value length: 28 chars
[OK] Secret preview: Supe****
[INFO] Next check in 30 seconds...
```

## Part A — Diagnose It Manually

When the secret won't mount, the pod usually sits in `ContainerCreating` (it
can't start until the CSI volume is ready). Work through these steps in order.

### Step 1: Check Pod Status

```bash
kubectl get pods -n scenario-keyvault
```

```
NAME                             READY   STATUS              RESTARTS   AGE
keyvault-demo-7d9c8b6f4-abcde    0/1     ContainerCreating   0          90s
```

A pod stuck in `ContainerCreating` for more than ~30s almost always means a
volume problem. Save the pod name:

```bash
POD=$(kubectl get pods -n scenario-keyvault -l app=keyvault-demo -o jsonpath='{.items[0].metadata.name}')
echo "$POD"
```

### Step 2: Describe the Pod (read the Events)

The CSI driver reports mount failures in the pod's `Events`, not in container
logs (the container hasn't started yet):

```bash
kubectl describe pod "$POD" -n scenario-keyvault
```

Look in the **`Events`** section for a `FailedMount` warning. The exact message
tells you which layer is broken — see Common Failure Modes below.

### Step 3: Check Namespace Events and the CSI Driver

```bash
# All recent events in the namespace, newest last
kubectl get events -n scenario-keyvault --sort-by='.lastTimestamp'

# Confirm the Secrets Store CSI driver pods are healthy
kubectl get pods -n kube-system -l app=secrets-store-csi-driver
```

### Step 4: If the Pod IS Running, Check the Secret Was Mounted

When everything is configured correctly the pod runs and prints the secret
status — verify from the logs:

```bash
kubectl logs "$POD" -n scenario-keyvault
```

```
=== Key Vault Secret Volume Demo ===
Process ID: 1
Looking for secret at: /mnt/secrets/demo-secret

[OK] Secret mounted successfully. Value length: 28 chars
[OK] Secret preview: Supe****
[INFO] Next check in 30 seconds...
```

If you instead see `[ERROR] Secret file not found`, the volume mounted but the
expected object name is wrong.

## Part B — Diagnose It with Copilot CLI

Same investigation, but hand the raw Kubernetes output to the GitHub Copilot CLI
(`copilot`) and let it translate CSI/RBAC/DNS errors into plain English with a
fix.

> **Important — don't pipe into Copilot.** The GitHub Copilot CLI (`copilot`)
> does **not** read piped `stdin` as context. If you run
> `kubectl describe pod ... | copilot -p "..."`, Copilot sees an empty prompt
> and replies that there's no data. Instead, embed the command's output
> **inside** the prompt using shell command substitution `$(...)`.

### Step 1: Explain the Pod Status

```bash
copilot -p "Explain this Kubernetes pod status in plain English and tell me what is wrong:

$(kubectl get pods -n scenario-keyvault)"
```

### Step 2: Explain the Mount Failure and Get a Fix

This is the key step — feed the describe output (with the `FailedMount` event)
in and ask for a remediation plan:

```bash
copilot -p "This pod cannot mount an Azure Key Vault secret via the Secrets Store CSI driver. Explain these pod events in plain English and tell me exactly how to fix the mount error:

$(kubectl describe pod "$POD" -n scenario-keyvault)"
```

### Step 3: Explain the Namespace Events

```bash
copilot -p "Explain these Kubernetes events in plain English and how to fix the errors:

$(kubectl get events -n scenario-keyvault --sort-by='.lastTimestamp')"
```

> **Tip:** Because this `copilot` is agentic, you can also let it run the
> commands itself instead of substituting output — just add `--allow-all-tools`
> and describe the task:
>
> ```bash
> copilot --allow-all-tools -p "The pod in namespace scenario-keyvault is failing to mount a Key Vault secret via the Secrets Store CSI driver. Investigate with kubectl, explain the root cause in plain English, and tell me how to fix it."
> ```

### One-liner: hand Copilot everything at once

```bash
copilot -p "This pod cannot mount its Key Vault secret. Explain what is wrong in plain English and give me step-by-step instructions to fix it.

=== STATUS ===
$(kubectl get pods -n scenario-keyvault)

=== DESCRIBE ===
$(kubectl describe pod "$POD" -n scenario-keyvault)

=== EVENTS ===
$(kubectl get events -n scenario-keyvault --sort-by='.lastTimestamp')"
```

## Common Failure Modes

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

#### DNS / Private Endpoint Resolution Failure  ← this scenario's root cause

If the Key Vault FQDN resolves to the wrong IP (or doesn't resolve), the CSI
driver can't reach Key Vault and the mount **times out**:

```
Warning  FailedMount  ... MountVolume.SetUp failed for volume "secrets-store" :
rpc error: code = DeadlineExceeded desc = context deadline exceeded
```

(If DNS fails to resolve at all you'd instead see `... could not resolve host ...`.)

**Check:**
- The A record for the vault in the `privatelink.vaultcore.azure.net` private DNS
  zone points to the **private endpoint's** IP (not a wrong/stale address):
  ```bash
  az network private-dns record-set a list -g ghcp-demo-rg -z privatelink.vaultcore.azure.net -o table
  az network private-endpoint show -g ghcp-demo-rg -n <vault>-pe --query "customDnsConfigs[0].ipAddresses" -o tsv
  ```
- The private DNS zone is linked to the VNet and the private endpoint has a DNS
  zone group configured
- AKS uses Azure-provided DNS (not custom DNS servers)

**Fix (this scenario):** restore the correct record automatically with

```bash
./setup.sh ghcp-demo-rg --fix-dns          # PowerShell: ./setup.ps1 -ResourceGroup ghcp-demo-rg -FixDns
```

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
- `${ACR_LOGIN_SERVER}` → registry login server (e.g. `ghcpdemoacr.azurecr.io`)

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
- The `copilot` CLI does not read piped `stdin` — embed `kubectl` output in the prompt with `$(...)` to turn CSI mount / RBAC / DNS errors into a plain-English explanation with fixes
