# Getting Started with the AKS Copilot Demo

This guide walks you through setting up and running the complete AKS troubleshooting demo.

## 5-Minute Quick Start

```bash
# 1. Clone/navigate to repo
cd aks-ghcp-demo

# 2. Create Azure Resource Group
az group create --name ghcp-demo-rg --location eastus

# 3. Deploy AKS Cluster
az deployment group create \
  --resource-group ghcp-demo-rg \
  --template-file infrastructure/main.bicep \
  --parameters infrastructure/parameters.json

# 4. Get cluster credentials
az aks get-credentials --resource-group ghcp-demo-rg --name aks-ghcp-demo

# 5. Deploy a scenario
kubectl apply -f scenarios/01-crashloopbackoff/deployment.yaml

# 6. Troubleshoot with Copilot
kubectl get pods -n scenario-crashloop | gh copilot explain
kubectl logs -n scenario-crashloop <pod-name> --previous | gh copilot explain
```

**PowerShell equivalent:**

```powershell
# 1. Clone/navigate to repo
cd aks-ghcp-demo

# 2. Create Azure Resource Group
az group create --name ghcp-demo-rg --location eastus

# 3. Deploy AKS Cluster
az deployment group create `
  --resource-group ghcp-demo-rg `
  --template-file infrastructure/main.bicep `
  --parameters infrastructure/parameters.json

# 4. Get cluster credentials
az aks get-credentials --resource-group ghcp-demo-rg --name aks-ghcp-demo

# 5. Deploy a scenario
kubectl apply -f scenarios/01-crashloopbackoff/deployment.yaml

# 6. Troubleshoot with Copilot
kubectl get pods -n scenario-crashloop | gh copilot explain
kubectl logs -n scenario-crashloop <pod-name> --previous | gh copilot explain
```

## Prerequisites

### Required Software

```bash
# Check if installed
command -v az        # Azure CLI
command -v kubectl   # Kubernetes CLI
command -v docker    # Docker (optional, for building images)
command -v gh        # GitHub CLI
```

**PowerShell equivalent:**

```powershell
# Check if installed
Get-Command az      -ErrorAction SilentlyContinue
Get-Command kubectl -ErrorAction SilentlyContinue
Get-Command docker  -ErrorAction SilentlyContinue
Get-Command gh      -ErrorAction SilentlyContinue
```

### Installation Instructions

**Azure CLI**:

```bash
# macOS
brew install azure-cli

# Linux
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Windows
winget install Microsoft.AzureCLI
```

**kubectl**:

```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Windows
winget install Kubernetes.kubectl
```

**GitHub CLI & Copilot**:

```bash
# macOS
brew install gh

# Linux
curl -sS https://webi.sh/gh | sh

# Authenticate
gh auth login

# Verify Copilot
gh copilot --help
```

### Azure Account Setup

```bash
# Login to Azure
az login

# Set default subscription (if multiple)
az account set --subscription "<subscription-id>"

# Verify access
az account show
```

## Step-by-Step Setup

### Step 1: Prepare Azure

```bash
# Create resource group
az group create \
  --name ghcp-demo-rg \
  --location eastus

# Verify
az group show --name ghcp-demo-rg
```

**PowerShell equivalent:**

```powershell
# Create resource group
az group create `
  --name ghcp-demo-rg `
  --location eastus

# Verify
az group show --name ghcp-demo-rg
```

### Step 2: Deploy AKS Infrastructure

```bash
# Option A: Deploy with defaults
az deployment group create \
  --resource-group ghcp-demo-rg \
  --template-file infrastructure/main.bicep \
  --parameters infrastructure/parameters.json

# Option B: Deploy with custom parameters
az deployment group create \
  --resource-group ghcp-demo-rg \
  --template-file infrastructure/main.bicep \
  --parameters \
    location=eastus \
    clusterName=my-demo-cluster \
    nodeCount=3 \
    vmSize=Standard_D3s_v3

# Monitor deployment (takes ~10-15 minutes)
az deployment group show \
  --resource-group ghcp-demo-rg \
  --name main \
  --query properties.provisioningState
```

**PowerShell equivalent:**

```powershell
# Option A: Deploy with defaults
az deployment group create `
  --resource-group ghcp-demo-rg `
  --template-file infrastructure/main.bicep `
  --parameters infrastructure/parameters.json

# Option B: Deploy with custom parameters
az deployment group create `
  --resource-group ghcp-demo-rg `
  --template-file infrastructure/main.bicep `
  --parameters `
    location=eastus `
    clusterName=my-demo-cluster `
    nodeCount=3 `
    vmSize=Standard_D3s_v3

