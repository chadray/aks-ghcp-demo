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
- GitHub Copilot CLI installed (`copilot` — the standalone GitHub Copilot CLI)

> **Tip — Automated Setup:** A PowerShell script is provided in the [`Utilities/`](Utilities/) folder that can install or update all of the prerequisites listed above using `winget`. Run it in an elevated PowerShell window:
>
> ```powershell
> .\Utilities\setup-dev-tools.ps1
> ```
>
> The script installs Azure CLI, Helm, kubectl, Docker Desktop, GitHub CLI, and the GitHub Copilot CLI extension (`gh-copilot`). If a tool is already installed it will be upgraded to the latest version.

### 1. Deploy AKS Infrastructure

The Bicep template provisions the AKS cluster **and** an Azure Container Registry,
granting the cluster's kubelet identity `AcrPull` so pods can pull images without
image-pull secrets (the IaC equivalent of `az aks update --attach-acr`).

```bash
cd infrastructure
az deployment group create \
  --resource-group ghcp-demo-rg \
  --template-file main.bicep \
  --parameters parameters.json

# Get cluster credentials
az aks get-credentials --resource-group ghcp-demo-rg --name aks-ghcp-demo --overwrite-existing
```

**PowerShell equivalent:**

```powershell
cd infrastructure
az deployment group create `
  --resource-group ghcp-demo-rg `
  --template-file main.bicep `
  --parameters parameters.json

# Get cluster credentials
az aks get-credentials --resource-group ghcp-demo-rg --name aks-ghcp-demo --overwrite-existing
```

> The registry name (`acrName`, default `ghcpdemoacr`) is configurable in
> `infrastructure/parameters.json`. The scenarios discover it dynamically, so you
> can change it without editing any manifests. See
> [`infrastructure/README.md`](infrastructure/README.md) for details.

### 2. Deploy a Scenario

The scenario manifests reference the container registry through a
`${ACR_LOGIN_SERVER}` placeholder rather than a hard-coded name, so they are not
tied to any specific ACR. A deploy helper discovers the cluster's **attached
Azure Container Registry at runtime**, substitutes the placeholder, and applies
the manifest. **Run it from the `scenarios/` folder:**

```bash
cd scenarios

# Deploy a scenario (auto-discovers the ACR attached to the cluster)
./deploy.sh 01-crashloopbackoff

# Optionally build & push the image first, then deploy
./deploy.sh 01-crashloopbackoff --build

# Check pod status (namespace is printed at the end of the deploy)
kubectl get pods -n scenario-crashloop
```

**PowerShell equivalent:**

```powershell
cd scenarios

# Deploy a scenario (auto-discovers the ACR attached to the cluster)
./deploy.ps1 01-crashloopbackoff

# Optionally build & push the image first, then deploy
./deploy.ps1 01-crashloopbackoff -Build

kubectl get pods -n scenario-crashloop
```

Valid scenario folders: `01-crashloopbackoff`, `02-imagepullbackoff`,
`03-application-logs`, `04-keyvault-secret-volume`.

> **Why not plain `kubectl apply -f deployment.yaml`?** The manifest contains the
> literal `${ACR_LOGIN_SERVER}` placeholder, which is not a valid image name, so a
> raw apply would fail. The helper resolves it for you. If you must use kubectl
> directly, substitute first:
>
> ```bash
> ACR=$(az acr list -g ghcp-demo-rg --query "[0].loginServer" -o tsv)
> sed "s|\${ACR_LOGIN_SERVER}|$ACR|g" deployment.yaml | kubectl apply -f -
> ```

The helper honors these overrides (env vars for bash, parameters for PowerShell)
if your cluster/registry differ from the defaults: `RESOURCE_GROUP`
(default `ghcp-demo-rg`), `CLUSTER_NAME` (default `aks-ghcp-demo`), `ACR_NAME`,
and `ACR_LOGIN_SERVER`.

> **Scenario 4 is different.** It needs Key Vault + workload-identity values from
> the Bicep deployment, so deploy it with its own setup script instead of
> `deploy.sh`:
>
> ```bash
> cd scenarios/04-keyvault-secret-volume
> ./setup.sh ghcp-demo-rg        # PowerShell: ./setup.ps1 -ResourceGroup ghcp-demo-rg
> ```

### 3. Use GitHub Copilot CLI to Troubleshoot

Once a pod is in a failed state, hand the `kubectl` output to the GitHub Copilot
CLI (`copilot`) and ask it to explain the output in plain English and
troubleshoot the errors.

> **Important — don't pipe into Copilot.** The GitHub Copilot CLI does **not**
> read piped `stdin` as context. `kubectl ... | copilot -p "..."` gives Copilot an
> empty prompt and it replies that there's no data. Instead, embed the command's
> output **inline** in the prompt using shell command substitution `$(...)` so the
> text becomes part of the `-p` argument.

```bash
# Capture the pod name once
POD=$(kubectl get pods -n scenario-1 -o jsonpath='{.items[0].metadata.name}')

