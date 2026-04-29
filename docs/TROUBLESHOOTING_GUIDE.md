# AKS Troubleshooting Guide

A comprehensive guide for using Copilot CLI to troubleshoot common AKS issues.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [General Troubleshooting Workflow](#general-troubleshooting-workflow)
3. [Pod-Level Issues](#pod-level-issues)
4. [Deployment Issues](#deployment-issues)
5. [Node Issues](#node-issues)
6. [Networking Issues](#networking-issues)
7. [Resource Issues](#resource-issues)
8. [Using Copilot CLI Effectively](#using-copilot-cli-effectively)

## Prerequisites

Before troubleshooting, ensure you have:

```bash
# Check kubectl is configured
kubectl cluster-info

# Verify Copilot CLI is installed
gh copilot --version

# Check permissions
kubectl auth can-i get pods --all-namespaces
```

## General Troubleshooting Workflow

```
1. Identify the problem
   └─ Check pod/deployment/node status

2. Gather information
   └─ Describe resources
   └─ Get logs
   └─ Check events

3. Analyze with Copilot
   └─ Pipe output to: gh copilot explain

4. Identify root cause
   └─ Look for patterns in logs/events

5. Implement fix
   └─ Update deployments
   └─ Verify changes

6. Monitor
   └─ Watch pod status
   └─ Verify functionality
```

## Pod-Level Issues

### Issue 1: Pod Not Starting (CrashLoopBackOff)

**Symptom**: Pod keeps restarting

```bash
# Step 1: Check pod status
kubectl get pods -n <namespace> | gh copilot explain

# Step 2: Get detailed info
kubectl describe pod <pod-name> -n <namespace> | gh copilot explain

# Step 3: Check logs (current)
kubectl logs <pod-name> -n <namespace> | gh copilot explain

# Step 4: Check logs from previous crash
kubectl logs <pod-name> -n <namespace> --previous | gh copilot explain
```

**Common causes**:

- Missing configuration files or ConfigMaps
- Invalid environment variables
- Missing dependencies or libraries
- Code errors that crash immediately
- Permission issues

**Fix approach**:

```bash
# Read logs to identify the error
kubectl logs <pod-name> -n <namespace> --previous | head -20

# Create missing ConfigMap or Secret
kubectl create configmap <name> --from-file=<file> -n <namespace>

# Update deployment with volumes
kubectl set volume deployment/<dep> --add --name=config \
  --type=configmap --configmap-name=<name> --mount-path=/etc/config

# Or directly edit deployment
kubectl edit deployment <dep> -n <namespace>
```

### Issue 2: Pod Can't Pull Image (ImagePullBackOff)

**Symptom**: Pod stuck in `ImagePullBackOff`

```bash
# Step 1: Check the error
kubectl describe pod <pod-name> -n <namespace> | gh copilot explain

# Step 2: Look specifically at events
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 "Events:" | gh copilot explain
```

**Common causes**:

- Typo in image name or tag
- Image doesn't exist in registry
- Private registry - missing credentials
- Registry is down or unreachable

**Fix approach**:

```bash
# Check if image exists (Docker Hub)
docker search <image-name>

# Check Azure Container Registry
az acr repository show-tags --registry <registry> --repository <image>

# Add image pull secret for private registry
kubectl create secret docker-registry regcred \
  --docker-server=<registry-url> \
  --docker-username=<user> \
  --docker-password=<password> \
  -n <namespace>

# Update deployment to use secret
kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "regcred"}]}' -n <namespace>

# Or fix the image name directly
kubectl set image deployment/<dep> \
  <container>=<correct-image>:<tag> \
  -n <namespace>
```

### Issue 3: Pod Running But Broken (Application Errors)

**Symptom**: Pod shows `Running` but not responding correctly

```bash
# Step 1: Verify pod is actually running
kubectl get pods -n <namespace>

# Step 2: Check application logs - this is critical!
kubectl logs <pod-name> -n <namespace> | gh copilot explain

# Step 3: Stream logs to see current behavior
kubectl logs <pod-name> -n <namespace> -f | gh copilot explain

# Step 4: Look for error patterns
kubectl logs <pod-name> -n <namespace> | grep ERROR | gh copilot explain
```

**Common causes**:

- Application-level errors (bugs in code)
- Failed connections to backend services
- Invalid configuration values
- Insufficient resources (CPU/memory)
- Database connection issues

**Fix approach**:

```bash
# Increase resources
kubectl set resources deployment/<dep> \
  --requests=cpu=500m,memory=512Mi \
  --limits=cpu=1000m,memory=1024Mi \
  -n <namespace>

# Check environment variables
kubectl set env deployment/<dep> --list -n <namespace>

# Update environment variable
kubectl set env deployment/<dep> \
  DATABASE_URL=postgresql://host:5432/db \
  -n <namespace>

# Scale up replicas
kubectl scale deployment <dep> --replicas=3 -n <namespace>
```

### Issue 4: Pod Pending

**Symptom**: Pod stuck in `Pending` state

```bash
# Step 1: Get pod details
kubectl describe pod <pod-name> -n <namespace> | gh copilot explain

# Step 2: Check events specifically
kubectl get events -n <namespace> | grep <pod-name> | gh copilot explain

# Step 3: Check node capacity
kubectl top nodes | gh copilot explain
```

**Common causes**:

- No available nodes with resources
- Node selector constraints not met
- PVC not bound
- Scheduling conflicts

**Fix approach**:

```bash
# Check node availability
kubectl get nodes
kubectl describe node <node-name>

# Remove node selectors
kubectl patch deployment <dep> --type json -p='[{"op": "remove", "path": "/spec/template/spec/nodeSelector"}]' -n <namespace>

# Scale cluster
az aks scale --resource-group <rg> --name <cluster> --node-count 3

# Check PVC status
kubectl get pvc -n <namespace>
kubectl describe pvc <pvc-name> -n <namespace>
```

## Deployment Issues

### Issue: Deployment Not Rolling Out

```bash
# Check deployment status
kubectl rollout status deployment/<dep> -n <namespace> | gh copilot explain

# Get deployment details
kubectl describe deployment <dep> -n <namespace> | gh copilot explain

# Check for recent changes
kubectl rollout history deployment/<dep> -n <namespace>
```

**Fix approach**:

```bash
# Rollback to previous version
kubectl rollout undo deployment/<dep> -n <namespace>

# Check deployment events
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -20 | gh copilot explain

# Manually trigger rollout
kubectl rollout restart deployment/<dep> -n <namespace>
```

## Node Issues

### Issue: Node NotReady

```bash
# Check node status
kubectl get nodes | gh copilot explain

# Get node details
kubectl describe node <node-name> | gh copilot explain

# Check node logs
kubectl logs -n kube-system -l component=kubelet --tail=50 | gh copilot explain
```

**Common causes**:

- Insufficient disk space
- Memory pressure
- Network issues
- Kubelet problems

**Fix approach**:

```bash
# Drain node for maintenance
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Debug node
kubectl debug node/<node-name> -it --image=ubuntu

# Re-add node
kubectl uncordon <node-name>

# Check disk usage
kubectl top nodes
```

## Networking Issues

### Issue: Pod Can't Reach Service

```bash
# Check service
kubectl get svc -n <namespace>
kubectl describe svc <svc-name> -n <namespace> | gh copilot explain

# Check endpoints
kubectl get endpoints -n <namespace> | gh copilot explain

# Test connectivity from pod
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  sh -c "wget -O- http://<svc-name>:<port>" | gh copilot explain
```

**Fix approach**:

```bash
# Check selector labels
kubectl get pods -n <namespace> --show-labels

# Update service selector if needed
kubectl patch svc <svc-name> -p '{"spec":{"selector":{"app":"myapp"}}}' -n <namespace>

# Check network policy
kubectl get networkpolicies -n <namespace>
kubectl describe networkpolicy <policy> -n <namespace>
```

## Resource Issues

### Issue: Insufficient Resources

```bash
# Check cluster capacity
kubectl top nodes
kubectl top pods -n <namespace>

# Get resource requests/limits
kubectl describe deployment <dep> -n <namespace> | grep -A 5 "Limits\|Requests"
```

**Fix approach**:

```bash
# Update resource requests
kubectl set resources deployment/<dep> \
  --requests=cpu=250m,memory=256Mi \
  --limits=cpu=500m,memory=512Mi \
  -n <namespace>

# Scale cluster
az aks scale --resource-group <rg> --name <cluster> --node-count 5

# Scale individual deployments
kubectl autoscale deployment <dep> --min=2 --max=10 -n <namespace>
```

## Using Copilot CLI Effectively

### 1. Explain Kubernetes Output

```bash
# Explain any kubectl command output
kubectl get pods | gh copilot explain
kubectl describe deployment myapp | gh copilot explain
kubectl get events | gh copilot explain
```

### 2. Explain Application Logs

```bash
# Explain logs from a pod
kubectl logs <pod-name> | gh copilot explain

# Explain specific error messages
kubectl logs <pod-name> | grep ERROR | gh copilot explain

# Explain multiple resources
kubectl logs <pod-name> && kubectl describe pod <pod-name> | gh copilot explain
```

### 3. Get Suggestions

```bash
# Interactive mode for suggestions
gh copilot suggest

# Paste your problem description
# Copilot will suggest kubectl commands
```

### 4. Save Output for Analysis

```bash
# Save output to file for detailed analysis
kubectl describe pod <pod-name> > pod-info.txt
kubectl logs <pod-name> >> pod-info.txt

# Ask Copilot about the file
cat pod-info.txt | gh copilot explain
```

### 5. Combine Multiple Sources

```bash
# Combine deployment info and logs
(kubectl describe deployment <dep>; echo "---LOGS---"; kubectl logs -l app=<app>) | gh copilot explain
```

## Quick Reference

### Essential Commands

```bash
# Get pod status
kubectl get pods -n <namespace>
kubectl get pods -n <namespace> -w  # Watch

# Describe pod
kubectl describe pod <name> -n <namespace>

# Get logs
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous  # From crash
kubectl logs <pod-name> -n <namespace> -f  # Follow
kubectl logs <pod-name> -n <namespace> --tail=50  # Last 50 lines

# Events
kubectl get events -n <namespace>
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Scale
kubectl scale deployment <name> --replicas=3 -n <namespace>

# Rollback
kubectl rollout undo deployment/<name> -n <namespace>

# Port forward
kubectl port-forward pod/<name> 8080:8080 -n <namespace>

# Execute commands
kubectl exec <pod-name> -n <namespace> -- /bin/bash
```

### Copilot CLI Workflow

```bash
# 1. Observe problem
kubectl get pods

# 2. Explain to Copilot
kubectl describe pod <failing-pod> | gh copilot explain

# 3. Get suggestions
gh copilot suggest

# 4. Check logs
kubectl logs <pod-name> | gh copilot explain

# 5. Implement fix
# (based on Copilot's analysis)

# 6. Verify
kubectl get pods -w
```

## Tips & Tricks

### Use Aliases for Speed

```bash
alias k=kubectl
alias kgp="kubectl get pods"
alias kdp="kubectl describe pod"
alias klogs="kubectl logs"

# Now: k get pods | gh copilot explain
```

### Save Time with Labels

```bash
# Label your pods
kubectl label pods <pod-name> tier=frontend -n <namespace>

# Query by label
kubectl get pods -l tier=frontend | gh copilot explain
```

### Create Debugging Pods

```bash
# Alpine-based debug pod
kubectl run -it --rm debug --image=alpine --restart=Never -- /bin/sh

# Ubuntu-based debug pod
kubectl debug node/<node-name> -it --image=ubuntu
```

### Monitor in Real-Time

```bash
# Watch pod updates
kubectl get pods -w

# Watch specific deployment
kubectl rollout status deployment/<name>

# Follow logs
kubectl logs <pod> -f | grep -E "ERROR|WARN"
```

## Additional Resources

- [Kubernetes Troubleshooting Documentation](https://kubernetes.io/docs/tasks/debug-application-cluster/)
- [AKS Troubleshooting Guide](https://docs.microsoft.com/azure/aks/troubleshooting)
- [GitHub Copilot CLI Help](https://docs.github.com/en/copilot/copilot-cli)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
