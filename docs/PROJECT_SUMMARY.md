# Project Summary & Navigation

## What You've Built

A complete, production-ready GitHub Copilot CLI troubleshooting demo for Azure Kubernetes Service (AKS) that enables support teams to diagnose and resolve common Kubernetes failures.

## Project Structure

```
aks-ghcp-demo/
│
├── README.md                           # Main project overview
│
├── infrastructure/                     # AKS Cluster Infrastructure
│   ├── main.bicep                     # Bicep template for AKS deployment
│   ├── parameters.json                # Deployment parameters
│   └── README.md                      # Infrastructure setup guide
│
├── scenarios/                          # Three failure scenarios
│   ├── 01-crashloopbackoff/           # Scenario 1: Pod crashes on startup
│   │   ├── app.py                     # Python application code
│   │   ├── Dockerfile                 # Container image definition
│   │   ├── deployment.yaml            # Kubernetes deployment manifest
│   │   └── README.md                  # Detailed scenario documentation
│   │
│   ├── 02-imagepullbackoff/           # Scenario 2: Cannot pull image
│   │   ├── app.py                     # Working application code
│   │   ├── Dockerfile                 # Container image definition
│   │   ├── deployment.yaml            # Deployment with invalid image
│   │   └── README.md                  # Detailed scenario documentation
│   │
│   └── 03-application-logs/           # Scenario 3: Errors in application logs
│       ├── app.py                     # App that runs but has errors
│       ├── Dockerfile                 # Container image definition
│       ├── deployment.yaml            # Kubernetes deployment manifest
│       └── README.md                  # Detailed scenario documentation
│
└── docs/                               # Comprehensive documentation
    ├── GETTING_STARTED.md             # Step-by-step setup guide
    ├── TROUBLESHOOTING_GUIDE.md       # Detailed troubleshooting procedures
    ├── COPILOT_CLI_GUIDE.md           # How to use Copilot CLI effectively
    └── QUICK_REFERENCE.md             # One-page cheat sheet
```

## Key Components

### 1. Infrastructure (`infrastructure/`)

- **Bicep template** to deploy a complete AKS cluster with:
  - Managed Kubernetes cluster
  - 2 nodes (configurable)
  - Log Analytics monitoring enabled
  - Azure RBAC enabled
- **Parameters file** for easy customization
- **Documentation** for deployment and troubleshooting

### 2. Scenario 1: CrashLoopBackOff (`scenarios/01-crashloopbackoff/`)

**What it demonstrates:**

- Container immediately crashes on startup
- Pod restarts repeatedly in a loop
- Clear error messages in logs

**Why it matters:**

- Most common failure in production environments
- Demonstrates pod status vs. logs investigation

**Key files:**

- `app.py`: Python app that fails to find config file
- `deployment.yaml`: Kubernetes deployment
- `README.md`: Complete diagnostic guide

### 3. Scenario 2: ImagePullBackOff (`scenarios/02-imagepullbackoff/`)

**What it demonstrates:**

- Container image cannot be pulled from registry
- Pod stuck in backoff retry state
- Image pull error messages

**Why it matters:**

- Common cause of deployment failures
- Often due to typos or incorrect registry settings

**Key files:**

- `deployment.yaml`: References non-existent image tag
- `README.md`: Image pull troubleshooting guide

### 4. Scenario 3: Application Errors in Logs (`scenarios/03-application-logs/`)

**What it demonstrates:**

- Pod appears healthy but has application errors
- Kubernetes thinks it's fine, but app is failing
- Errors only visible by reading logs

**Why it matters:**

- Most realistic real-world scenario
- Shows need to look deeper than pod status

**Key files:**

- `app.py`: App with intermittent database connection errors
- `deployment.yaml`: Healthy-looking deployment
- `README.md`: Log analysis troubleshooting guide

### 5. Documentation

#### [GETTING_STARTED.md](docs/GETTING_STARTED.md)

- **Purpose**: Step-by-step setup guide
- **Contents**:
  - 5-minute quick start
  - Prerequisites and installation
  - Detailed deployment steps
  - Running each scenario
  - Demo workflows (for presenters)
  - Cleanup procedures

#### [TROUBLESHOOTING_GUIDE.md](docs/TROUBLESHOOTING_GUIDE.md)

- **Purpose**: Comprehensive troubleshooting reference
- **Contents**:
  - General troubleshooting workflow
  - Pod-level issues and solutions
  - Deployment issues
  - Node issues
  - Networking issues
  - Resource issues
  - Using Copilot CLI effectively
  - Quick reference commands

#### [COPILOT_CLI_GUIDE.md](docs/COPILOT_CLI_GUIDE.md)

- **Purpose**: How to use GitHub Copilot CLI for troubleshooting
- **Contents**:
  - What is GitHub Copilot CLI
  - Core commands explained
  - Practical troubleshooting workflows
  - Real-world examples
  - Advanced usage techniques
  - Comparison before/after Copilot
  - Tips for effective use

