# Complete Resource Index

## 📚 Documentation Files

### Getting Started

- **[GETTING_STARTED.md](docs/GETTING_STARTED.md)** ⭐ START HERE
  - 5-minute quick start
  - Detailed setup instructions
  - Running each scenario
  - Demo workflows for presenters
  - Troubleshooting setup issues

### Core Guides

- **[COPILOT_CLI_GUIDE.md](docs/COPILOT_CLI_GUIDE.md)**
  - What is GitHub Copilot CLI?
  - Installation and authentication
  - Core commands: `explain` and `suggest`
  - Practical troubleshooting workflows
  - Real-world examples with Copilot
  - Tips for effective use

- **[TROUBLESHOOTING_GUIDE.md](docs/TROUBLESHOOTING_GUIDE.md)**
  - General troubleshooting workflow
  - Detailed solutions for each issue type
  - Pod-level issues
  - Deployment issues
  - Node issues
  - Networking issues
  - Resource management issues

### References

- **[QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md)**
  - One-page command reference
  - Common issues & quick fixes
  - Status reference table
  - Useful aliases
  - Emergency commands

- **[PROJECT_SUMMARY.md](docs/PROJECT_SUMMARY.md)**
  - Project overview
  - File structure explanation
  - Component descriptions
  - Use cases and customization guide

## 🏗️ Infrastructure Setup

### Directory: `infrastructure/`

- **[main.bicep](infrastructure/main.bicep)**
  - AKS cluster deployment template
  - Configurable parameters for cluster size, location, Kubernetes version
  - Log Analytics integration
  - RBAC enabled
  - 🔧 Ready to deploy with: `az deployment group create`

- **[parameters.json](infrastructure/parameters.json)**
  - Default parameter values
  - Configure cluster name, location, node count, VM size
  - Easy to customize for your needs

- **[README.md](infrastructure/README.md)**
  - Infrastructure setup guide
  - Deployment instructions
  - Configuration options
  - Cleanup procedures
  - Troubleshooting deployment issues

## 📋 Failure Scenarios

### Scenario 1: CrashLoopBackOff

Directory: `scenarios/01-crashloopbackoff/`

- **[app.py](scenarios/01-crashloopbackoff/app.py)**
  - Python application that crashes on startup
  - Missing configuration file causes immediate exit
  - Demonstrates immediate crash pattern

- **[Dockerfile](scenarios/01-crashloopbackoff/Dockerfile)**
  - Container image definition
  - Based on Python 3.11-slim
  - Sets up unbuffered Python output

- **[deployment.yaml](scenarios/01-crashloopbackoff/deployment.yaml)**
  - Kubernetes deployment manifest
  - Creates namespace `scenario-crashloop`
  - References inline Python command

- **[README.md](scenarios/01-crashloopbackoff/README.md)** 📖
  - Complete scenario explanation
  - Symptoms and diagnosis procedures
  - Root causes in real scenarios
  - Step-by-step troubleshooting with Copilot
  - Solutions and fixes

**What you'll learn:**

- How to diagnose container crashes
- Interpreting CrashLoopBackOff status
- Using pod logs with `--previous` flag
- Real-world causes (config, dependencies, permissions)

### Scenario 2: ImagePullBackOff

Directory: `scenarios/02-imagepullbackoff/`

- **[app.py](scenarios/02-imagepullbackoff/app.py)**
  - Working HTTP server application
  - Would run fine if image could be pulled
  - Demonstrates valid app code can fail due to image issues

- **[Dockerfile](scenarios/02-imagepullbackoff/Dockerfile)**
  - Container image definition
  - Exposes port 8080

- **[deployment.yaml](scenarios/02-imagepullbackoff/deployment.yaml)**
  - Kubernetes deployment manifest
  - References non-existent image: `docker.io/mycompany/myapp:v99.99.99`
  - Always pull policy to force error

- **[README.md](scenarios/02-imagepullbackoff/README.md)** 📖
  - Scenario explanation and symptoms
  - How to diagnose with Copilot
  - Real-world root causes
  - Solutions for various scenarios
  - Steps to fix the issue

