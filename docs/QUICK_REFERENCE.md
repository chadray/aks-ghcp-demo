# AKS Troubleshooting Quick Reference

A one-page reference guide for Copilot CLI troubleshooting commands.

## Essential kubectl Commands

```bash
# Get pod status
kubectl get pods -n <ns>                    # List pods
kubectl get pods -n <ns> -w                 # Watch pods
kubectl get pods --all-namespaces           # All namespaces

# Describe resources
kubectl describe pod <name> -n <ns>         # Pod details
kubectl describe deployment <name> -n <ns>  # Deployment details

# View logs
kubectl logs <pod> -n <ns>                  # Current logs
kubectl logs <pod> -n <ns> --previous       # Logs from crash
kubectl logs <pod> -n <ns> -f               # Follow logs
kubectl logs <pod> -n <ns> --tail=50        # Last 50 lines

# Events
kubectl get events -n <ns>                  # Recent events
kubectl get events -n <ns> --sort-by='.lastTimestamp'  # Sorted

# Debugging
kubectl describe pod <name> -n <ns> | grep -i error    # Find errors
kubectl exec <pod> -n <ns> -- /bin/bash                # Shell access
kubectl top nodes                           # Resource usage
```

## Copilot CLI Commands

```bash
# Explain any output
gh copilot explain                           # Interactive mode
kubectl get pods | gh copilot explain       # Pipe output
kubectl logs <pod> | gh copilot explain     # Explain logs

# Get suggestions
gh copilot suggest                           # Interactive suggestions
```

## Common Issues & Quick Fixes

### 🔴 CrashLoopBackOff

```bash
# 1. Check pod status
kubectl get pods -n <ns> | gh copilot explain

# 2. Get logs from crash
kubectl logs <pod> -n <ns> --previous | gh copilot explain

# 3. Common fixes
# - Mount missing ConfigMap
# - Add environment variables
# - Fix application code
```

### 🟠 ImagePullBackOff

```bash
# 1. Describe to see error
kubectl describe pod <pod> -n <ns> | gh copilot explain

# 2. Fix incorrect image tag
kubectl set image deployment/<dep> \
  <container>=<correct-image>:<tag> -n <ns>

# 3. For private registry
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<user> \
  --docker-password=<pass> -n <ns>
```

### 🟡 Pod Running but Broken

```bash
# 1. Check application logs (not pod status!)
kubectl logs <pod> -n <ns> | gh copilot explain

# 2. Follow logs to see real-time issues
kubectl logs <pod> -n <ns> -f

# 3. Look for error patterns
kubectl logs <pod> -n <ns> | grep ERROR | gh copilot explain

# 4. Scale or increase resources
kubectl scale deployment <dep> --replicas=3 -n <ns>
kubectl set resources deployment/<dep> \
  --requests=cpu=500m,memory=512Mi \
  --limits=cpu=1000m,memory=1024Mi -n <ns>
```

### ⚪ Pod Pending

```bash
# 1. Check why it's pending
kubectl describe pod <pod> -n <ns> | gh copilot explain

# 2. Check node capacity
kubectl top nodes | gh copilot explain

# 3. Scale cluster if needed
az aks scale --resource-group <rg> --name <cluster> --node-count 3
```

### 🔵 Pod Stuck in Unknown

```bash
# 1. Check node status
kubectl get nodes | gh copilot explain

# 2. Check pod details
kubectl describe pod <pod> -n <ns> | gh copilot explain

# 3. Force delete if necessary (last resort)
kubectl delete pod <pod> -n <ns> --force --grace-period=0
```

## Diagnostic Workflow

```
1. kubectl get pods                    ← See what's wrong
           ↓
2. kubectl describe pod <name>         ← Get more details
           ↓
3. kubectl logs <pod> (--previous)     ← Check logs
           ↓
4. Pipe to: | gh copilot explain      ← Get Copilot's analysis
           ↓
5. gh copilot suggest                 ← Get fix suggestions
           ↓
6. Apply fix                          ← Implement
           ↓
7. kubectl get pods -w                ← Watch recovery
```

## Useful Aliases

```bash
# Add to ~/.bashrc or ~/.zshrc:
alias k='kubectl'
alias kg='kubectl get'
alias kgp='kubectl get pods'
alias kgd='kubectl get deployment'
alias kdp='kubectl describe pod'
alias klogs='kubectl logs'
alias kex='kubectl exec -it'
alias kctx='kubectl config current-context'

# Usage:
# kgp                           # List pods
# kdp <pod-name>               # Describe pod
# klogs <pod-name> | gh copilot explain
```