# Monitor deployment (takes ~10-15 minutes)
az deployment group show `
  --resource-group ghcp-demo-rg `
  --name main `
  --query properties.provisioningState
```

**Wait for provisioning state to be "Succeeded"**

### Step 3: Configure kubectl

```bash
# Get AKS cluster credentials
az aks get-credentials \
  --resource-group ghcp-demo-rg \
  --name aks-ghcp-demo \
  --overwrite-existing

# Verify cluster access
kubectl cluster-info
kubectl get nodes
```

**PowerShell equivalent:**

```powershell
# Get AKS cluster credentials
az aks get-credentials `
  --resource-group ghcp-demo-rg `
  --name aks-ghcp-demo `
  --overwrite-existing

# Verify cluster access
kubectl cluster-info
kubectl get nodes
```

Expected output:

```
NAME                                STATUS   ROLES   AGE     VERSION
aks-agentpool-xxxxx-vmss000000      Ready    agent   5m      v1.28.x
aks-agentpool-xxxxx-vmss000001      Ready    agent   5m      v1.28.x
```

### Step 4: Run Scenario 1 (CrashLoopBackOff)

```bash
# Deploy scenario
kubectl apply -f scenarios/01-crashloopbackoff/deployment.yaml

# Watch pod status (gives it 20 seconds to crash)
sleep 5
kubectl get pods -n scenario-crashloop

# You should see CrashLoopBackOff after a few seconds
```

**PowerShell equivalent:**

```powershell
# Deploy scenario
kubectl apply -f scenarios/01-crashloopbackoff/deployment.yaml

# Watch pod status (gives it 20 seconds to crash)
Start-Sleep -Seconds 5
kubectl get pods -n scenario-crashloop

# You should see CrashLoopBackOff after a few seconds
```

**Troubleshoot with Copilot**:

```bash
# Step 1: Explain pod status
kubectl get pods -n scenario-crashloop | gh copilot explain

# Step 2: Get detailed pod info
kubectl describe pod -n scenario-crashloop <pod-name> | gh copilot explain

# Step 3: Check previous logs (from crash)
kubectl logs -n scenario-crashloop <pod-name> --previous | gh copilot explain
```

**Expected Copilot Output**:

> "The pod is in CrashLoopBackOff, which means the container keeps crashing. The logs show: 'ERROR: Configuration file not found at /app/config/application.conf'. This means the application expects a configuration file that isn't being provided to the container."

### Step 5: Run Scenario 2 (ImagePullBackOff)

```bash
# Deploy scenario
kubectl apply -f scenarios/02-imagepullbackoff/deployment.yaml

# Check pod status
kubectl get pods -n scenario-imagepull

# You should see ImagePullBackOff
```

**Troubleshoot with Copilot**:

```bash
# Get the error
kubectl describe pod -n scenario-imagepull <pod-name> | gh copilot explain

# Copilot will explain:
# "The pod cannot pull the image 'docker.io/mycompany/myapp:v99.99.99'
#  because it doesn't exist in the registry. This is an ImagePullBackOff error."
```

### Step 6: Run Scenario 3 (Application Logs)

```bash
# Deploy scenario
kubectl apply -f scenarios/03-application-logs/deployment.yaml

# Check pod status
kubectl get pods -n scenario-applogs

# You should see Running (but with errors in logs!)
```

**Troubleshoot with Copilot**:

```bash
# Pod appears healthy
kubectl get pods -n scenario-applogs

# But check the logs
kubectl logs -n scenario-applogs <pod-name> | gh copilot explain

# Copilot will explain the database connection errors visible only in logs
```

## Running All Scenarios

```bash
# Deploy all at once
for scenario in scenarios/*/deployment.yaml; do
  kubectl apply -f $scenario
done

# Check all pods
kubectl get pods --all-namespaces

# Troubleshoot with Copilot
kubectl get pods --all-namespaces | gh copilot explain
```

**PowerShell equivalent:**

```powershell
# Deploy all at once
Get-ChildItem scenarios/*/deployment.yaml | ForEach-Object {
  kubectl apply -f $_.FullName
}

# Check all pods
kubectl get pods --all-namespaces

