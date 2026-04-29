# Scenario 1: CrashLoopBackOff

## Overview

This scenario demonstrates the **CrashLoopBackOff** failure pattern - one of the most common issues support teams encounter with Kubernetes deployments.

**What happens**: A container starts, runs, and immediately exits/crashes. Kubernetes sees the container died and restarts it. After several failed restart attempts with increasing delays, the pod enters `CrashLoopBackOff` state.

## The Problem

The application tries to load a configuration file at startup:

```
/app/config/application.conf
```

Since this file doesn't exist in the container, the application:

1. Throws a `FileNotFoundError`
2. Logs the error to stdout
3. Exits with code 1

Kubernetes detects the container crash and restarts it, creating a loop.

## Symptoms

When you run this scenario, you'll see:

```bash
$ kubectl get pods -n scenario-crashloop
NAME                              READY   STATUS             RESTARTS   AGE
crashloop-demo-7f8d4c9b2-abc12   0/1     CrashLoopBackOff   5          2m30s
```

**Key indicators**:

- `READY`: 0/1 (not ready)
- `STATUS`: CrashLoopBackOff (repeatedly crashing)
- `RESTARTS`: Increasing number (showing pod keeps restarting)

## Diagnosing with Copilot CLI

### Step 1: Get Pod Status

```bash
kubectl get pods -n scenario-crashloop | gh copilot explain
```

Copilot will explain that the pod is in CrashLoopBackOff state and restarting repeatedly.

### Step 2: Describe the Pod

```bash
kubectl describe pod <pod-name> -n scenario-crashloop | gh copilot explain
```

Look for the "Events" section showing container restarts and error conditions.

### Step 3: Check Pod Logs

```bash
kubectl logs <pod-name> -n scenario-crashloop | gh copilot explain
```

This will show the error message:

```
ERROR: Configuration file not found at /app/config/application.conf
FATAL: Cannot start application without configuration
```

Copilot will explain the root cause and suggest solutions.

## Root Causes in Real-World Scenarios

1. **Missing Configuration**: App expects mounted volumes or ConfigMaps that aren't defined
2. **Missing Environment Variables**: App needs env vars that aren't set
3. **Permission Issues**: App can't read required files due to permissions
4. **Dependency Issues**: Missing system libraries or dependencies
5. **Bad Code**: Application has a bug that causes immediate crash

## Solutions

### Solution 1: Mount a ConfigMap

Create a config file and mount it:

```bash
# Create a config file
echo "debug=true
database_url=postgresql://localhost/mydb" > app.conf

# Create ConfigMap
kubectl create configmap app-config --from-file=application.conf=app.conf -n scenario-crashloop

# Modify deployment to mount it:
# Add to spec.template.spec:
# volumes:
# - name: config
#   configMap:
#     name: app-config
# Add to containers[0]:
# volumeMounts:
# - name: config
#   mountPath: /app/config
```

### Solution 2: Add Environment Variables

```yaml
env:
  - name: CONFIG_PATH
    value: /app/config/application.conf
  - name: APP_ENV
    value: production
```

### Solution 3: Use init Containers

Initialize config before main app starts:

```yaml
initContainers:
  - name: init-config
    image: busybox
    command:
      [
        "sh",
        "-c",
        'mkdir -p /app/config && echo "configured" > /app/config/application.conf',
      ]
    volumeMounts:
      - name: app-storage
        mountPath: /app
```

## Try It Yourself

### 1. Deploy the Scenario

```bash
kubectl apply -f deployment.yaml
```

### 2. Monitor Pod Status

```bash
kubectl get pods -n scenario-crashloop -w
```

Watch as the pod repeatedly crashes and restarts.

### 3. Examine Logs

```bash
# Get current logs
kubectl logs -n scenario-crashloop crashloop-demo-7f8d4c9b2-abc12

# Get logs from previous run (if available)
kubectl logs -n scenario-crashloop crashloop-demo-7f8d4c9b2-abc12 --previous
```

### 4. Get Detailed Descriptions

```bash
kubectl describe pod -n scenario-crashloop crashloop-demo-7f8d4c9b2-abc12
```

### 5. Use Copilot to Explain

```bash
# Pipe any kubectl output to Copilot
kubectl logs -n scenario-crashloop crashloop-demo-7f8d4c9b2-abc12 | gh copilot explain

# Or explain events
kubectl get events -n scenario-crashloop | gh copilot explain
```

## Cleanup

```bash
kubectl delete namespace scenario-crashloop
```

## Key Takeaways

- **CrashLoopBackOff** means the container keeps exiting immediately
- Always check pod logs with `--previous` flag to see logs from crashed container
- Most often caused by configuration, environment, or permission issues
- Copilot CLI can help parse logs and identify patterns in error messages
- Event descriptions provide insight into why restarts are happening