## Status Reference

| Status              | Meaning                    | Action                           |
| ------------------- | -------------------------- | -------------------------------- |
| `Pending`           | Resource not available     | Check nodes, scale cluster       |
| `ContainerCreating` | Container being downloaded | Wait a moment                    |
| `Running`           | Pod is running             | Check application logs if broken |
| `CrashLoopBackOff`  | Container keeps crashing   | Check logs --previous            |
| `ImagePullBackOff`  | Can't pull image           | Fix image name or registry       |
| `Completed`         | Job finished successfully  | Expected for jobs                |
| `Failed`            | Pod failed                 | Check logs and events            |
| `Unknown`           | Unclear status             | Check node/kubelet               |

## Event Types

| Type      | Meaning           | Priority    |
| --------- | ----------------- | ----------- |
| `Normal`  | Routine operation | ℹ️ Info     |
| `Warning` | Potential problem | ⚠️ Warning  |
| `Error`   | Problem occurred  | 🔴 Critical |

## Resource Limits Check

```bash
# Current usage
kubectl top nodes           # Node usage
kubectl top pods -n <ns>    # Pod usage

# Request/Limits
kubectl describe pod <pod> -n <ns> | grep -A 3 'Requests\|Limits'

# Edit if needed
kubectl set resources deployment/<dep> \
  --requests=cpu=100m,memory=128Mi \
  --limits=cpu=500m,memory=512Mi -n <ns>
```

## Port Forwarding (Testing)

```bash
# Access pod directly
kubectl port-forward pod/<pod> 8080:8080 -n <ns> &

# Access service
kubectl port-forward svc/<svc> 8080:8080 -n <ns> &

# Test the connection
curl http://localhost:8080/health

# Kill port forward
kill %1  # or Ctrl+C
```

## Rollback Deployment

```bash
# View rollout history
kubectl rollout history deployment/<dep> -n <ns>

# Rollback to previous version
kubectl rollout undo deployment/<dep> -n <ns>

# Rollback to specific revision
kubectl rollout undo deployment/<dep> --to-revision=2 -n <ns>

# Check rollout status
kubectl rollout status deployment/<dep> -n <ns>
```

## Copy Files

```bash
# From pod to local
kubectl cp <ns>/<pod>:/path/to/file ./file -n <ns>

# From local to pod
kubectl cp ./file <ns>/<pod>:/path/to/file -n <ns>
```

## Monitoring Commands

```bash
# Watch pod startup
watch -n 1 'kubectl get pods -n <ns>'

# Follow multiple logs
kubectl logs -n <ns> -f -l app=<label> --all-containers

# Stream all events
kubectl get events -n <ns> -w

# Monitor resources in real-time
watch 'kubectl top pods -n <ns>'
```

## Useful Flags

```bash
# Output formats
-o yaml              # YAML output
-o json              # JSON output
-o wide              # Extended output
-o custom-columns    # Custom columns

# Selection
-l key=value        # Label selector
-n <namespace>      # Namespace
--all-namespaces    # All namespaces

# Watch/Follow
-w                  # Watch for changes
-f                  # Follow logs

# Help
--help              # Show command help
-h                  # Short help
```

## Common Mistakes to Avoid

❌ Don't:

- Forget to specify namespace (`-n <namespace>`)
- Use old pod logs without `--previous`
- Ignore events
- Scale pods without checking logs first
- Delete pods instead of fixing the issue

✅ Do:

- Always check logs first
- Use `kubectl describe` for context
- Ask Copilot to explain output
- Create aliases for faster typing
- Save diagnostic info for analysis

## Emergency Commands

```bash
# Delete pod (will be recreated by deployment)
kubectl delete pod <pod> -n <ns>

# Delete pod immediately
kubectl delete pod <pod> -n <ns> --force --grace-period=0

# Restart deployment
kubectl rollout restart deployment/<dep> -n <ns>

# Scale to 0 then back up (hard restart)
kubectl scale deployment/<dep> --replicas=0 -n <ns>
sleep 2
kubectl scale deployment/<dep> --replicas=3 -n <ns>
```

## Learn More

- Full guide: `docs/GETTING_STARTED.md`
- Detailed troubleshooting: `docs/TROUBLESHOOTING_GUIDE.md`
- Copilot CLI usage: `docs/COPILOT_CLI_GUIDE.md`
- Scenario details: `scenarios/*/README.md`
