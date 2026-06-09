# GitHub Copilot CLI Guide for AKS Troubleshooting

Learn how to use GitHub Copilot CLI as a troubleshooting partner for AKS issues.

## What is GitHub Copilot CLI?

GitHub Copilot CLI is a command-line interface that brings AI-powered suggestions to your terminal. For AKS troubleshooting, it helps you:

1. **Explain** complex kubectl output and errors
2. **Suggest** solutions based on error messages
3. **Understand** Kubernetes concepts and issues
4. **Diagnose** problems faster

## Installation

### Prerequisites

- GitHub CLI (`gh`) installed
- GitHub Copilot subscription or trial
- kubectl installed
- Access to an AKS cluster

### Install GitHub CLI

```bash
# macOS
brew install gh

# Linux
curl -sS https://webi.sh/gh | sh

# Windows
winget install GitHub.cli
```

### Authenticate

```bash
# Authenticate with GitHub
gh auth login

# Verify Copilot access
gh copilot --help
```

## Core Commands

### 1. `gh copilot explain`

Explain kubectl output, error messages, or Kubernetes concepts.

```bash
# Explain pod status
kubectl get pods | gh copilot explain

# Explain deployment info
kubectl describe deployment myapp | gh copilot explain

# Explain error messages
kubectl logs pod-name | grep ERROR | gh copilot explain

# Interactive explanation
gh copilot explain
# Then paste your content
```

**Use cases**:

- Confused about a pod status?
- Don't understand an error message?
- Want to learn what an event means?

**Example**:

```bash
$ kubectl get pods
NAME                              READY   STATUS             RESTARTS   AGE
myapp-5d4f6b8c9-xyz12            0/1     CrashLoopBackOff   5          2m

$ kubectl get pods | gh copilot explain
# Copilot outputs:
# This shows a pod that is crashing repeatedly. The pod has restarted 5 times
# already, indicating a problem with the container startup. Common causes...
```

### 2. `gh copilot suggest`

Get suggestions for commands or next steps.

```bash
# Get command suggestions
gh copilot suggest

# Interactive mode
# Describe your problem in natural language
# Copilot suggests kubectl commands or fixes
```

**Use cases**:

- Not sure what command to run next?
- Want suggestions on how to fix an issue?
- Need help with Kubernetes concepts?

**Example**:

```bash
$ gh copilot suggest
# You describe: "My pod keeps restarting, how do I see why?"
# Copilot suggests:
# Try: kubectl logs <pod-name> --previous
# Or: kubectl describe pod <pod-name>
# Or: kubectl get events -n <namespace>
```

## Practical Troubleshooting Workflows

### Workflow 1: Quick Pod Diagnosis

```bash
# 1. See what's wrong
kubectl get pods -n my-namespace | gh copilot explain

# 2. Get more details
kubectl describe pod <failing-pod> -n my-namespace | gh copilot explain

# 3. Check logs
kubectl logs <failing-pod> -n my-namespace | gh copilot explain

# 4. Get suggestions on fix
gh copilot suggest
```

### Workflow 2: Error Message Analysis

```bash
# 1. Find errors in logs
kubectl logs <pod-name> | grep -i error

# 2. Have Copilot explain them
kubectl logs <pod-name> | grep -i error | gh copilot explain

# 3. Get specific information
kubectl logs <pod-name> | head -50 | gh copilot explain
```

**PowerShell equivalent:**

```powershell
# 1. Find errors in logs
kubectl logs <pod-name> | Select-String -Pattern "error" -CaseSensitive:$false

# 2. Have Copilot explain them
kubectl logs <pod-name> | Select-String -Pattern "error" -CaseSensitive:$false | gh copilot explain

# 3. Get specific information
kubectl logs <pod-name> | Select-Object -First 50 | gh copilot explain
```

### Workflow 3: Event Investigation

```bash
# 1. Get recent events
kubectl get events -n my-namespace --sort-by='.lastTimestamp' | tail -20

# 2. Explain events
kubectl get events -n my-namespace --sort-by='.lastTimestamp' | gh copilot explain

# 3. Focus on specific event type
kubectl get events -n my-namespace | grep Warning | gh copilot explain
```

**PowerShell equivalent:**

```powershell
# 1. Get recent events
kubectl get events -n my-namespace --sort-by='.lastTimestamp' | Select-Object -Last 20

# 2. Explain events
kubectl get events -n my-namespace --sort-by='.lastTimestamp' | gh copilot explain

# 3. Focus on specific event type
kubectl get events -n my-namespace | Select-String "Warning" | gh copilot explain
```