# Troubleshoot with Copilot
kubectl get pods --all-namespaces | gh copilot explain
```

## Demo Workflow

Use this workflow to demonstrate the troubleshooting process:

### Scenario A: Cold Start (30 minutes)

1. **Setup Phase** (5 min)
   - Deploy cluster
   - Deploy a scenario
   - Show pod is broken

2. **Observation Phase** (5 min)
   - Show `kubectl get pods` - pod appears broken
   - Show `kubectl describe pod` - lots of output
   - Ask: "How do I figure out what's wrong?"

3. **Troubleshooting Phase** (10 min)
   - Use Copilot to explain pod status
   - Use Copilot to explain pod description
   - Use Copilot to explain logs
   - Gradually narrow down to root cause

4. **Analysis Phase** (5 min)
   - Show Copilot-suggested fix
   - Apply the fix
   - Show pod recovering

5. **Verification Phase** (5 min)
   - Confirm pod is healthy
   - Check logs show success
   - Demonstrate readiness/liveness checks

### Scenario B: Comparative Demo (45 minutes)

1. **Without Copilot** (15 min)
   - Deploy scenario
   - Show how long it takes to diagnose without help
   - Struggle with logs
   - Eventually find the issue

2. **With Copilot** (15 min)
   - Deploy same scenario on different namespace
   - Use Copilot CLI to immediately identify issue
   - Show how much faster it is
   - Apply fix and verify

3. **Discussion** (15 min)
   - Compare the two approaches
   - Highlight time savings
   - Show scalability to multiple problems
   - Discuss team onboarding benefits

## Building Container Images (Optional)

If you want to build and push your own images:

```bash
# Create Azure Container Registry
az acr create --resource-group ghcp-demo-rg --name demoacr --sku Basic