**What you'll learn:**

- Image pull failure diagnosis
- Working with container registries
- Fixing typos in image names
- Private registry authentication
- Using private ACR

### Scenario 3: Application Error in Logs

Directory: `scenarios/03-application-logs/`

- **[app.py](scenarios/03-application-logs/app.py)**
  - Python HTTP server with intentional business logic errors
  - Passes health/readiness checks
  - Fails ~40% of requests with database errors
  - Errors only visible in logs
  - Demonstrates realistic application issues

- **[Dockerfile](scenarios/03-application-logs/Dockerfile)**
  - Container image definition
  - Sets LOG_LEVEL environment variable

- **[deployment.yaml](scenarios/03-application-logs/deployment.yaml)**
  - Kubernetes deployment manifest
  - Inline Python app (comprehensive demo)
  - Includes health and readiness probes
  - Pod appears healthy despite errors

- **[README.md](scenarios/03-application-logs/README.md)** 📖
  - Scenario explanation
  - Why pod appears healthy but isn't
  - How to analyze application logs
  - Patterns in error messages
  - Solutions for connection pool, scaling, resources
  - Advanced log analysis techniques

**What you'll learn:**

- Kubernetes pod status vs. application health
- Reading and parsing application logs
- Identifying error patterns
- Database connection troubleshooting
- Resource and scaling issues

## 🗂️ Complete File Tree

```
aks-ghcp-demo/
├── README.md                                    # Main project README
├── infrastructure/
│   ├── main.bicep                              # AKS Bicep template
│   ├── parameters.json                         # Default parameters
│   └── README.md                               # Infrastructure guide
├── scenarios/
│   ├── 01-crashloopbackoff/
│   │   ├── app.py                              # Crashing app
│   │   ├── Dockerfile                          # Container image
│   │   ├── deployment.yaml                     # K8s manifest
│   │   └── README.md                           # Scenario guide
│   ├── 02-imagepullbackoff/
│   │   ├── app.py                              # Working app (won't run)
│   │   ├── Dockerfile                          # Container image
│   │   ├── deployment.yaml                     # K8s manifest
│   │   └── README.md                           # Scenario guide
│   └── 03-application-logs/
│       ├── app.py                              # App with errors
│       ├── Dockerfile                          # Container image
│       ├── deployment.yaml                     # K8s manifest
│       └── README.md                           # Scenario guide
└── docs/
    ├── GETTING_STARTED.md                      # Setup guide ⭐
    ├── TROUBLESHOOTING_GUIDE.md                # Detailed procedures
    ├── COPILOT_CLI_GUIDE.md                    # Tool usage guide
    ├── QUICK_REFERENCE.md                      # Cheat sheet
    └── PROJECT_SUMMARY.md                      # Project overview
```

## 🎯 Quick Navigation by Task

### "I want to get started quickly"

→ Read: [GETTING_STARTED.md](docs/GETTING_STARTED.md)

### "How do I use Copilot CLI?"

→ Read: [COPILOT_CLI_GUIDE.md](docs/COPILOT_CLI_GUIDE.md)

### "I'm stuck on troubleshooting"

→ Read: [TROUBLESHOOTING_GUIDE.md](docs/TROUBLESHOOTING_GUIDE.md)

### "I need quick commands"

→ Read: [QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md)

### "I want to understand a specific scenario"

→ Read scenario README:

- [Scenario 1 README](scenarios/01-crashloopbackoff/README.md)
- [Scenario 2 README](scenarios/02-imagepullbackoff/README.md)
- [Scenario 3 README](scenarios/03-application-logs/README.md)

### "How do I deploy the AKS cluster?"

→ Read: [Infrastructure README](infrastructure/README.md)

### "What's in this project?"

→ Read: [PROJECT_SUMMARY.md](docs/PROJECT_SUMMARY.md)

## 💡 Common Workflows

### Deploy and Troubleshoot Scenario 1

1. Read: [GETTING_STARTED.md](docs/GETTING_STARTED.md) (Deploy section)
2. Deploy cluster
3. Deploy scenario: `kubectl apply -f scenarios/01-crashloopbackoff/deployment.yaml`
4. Read: [Scenario 1 README](scenarios/01-crashloopbackoff/README.md)
5. Follow troubleshooting steps

