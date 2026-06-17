# AKS Infrastructure Setup

This folder contains Bicep templates for deploying the AKS cluster used in this demo.

## Files

- `main.bicep` - Main infrastructure template
- `parameters.json` - Parameter values for the deployment

## Quick Deploy

### 1. Create a Resource Group

```bash
az group create \
  --name ghcp-demo-rg \
  --location eastus
```

**PowerShell equivalent:**

```powershell
az group create `
  --name ghcp-demo-rg `
  --location eastus
```

### 2. Deploy the Cluster

```bash
az deployment group create \
  --resource-group ghcp-demo-rg \
  --template-file main.bicep \
  --parameters parameters.json
```

**PowerShell equivalent:**

```powershell
az deployment group create `
  --resource-group ghcp-demo-rg `
  --template-file main.bicep `
  --parameters parameters.json
```

### 3. Get Cluster Credentials

```bash
az aks get-credentials \
  --resource-group ghcp-demo-rg \
  --name aks-ghcp-demo \
  --overwrite-existing
```

**PowerShell equivalent:**

```powershell
az aks get-credentials `
  --resource-group ghcp-demo-rg `
  --name aks-ghcp-demo `
  --overwrite-existing
```

### 4. Verify Cluster

```bash
kubectl cluster-info
kubectl get nodes
```

## Configuration

The default configuration creates:

- **Cluster Name**: aks-ghcp-demo
- **Location**: eastus
- **Node Pool**: 2x Standard_D2s_v3 nodes (in a dedicated VNet subnet)
- **Kubernetes Version**: 1.28
- **Monitoring**: Log Analytics integration enabled
- **RBAC**: Enabled
- **VNet**: 10.1.0.0/16 with AKS and private endpoint subnets
- **Key Vault**: RBAC-authorized, private endpoint only, soft delete + purge protection
- **Secrets Store CSI Driver**: Enabled with secret rotation
- **Workload Identity**: OIDC issuer + workload identity enabled
- **Managed Identity**: Federated with Key Vault Secrets User role
- **Container Registry**: Azure Container Registry with the AKS kubelet identity granted `AcrPull` (the IaC equivalent of `az aks update --attach-acr`)

## Customization

Modify `parameters.json` to change:

- `location` - Azure region
- `clusterName` - AKS cluster name
- `nodeCount` - Number of nodes
- `vmSize` - VM size for nodes
- `kubernetesVersion` - Kubernetes version
- `acrName` - Azure Container Registry name (globally unique, alphanumeric, 5-50 chars)
- `acrSku` - ACR SKU (`Basic`, `Standard`, or `Premium`)

> The scenarios are **not** tied to a specific registry name. They reference the
> registry through a `${ACR_LOGIN_SERVER}` placeholder and the deploy helper
> (`scenarios/deploy.sh` / `deploy.ps1`) discovers the cluster's attached ACR at
> runtime. Change `acrName` here and the scenarios still work with no edits.

The deployment exposes `acrName` and `acrLoginServer` as outputs:

```bash
az deployment group show -g ghcp-demo-rg -n main --query properties.outputs.acrLoginServer.value -o tsv
```

```bash
az deployment group create \
  --resource-group ghcp-demo-rg \
  --template-file main.bicep \
  --parameters parameters.json
```

**PowerShell equivalent:**

```powershell
az deployment group create `
  --resource-group ghcp-demo-rg `
  --template-file main.bicep `
  --parameters parameters.json
```

## Cleanup

To delete the AKS cluster and all resources:

```bash
az group delete \
  --name ghcp-demo-rg \
  --yes --no-wait
```

**PowerShell equivalent:**

```powershell
az group delete `
  --name ghcp-demo-rg `
  --yes --no-wait
```

## Monitoring

Container Insights is enabled by default. View logs in the Azure Portal or via CLI:

```bash
# View container logs
az monitor log-analytics query \
  --workspace ghcp-demo-rg_aks-ghcp-demo_law \
  --analytics-query "ContainerLog | head 10"
```

**PowerShell equivalent:**

```powershell
# View container logs
az monitor log-analytics query `
  --workspace ghcp-demo-rg_aks-ghcp-demo_law `
  --analytics-query "ContainerLog | head 10"
```

## Troubleshooting

### Deployment fails with quota error

- Check your subscription limits: `az vm list-usage --location eastus`
- Reduce `nodeCount` or use a smaller `vmSize`

### Cannot get cluster credentials

- Verify cluster name matches exactly
- Confirm resource group exists and is correct
- Check Azure CLI authentication: `az account show`

### Nodes are NotReady

- Wait 5-10 minutes for nodes to fully initialize
- Check node status: `kubectl get nodes -w`
- Describe node for details: `kubectl describe node <node-name>`