# Get pod details
copilot -p "Explain these pod events in plain English and how to troubleshoot the errors:

$(kubectl describe pod "$POD" -n scenario-1)"

# View logs
copilot -p "Explain these logs in plain English and how to fix the errors:

$(kubectl logs "$POD" -n scenario-1)"

# Get events
copilot -p "Explain these Kubernetes events in plain English and how to fix them:

$(kubectl get events -n scenario-1)"
```

> **Tip:** Because this `copilot` is agentic, you can also let it run the commands
> itself — add `--allow-all-tools` and just describe the task:
> `copilot --allow-all-tools -p "Investigate the failing pod in namespace scenario-1 with kubectl, explain the root cause in plain English, and tell me how to fix it."`

## Folder Structure

```
aks-ghcp-demo/
├── README.md (this file)
├── Utilities/
│   └── setup-dev-tools.ps1
├── infrastructure/
│   ├── main.bicep
│   ├── parameters.json
│   └── README.md
├── scenarios/
│   ├── deploy.sh            # Dynamic deployer (bash) — resolves ACR + applies
│   ├── deploy.ps1           # Dynamic deployer (PowerShell)
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

The core pattern is to embed `kubectl` output **inline** in the prompt with
command substitution — `copilot -p "<your prompt>:\n\n$(kubectl ...)"` — and ask
it to explain the output in plain English and troubleshoot the errors.

> Do **not** pipe (`kubectl ... | copilot`); the CLI ignores piped `stdin`. Use
> `$(...)` so the output is part of the `-p` prompt text.

### Explain Kubernetes Resources

```bash
copilot -p "Explain this pod status in plain English and tell me what is wrong:

$(kubectl get pods -n namespace)"

copilot -p "Explain this deployment in plain English and how to troubleshoot any issues:

$(kubectl describe deployment my-app -n namespace)"
```

### Explain Logs

```bash
copilot -p "Explain these logs in plain English and how to fix the errors:

$(kubectl logs pod-name -n namespace)"
```

### Explain Events

```bash
copilot -p "Explain these Kubernetes events in plain English and how to fix them:

$(kubectl get events -n namespace)"
```

### Let Copilot Run the Commands (agentic)

```bash
# Grant tool access and describe the task; Copilot runs kubectl itself
copilot --allow-all-tools -p "Investigate the failing pod in namespace <namespace>, explain the root cause in plain English, and tell me how to fix it."
```

### Interactive Prompts

```bash
copilot   # Open an interactive Copilot session to paste output and ask questions
```

## Building Container Images

Each scenario ships a `Dockerfile`. Build and push images to the cluster's
attached registry with `az acr build` (no local Docker required) — or let the
deploy helper do it with `--build`:

```bash
# Discover the registry name from the resource group
ACR_NAME=$(az acr list -g ghcp-demo-rg --query "[0].name" -o tsv)

# Build & push directly in ACR
az acr build --registry "$ACR_NAME" --image crashloop-demo:v1 scenarios/01-crashloopbackoff

# …or build + deploy in one step
cd scenarios && ./deploy.sh 01-crashloopbackoff --build
```

The manifests reference images as `${ACR_LOGIN_SERVER}/<image>:<tag>`; the deploy
helper substitutes the real login server at apply time, so you never hard-code a
registry name.

> **Note for Scenario 2 (ImagePullBackOff):** only the `:v1` tag is pushed on
> purpose — the deployment intentionally requests `:latest` (which doesn't exist)
> so the image-pull failure can be demonstrated. Don't push `:latest` for that
> scenario unless you want to "fix" it.

## Next Steps

- Review each scenario's README for detailed information
- Follow the TROUBLESHOOTING_GUIDE.md for diagnostic procedures
- Experiment with different `copilot` prompts for explaining and troubleshooting output
- Extend scenarios with your own failure patterns

## Support

For questions about AKS, check the [Azure Kubernetes Service Documentation](https://docs.microsoft.com/azure/aks/)

For GitHub Copilot CLI, see [GitHub Copilot CLI Documentation](https://docs.github.com/en/copilot/copilot-cli/about-github-copilot-cli)

---

**Created**: April 2026  
**Purpose**: Demonstrate support team troubleshooting workflow with GitHub Copilot CLI
