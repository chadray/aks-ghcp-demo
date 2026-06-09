# AKS GitHub Copilot CLI Troubleshooting Demo

This repository demonstrates how support teams can use **GitHub Copilot CLI** to troubleshoot and diagnose common AKS (Azure Kubernetes Service) failure scenarios. It simulates a typical workflow where developers deploy code, a pipeline runs, something breaks, and the support team uses Copilot to analyze and troubleshoot the environment.

## Demo Overview

This demo includes:

1. **AKS Infrastructure** - A complete, ready-to-deploy AKS cluster setup using Bicep
2. **Four Failure Scenarios** - Real-world Kubernetes failure patterns that support teams commonly encounter
3. **Complete Documentation** - Step-by-step guides for each scenario and troubleshooting approach

## Scenarios Included

### Scenario 1: CrashLoopBackOff

- **Description**: Application crashes immediately on startup
- **Root Cause**: Configuration error or missing dependencies
- **Diagnosis Method**: Pod logs and events show repeated restart attempts
- **Location**: `scenarios/01-crashloopbackoff/`

### Scenario 2: ImagePullBackOff

- **Description**: Container image cannot be pulled from registry
- **Root Cause**: Wrong image tag, invalid credentials, or non-existent registry
- **Diagnosis Method**: Pod events show image pull failures
- **Location**: `scenarios/02-imagepullbackoff/`

### Scenario 3: Application Error in Logs

- **Description**: Pod runs but application errors are written to stdout
- **Root Cause**: Business logic error or runtime issue
- **Diagnosis Method**: Must read pod logs to find the root cause
- **Location**: `scenarios/03-application-logs/`

### Scenario 4: Key Vault Secret Volume

- **Description**: Pod mounts a secret from Azure Key Vault via the Secrets Store CSI Driver
- **Root Cause**: Workload identity misconfiguration, RBAC issues, or private endpoint DNS failures
- **Diagnosis Method**: CSI mount events, pod events, and Key Vault access logs
- **Location**: `scenarios/04-keyvault-secret-volume/`

## Quick Start

### Prerequisites

- Azure CLI (`az`) installed
- Helm installed (for cluster deployment)
- kubectl installed
- Docker installed (for building container images)
- GitHub Copilot CLI installed (`gh copilot`)

### 1. Deploy AKS Infrastructure

```bash
cd infrastructure
az deployment group create \
  --resource-group my-rg \
  --template-file main.bicep \
  --parameters location=eastus clusterName=aks-ghcp-demo

# Get cluster credentials
az aks get-credentials --resource-group my-rg --name aks-ghcp-demo
```

**PowerShell equivalent:**

```powershell
cd infrastructure
az deployment group create `
  --resource-group my-rg `
  --template-file main.bicep `
  --parameters location=eastus clusterName=aks-ghcp-demo

# Get cluster credentials
az aks get-credentials --resource-group my-rg --name aks-ghcp-demo
```

### 2. Deploy a Scenario

Each scenario can be deployed independently:

```bash
# Deploy Scenario 1: CrashLoopBackOff
cd scenarios/01-crashloopbackoff
kubectl create namespace scenario-1
kubectl apply -f deployment.yaml -n scenario-1

# Check pod status
kubectl get pods -n scenario-1
```

### 3. Use GitHub Copilot CLI to Troubleshoot

Once a pod is in a failed state, use Copilot to help diagnose:

```bash
# Get pod details
kubectl describe pod <pod-name> -n scenario-1 | gh copilot explain

# View logs
kubectl logs <pod-name> -n scenario-1 | gh copilot explain

# Get events
kubectl get events -n scenario-1 | gh copilot explain
```

## Folder Structure

```
aks-ghcp-demo/
├── README.md (this file)
├── infrastructure/
│   ├── main.bicep
│   ├── parameters.json
│   └── README.md
├── scenarios/
│   ├── 01-crashloopbackoff/
│   │   ├── Dockerfile
│   │   ├── app.py (or app.js)
│   │   ├── deployment.yaml
│   │   └── README.md
│   ├── 02-imagepullbackoff/
│   │   ├── Dockerfile
│   │   ├── app.py (or app.js)
│   │   ├── deployment.yaml
│   │   └── README.md
│   ├── 03-application-logs/
│   │   ├── Dockerfile
│   │   ├── app.py (or app.js)
│   │   ├── deployment.yaml
│   │   └── README.md
│   └── 04-keyvault-secret-volume/
│       ├── Dockerfile
│       ├── app.py
│       ├── deployment.yaml
│       ├── setup.sh
│       └── README.md
└── docs/
    ├── TROUBLESHOOTING_GUIDE.md
    └── COPILOT_CLI_GUIDE.md
```

## How to Use This Demo in Your Support Workflow

1. **Setup Phase**: Deploy the AKS cluster and seed it with one of the failure scenarios
2. **Break Phase**: The application is already "broken" with a known failure pattern
3. **Troubleshoot Phase**: Use Copilot CLI to:
   - View pod status and events
   - Read application logs
   - Analyze error messages
   - Get Copilot's interpretation and suggested fixes
4. **Fix Phase**: Implement the fix and redeploy
5. **Verify Phase**: Confirm the application is now running

## Copilot CLI Commands Reference

### Explain Kubernetes Resources

```bash
kubectl get pods -n namespace | gh copilot explain
kubectl describe deployment my-app -n namespace | gh copilot explain
```

### Explain Logs

```bash
kubectl logs pod-name -n namespace | gh copilot explain
```

### Explain Events

```bash
kubectl get events -n namespace | gh copilot explain
```

### Interactive Prompts

```bash
gh copilot explain   # Interactive mode
gh copilot suggest   # Get suggestions for next steps
```

## Building Container Images

For development/testing, build and push images to your registry:

```bash
cd scenarios/01-crashloopbackoff
docker build -t <your-registry>/scenario-1:v1.0 .
docker push <your-registry>/scenario-1:v1.0
```

Update the `deployment.yaml` image reference as needed.

## Next Steps

- Review each scenario's README for detailed information
- Follow the TROUBLESHOOTING_GUIDE.md for diagnostic procedures
- Experiment with different `gh copilot` commands
- Extend scenarios with your own failure patterns

## Support

For questions about AKS, check the [Azure Kubernetes Service Documentation](https://docs.microsoft.com/azure/aks/)

For GitHub Copilot CLI, see [GitHub Copilot CLI Documentation](https://docs.github.com/en/copilot/copilot-cli/about-github-copilot-cli)

---

**Created**: April 2026  
**Purpose**: Demonstrate support team troubleshooting workflow with GitHub Copilot CLI