# Build images
for scenario in scenarios/*/; do
  image_name=$(basename $scenario)
  az acr build \
    --registry demoacr \
    --image demo/$image_name:v1.0 \
    $scenario
done

# Update deployment.yaml files to use your registry
# Change: docker.io/library/python:3.11-slim
# To: demoacr.azurecr.io/demo/<scenario>:v1.0
```

**PowerShell equivalent:**

```powershell
# Create Azure Container Registry
az acr create --resource-group ghcp-demo-rg --name demoacr --sku Basic

# Build images
Get-ChildItem scenarios -Directory | ForEach-Object {
  $imageName = $_.Name
  az acr build `
    --registry demoacr `
    --image "demo/${imageName}:v1.0" `
    $_.FullName
}

# Update deployment.yaml files to use your registry
# Change: docker.io/library/python:3.11-slim
# To: demoacr.azurecr.io/demo/<scenario>:v1.0
```

## Monitoring and Debugging

### Real-time Monitoring

```bash
# Watch all pods across namespaces
kubectl get pods --all-namespaces -w

# Stream logs from a pod
kubectl logs <pod-name> -n <namespace> -f

# Stream logs matching a pattern
kubectl logs <pod-name> -n <namespace> -f | grep ERROR
```

**PowerShell equivalent** (only the `grep` line differs):

```powershell
kubectl logs <pod-name> -n <namespace> -f | Select-String "ERROR"
```

### Detailed Debugging

```bash
# Get all resources in a namespace
kubectl get all -n <namespace>

# Export pod YAML for analysis
kubectl get pod <pod-name> -n <namespace> -o yaml

# Check recent events
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -10

# Execute command inside pod
kubectl exec <pod-name> -n <namespace> -- env | grep DATABASE
```

**PowerShell equivalent** (`tail`/`grep` differ):

```powershell
# Get all resources in a namespace
kubectl get all -n <namespace>

# Export pod YAML for analysis
kubectl get pod <pod-name> -n <namespace> -o yaml

# Check recent events
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | Select-Object -Last 10

# Execute command inside pod
kubectl exec <pod-name> -n <namespace> -- env | Select-String "DATABASE"
```

## Troubleshooting the Demo Setup

### AKS Deployment Fails

```bash
# Check deployment status
az deployment group show \
  --resource-group ghcp-demo-rg \
  --name main \
  --query "properties.{provisioningState:provisioningState, error:properties.error}"

# Check resource group is created
az group show --name ghcp-demo-rg

# Check quota
az vm list-usage --location eastus | grep Standard_D
```

**PowerShell equivalent:**

```powershell
# Check deployment status
az deployment group show `
  --resource-group ghcp-demo-rg `
  --name main `
  --query "properties.{provisioningState:provisioningState, error:properties.error}"

# Check resource group is created
az group show --name ghcp-demo-rg

# Check quota
az vm list-usage --location eastus | Select-String "Standard_D"
```

### kubectl Can't Connect

```bash
# Verify credentials are set
kubectl config current-context

# Try to get credentials again
az aks get-credentials \
  --resource-group ghcp-demo-rg \
  --name aks-ghcp-demo \
  --overwrite-existing

# Check cluster exists
az aks list --resource-group ghcp-demo-rg
```

**PowerShell equivalent:**

```powershell
# Verify credentials are set
kubectl config current-context

# Try to get credentials again
az aks get-credentials `
  --resource-group ghcp-demo-rg `
  --name aks-ghcp-demo `
  --overwrite-existing

# Check cluster exists
az aks list --resource-group ghcp-demo-rg
```

### Pods Stuck in Pending

```bash
# Check node availability
kubectl top nodes
kubectl get nodes

# Check pod details
kubectl describe pod <pod-name> -n <namespace>

# Scale cluster if needed
az aks scale \
  --resource-group ghcp-demo-rg \
  --name aks-ghcp-demo \
  --node-count 3
```

**PowerShell equivalent:**

```powershell
# Check node availability
kubectl top nodes
kubectl get nodes

# Check pod details
kubectl describe pod <pod-name> -n <namespace>

# Scale cluster if needed
az aks scale `
  --resource-group ghcp-demo-rg `
  --name aks-ghcp-demo `
  --node-count 3
```

### Copilot CLI Not Working

```bash
# Verify installation
gh extension list

# Check authentication
gh auth status

# Reinstall if needed
gh extension remove github/gh-copilot
gh extension install github/gh-copilot
```

## Cleanup

```bash
# Delete all scenarios
kubectl delete namespace scenario-crashloop scenario-imagepull scenario-applogs

# Delete AKS cluster and resources (takes ~15 minutes)
az group delete --name ghcp-demo-rg --yes --no-wait

# Or just delete the cluster
az aks delete \
  --resource-group ghcp-demo-rg \
  --name aks-ghcp-demo \
  --yes --no-wait
```

**PowerShell equivalent:**

```powershell
# Delete all scenarios
kubectl delete namespace scenario-crashloop scenario-imagepull scenario-applogs

# Delete AKS cluster and resources (takes ~15 minutes)
az group delete --name ghcp-demo-rg --yes --no-wait

# Or just delete the cluster
az aks delete `
  --resource-group ghcp-demo-rg `
  --name aks-ghcp-demo `
  --yes --no-wait
```

## Next Steps

1. **Review the scenario READMEs** to understand each failure pattern
2. **Read the Troubleshooting Guide** for detailed diagnostic procedures
3. **Review the Copilot CLI Guide** for command usage
4. **Practice the workflows** with each scenario
5. **Customize scenarios** for your team's use cases
6. **Build your own scenarios** following the pattern

## Tips for Presenters

- **Start with Scenario 3** - it's the most realistic (pod runs but has errors)
- **Use multiple terminals** - one for kubectl, one for Copilot
- **Explain as you go** - verbalize what Copilot is telling you
- **Try without Copilot first** - show the difficulty, then show Copilot
- **Have fallback scenarios** - if deployment is slow, pre-deploy before presentation
- **Use port-forwarding** - for showing application responses: `kubectl port-forward svc/<svc> 8080:8080`

## Demo Timing

| Phase           | Time       | Activity                        |
| --------------- | ---------- | ------------------------------- |
| Setup           | 15 min     | Deploy cluster, deploy scenario |
| Observation     | 5 min      | Show broken pod                 |
| Without Copilot | 10 min     | Manual troubleshooting          |
| With Copilot    | 5 min      | Automated troubleshooting       |
| Fix & Verify    | 5 min      | Apply fix, watch recovery       |
| Q&A             | 5 min      | Questions and discussion        |
| **Total**       | **45 min** | Full demo session               |

## Questions?

Refer to:

- Individual scenario READMEs in `scenarios/*/README.md`
- Troubleshooting Guide: `docs/TROUBLESHOOTING_GUIDE.md`
- Copilot CLI Guide: `docs/COPILOT_CLI_GUIDE.md`
- [AKS Documentation](https://docs.microsoft.com/azure/aks/)
- [Kubernetes Documentation](https://kubernetes.io/)