#### [QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md)

- **Purpose**: One-page reference card
- **Contents**:
  - Essential kubectl commands
  - Copilot CLI commands
  - Quick fixes for common issues
  - Status reference table
  - Useful aliases
  - Emergency commands

## Getting Started

### Minimum Time Setup (5 minutes)

```bash
cd aks-ghcp-demo
az group create --name ghcp-demo-rg --location eastus
az deployment group create --resource-group ghcp-demo-rg --template-file infrastructure/main.bicep --parameters infrastructure/parameters.json
az aks get-credentials --resource-group ghcp-demo-rg --name aks-ghcp-demo
kubectl apply -f scenarios/01-crashloopbackoff/deployment.yaml
kubectl logs -n scenario-crashloop <pod-name> --previous | gh copilot explain
```

### Complete Walkthrough (30-45 minutes)

1. Follow [GETTING_STARTED.md](docs/GETTING_STARTED.md)
2. Read each scenario's README
3. Deploy each scenario
4. Practice troubleshooting with Copilot CLI

## Use Cases

### 1. Team Training

- Train support teams on troubleshooting workflows
- Learn Kubernetes diagnostics
- Practice Copilot CLI usage

### 2. Customer Demos

- Show Copilot CLI value in production support
- Demonstrate troubleshooting speed
- Compare manual vs. AI-assisted diagnosis

### 3. Product Demos

- Demo Copilot CLI capabilities
- Show real-world AKS troubleshooting
- Highlight efficiency gains

### 4. Internal Enablement

- Onboard new support staff
- Standardize troubleshooting procedures
- Build institutional knowledge

## Demo Scenarios

### 5-Minute Demo

1. Deploy cluster
2. Show pod in CrashLoopBackOff
3. Pipe logs to Copilot
4. Show diagnosis in seconds

### 15-Minute Demo

1. Deploy cluster
2. Deploy all three scenarios
3. Troubleshoot each with Copilot
4. Show solutions for each

### 45-Minute Deep Dive

1. Setup phase (10 min)
2. Manual troubleshooting (10 min) - show the difficulty
3. Copilot CLI troubleshooting (10 min) - show the difference
4. Fixes and verification (10 min)
5. Q&A (5 min)

## Key Features

✅ **Complete Infrastructure** - Bicep template ready to deploy
✅ **Three Scenarios** - Covers common failure patterns
✅ **Realistic Applications** - Python apps with real failure modes
✅ **Comprehensive Docs** - Step-by-step guides for every scenario
✅ **Best Practices** - Kubernetes and troubleshooting best practices built in
✅ **Extensible** - Easy to add more scenarios
✅ **Production-Ready** - All YAML and code follow best practices

## Customization

### Add New Scenarios

1. Create folder: `scenarios/04-your-scenario/`
2. Create `app.py` with your failure pattern
3. Create `Dockerfile`
4. Create `deployment.yaml`
5. Create `README.md` with documentation

### Customize Parameters

- Modify `infrastructure/parameters.json` for cluster size
- Change node count, VM size, Kubernetes version
- Customize per your requirements

### Build Custom Images

- Build and push to your registry: `docker build -t your-registry/scenario:v1.0 .`
- Update `deployment.yaml` image references
- Deploy scenarios with your custom images

## Learning Objectives

After completing this demo, participants will understand:

- ✅ How to diagnose Kubernetes pod failures
- ✅ Common failure patterns and root causes
- ✅ How to use kubectl commands effectively
- ✅ How Copilot CLI accelerates troubleshooting
- ✅ Differences between pod status and application health
- ✅ How to read and interpret Kubernetes logs
- ✅ Best practices for AKS troubleshooting
- ✅ How to build troubleshooting workflows

## Resources

- [Main README](README.md) - Project overview
- [Getting Started](docs/GETTING_STARTED.md) - Setup guide
- [Troubleshooting Guide](docs/TROUBLESHOOTING_GUIDE.md) - Detailed procedures
- [Copilot CLI Guide](docs/COPILOT_CLI_GUIDE.md) - Tool usage
- [Quick Reference](docs/QUICK_REFERENCE.md) - Cheat sheet
- [AKS Docs](https://docs.microsoft.com/azure/aks/)
- [Kubernetes Docs](https://kubernetes.io/)
- [GitHub Copilot CLI Docs](https://docs.github.com/en/copilot/copilot-cli)

## Cleanup

To remove all resources:

```bash
az group delete --name ghcp-demo-rg --yes --no-wait
```

## Support & Contributions

This demo project is designed to be:

- **Easy to understand** - Clear, well-documented code
- **Easy to extend** - Modular scenario structure
- **Easy to share** - Self-contained with no external dependencies

Feel free to customize and extend for your organization's needs!

---

**Created**: April 2026  
**Purpose**: Demonstrate support team troubleshooting with GitHub Copilot CLI  
**Audience**: Support teams, DevOps engineers, Kubernetes operators