### Learn Copilot CLI

1. Read: [COPILOT_CLI_GUIDE.md](docs/COPILOT_CLI_GUIDE.md) (Installation section)
2. Install GitHub CLI and Copilot
3. Follow practical workflows in guide
4. Try with deployed scenarios

### Present to Team

1. Prepare cluster: [GETTING_STARTED.md](docs/GETTING_STARTED.md) (Demo Timing section)
2. Follow demo workflow: [GETTING_STARTED.md](docs/GETTING_STARTED.md) (Demo Workflow section)
3. Reference: [COPILOT_CLI_GUIDE.md](docs/COPILOT_CLI_GUIDE.md) (Real-World Examples)
4. Have [QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md) available for Q&A

## 📊 Documentation Coverage

| Topic                      | Coverage | Best Resource                                                |
| -------------------------- | -------- | ------------------------------------------------------------ |
| Initial Setup              | ✅✅✅   | [GETTING_STARTED.md](docs/GETTING_STARTED.md)                |
| Copilot CLI Usage          | ✅✅✅   | [COPILOT_CLI_GUIDE.md](docs/COPILOT_CLI_GUIDE.md)            |
| Troubleshooting Procedures | ✅✅✅   | [TROUBLESHOOTING_GUIDE.md](docs/TROUBLESHOOTING_GUIDE.md)    |
| Quick Commands             | ✅✅     | [QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md)                |
| CrashLoopBackOff           | ✅✅✅   | [Scenario 1 README](scenarios/01-crashloopbackoff/README.md) |
| ImagePullBackOff           | ✅✅✅   | [Scenario 2 README](scenarios/02-imagepullbackoff/README.md) |
| Application Errors         | ✅✅✅   | [Scenario 3 README](scenarios/03-application-logs/README.md) |
| Infrastructure             | ✅✅     | [Infrastructure README](infrastructure/README.md)            |
| Project Overview           | ✅✅     | [PROJECT_SUMMARY.md](docs/PROJECT_SUMMARY.md)                |

## 🔄 Recommended Reading Order

1. **First Time?** Start with [README.md](README.md) for project overview
2. **Setting Up?** Go to [GETTING_STARTED.md](docs/GETTING_STARTED.md)
3. **Learning Tool?** Read [COPILOT_CLI_GUIDE.md](docs/COPILOT_CLI_GUIDE.md)
4. **Troubleshooting?** Check specific scenario README or [TROUBLESHOOTING_GUIDE.md](docs/TROUBLESHOOTING_GUIDE.md)
5. **Quick Lookup?** Use [QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md)

## ✅ Checklist for Setup

- [ ] Read [README.md](README.md)
- [ ] Read [GETTING_STARTED.md](docs/GETTING_STARTED.md)
- [ ] Install Azure CLI
- [ ] Install kubectl
- [ ] Install GitHub CLI and Copilot
- [ ] Create Azure Resource Group
- [ ] Deploy AKS cluster
- [ ] Deploy first scenario
- [ ] Test with Copilot CLI
- [ ] Read scenario README for full context
- [ ] Try other scenarios

## 📞 Need Help?

- **Setup issues?** → [GETTING_STARTED.md - Troubleshooting](docs/GETTING_STARTED.md#troubleshooting-the-demo-setup)
- **Copilot issues?** → [COPILOT_CLI_GUIDE.md - Troubleshooting](docs/COPILOT_CLI_GUIDE.md#troubleshooting-copilot-cli-itself)
- **Scenario questions?** → Read scenario README
- **General K8s help?** → [TROUBLESHOOTING_GUIDE.md](docs/TROUBLESHOOTING_GUIDE.md)
- **Quick commands?** → [QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md)

---

**Total Documentation:** 1000+ lines across 5+ guides
**Code Examples:** 50+ real-world examples
**Scenarios:** 3 production-ready failure patterns
**Infrastructure:** Complete Bicep template for AKS