### Workflow 4: Resource Investigation

```bash
# 1. Check what resources are in use
kubectl top nodes
kubectl top pods -n my-namespace

# 2. Have Copilot explain the output
kubectl top pods -n my-namespace | gh copilot explain

# 3. Get suggestions on scaling
gh copilot suggest
# Describe: "My pods are using too much memory"
```

## Real-World Examples

### Example 1: CrashLoopBackOff

```bash
# The problem
$ kubectl get pods
NAME                        READY   STATUS             RESTARTS   AGE
myapp-abc123               0/1     CrashLoopBackOff   6          3m

# Ask Copilot
$ kubectl describe pod myapp-abc123 | gh copilot explain

# Copilot explains:
# The pod is crashing repeatedly. Looking at the events:
# - Back-off restarting failed container
# - Exit code 1 indicates application error
#
# To diagnose:
# 1. Check the pod logs: kubectl logs myapp-abc123 --previous
# 2. Check if all ConfigMaps/Secrets are mounted
# 3. Verify environment variables

# Check logs
$ kubectl logs myapp-abc123 --previous | gh copilot explain

# Copilot explains:
# ERROR: Configuration file not found at /app/config/application.conf
#
# This means the application expects a config file that isn't mounted.
# Solution: Create a ConfigMap with the config file and mount it in the deployment.

# Implement fix
$ kubectl create configmap app-config --from-file=application.conf
$ kubectl edit deployment myapp
# Add volumeMounts and volumes...
```

### Example 2: ImagePullBackOff

```bash
# The problem
$ kubectl get pods
NAME                        READY   STATUS             RESTARTS   AGE
web-app-def456             0/1     ImagePullBackOff   0          2m

# Ask Copilot
$ kubectl describe pod web-app-def456 | gh copilot explain

# Copilot explains:
# The pod cannot pull its container image. Events show:
# - Failed to pull image "myregistry.io/myapp:v99.99.99": manifest not found
#
# This is usually due to:
# 1. Wrong image name or tag (typo)
# 2. Image doesn't exist in the registry
# 3. Insufficient permissions to pull from private registry

# Check registry
$ az acr repository show-tags --registry myregistry --repository myapp

# Fix: Update to correct image tag
$ kubectl set image deployment/web-app web=myregistry.io/myapp:v1.0
$ kubectl get pods -w  # Watch the fix take effect
```

### Example 3: Debugging Application Errors

```bash
# The problem: Pod shows "Running" but not working correctly
$ kubectl get pods
NAME                        READY   STATUS   RESTARTS   AGE
api-server-ghi789          1/1     Running  0          5m

# Check the logs
$ kubectl logs api-server-ghi789 | gh copilot explain

# Copilot explains:
# I see several ERROR messages in the logs:
# - Database connection timeout
# - Connection pool exhausted
# - Retry failed after 3 attempts
#
# The pod is running but failing when it tries to connect to the database.
#
# Possible causes:
# 1. Database service is down
# 2. Credentials are wrong
# 3. Connection pool size is too small
# 4. Network connectivity issue

# Investigate further
$ kubectl exec api-server-ghi789 -- nslookup database-service | gh copilot explain

# Get suggestions on fix
$ gh copilot suggest
# Describe: "Pod can't connect to database, how do I fix it?"
# Copilot suggests: Check if service exists, verify credentials, scale connection pool
```

## Advanced Usage

### 1. Combine Commands for Context

```bash
# Paste both deployment info and logs for full context
(kubectl describe deployment myapp; echo "---RECENT LOGS---"; \
  kubectl logs -l app=myapp --tail=50) | gh copilot explain
```

**PowerShell equivalent:**

```powershell
# Paste both deployment info and logs for full context
& {
  kubectl describe deployment myapp
  "---RECENT LOGS---"
  kubectl logs -l app=myapp --tail=50
} | gh copilot explain
```

### 2. Save Output for Later Analysis

```bash
# Create a diagnostic bundle
mkdir diagnostic-report
kubectl get all -n my-namespace > diagnostic-report/resources.txt
kubectl get events -n my-namespace > diagnostic-report/events.txt
kubectl logs -l app=myapp --all-containers=true > diagnostic-report/logs.txt

# Analyze each
cat diagnostic-report/events.txt | gh copilot explain
cat diagnostic-report/logs.txt | gh copilot explain
```

### 3. Parse Complex Output

```bash
# Get YAML and ask Copilot about it
kubectl get deployment myapp -o yaml | gh copilot explain

# Understand resource specs
kubectl api-resources | gh copilot explain

# Check configuration
kubectl get configmap myapp-config -o yaml | gh copilot explain
```

### 4. Debug Networking

```bash
# Test connectivity from within cluster
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  sh -c "nc -zv service-name 8080" | gh copilot explain

# Check DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup service-name | gh copilot explain
```

## Tips for Effective Use

### 1. Provide Full Context

```bash
# ❌ Poor: Just the error
# "ERROR: Connection refused"

# ✅ Better: Error with context
# kubectl describe pod myapp | grep -A 5 -B 5 "ERROR"

# ✅ Best: Full pod info plus error
# kubectl describe pod myapp && kubectl logs myapp
```

### 2. Ask Clarifying Questions

```bash
# After Copilot's explanation, ask follow-ups:
# "What does CrashLoopBackOff mean exactly?"
# "How do I check if the ConfigMap exists?"
# "What's the right way to mount volumes?"

gh copilot suggest
# Then ask your follow-up question
```

### 3. Use Labels for Faster Querying

```bash
# Instead of remembering pod names:
# Label pods: kubectl label pod myapp-abc123 tier=api
# Then query: kubectl logs -l tier=api | gh copilot explain
```

### 4. Create Aliases

```bash
alias k="kubectl"
alias kex="kubectl explain"
alias klogs="kubectl logs"

# Now: klogs myapp | gh copilot explain
```

**PowerShell equivalent:**

```powershell
Set-Alias k     kubectl
# Aliases can only point at commands, not subcommands. For multi-word
# shortcuts, define functions instead:
function kex   { kubectl explain @args }
function klogs { kubectl logs @args }

# Now: klogs myapp | gh copilot explain
```

### 5. Learn from Explanations

```bash
# Don't just get the fix - understand why
# When Copilot explains an issue:
# 1. Read the full explanation
# 2. Ask "why" questions if unclear
# 3. Take notes for similar issues later
```

## Comparison: Before vs After Copilot CLI

### Before (Without Copilot)

```
1. $ kubectl get pods
   Pod is in CrashLoopBackOff - what does that mean?

2. Search Stack Overflow / Google for "CrashLoopBackOff"

3. Try different kubectl commands to gather info

4. Read through lots of output manually

5. Maybe figure out the issue...

Total time: 10-20 minutes
```

### After (With Copilot)

```
1. $ kubectl get pods | gh copilot explain
   Copilot immediately explains CrashLoopBackOff and possible causes

2. $ kubectl logs <pod> --previous | gh copilot explain
   Copilot reads logs and identifies the specific error

3. $ gh copilot suggest
   Copilot suggests the fix

4. Apply fix

Total time: 2-3 minutes
```

## Troubleshooting Copilot CLI Itself

### Issue: "gh copilot" command not found

```bash
# Verify installation
gh --version

# Check if copilot extension is installed
gh extension list

# Install copilot if missing
gh extension install github/gh-copilot
```

### Issue: Permission denied or auth error

```bash
# Re-authenticate
gh auth logout
gh auth login

# Check token scope
gh auth status
```

### Issue: Copilot not responding helpfully

```bash
# Make sure you're providing good context
# ❌ Just a status code
# ✅ Full error message with context

# Provide more information
kubectl describe pod <name> | gh copilot explain

# Use the interactive mode
gh copilot explain
# Then paste detailed information
```

## Learning Resources

- [GitHub Copilot CLI Documentation](https://docs.github.com/en/copilot/copilot-cli)
- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug-application-cluster/)
- [AKS Best Practices](https://docs.microsoft.com/azure/aks/best-practices)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

## Summary

GitHub Copilot CLI is a powerful tool for AKS troubleshooting when you:

✅ **Use it for**:

- Understanding kubectl output
- Parsing error messages and logs
- Getting suggestions on next steps
- Learning Kubernetes concepts
- Analyzing event logs

❌ **Don't expect it to**:

- Replace your understanding of Kubernetes
- Know your specific application logic
- Fix cluster-level infrastructure issues
- Manage your cluster configuration

## Next Steps

1. **Try the demo scenarios** in this repo with Copilot CLI
2. **Create aliases** for faster workflow
3. **Save good Q&A pairs** for future reference
4. **Build a knowledge base** of Copilot explanations
5. **Train your team** on Copilot CLI usage

Happy troubleshooting! 🚀
