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

## Part A — Diagnose It Manually

This is the "old school" workflow: run `kubectl` yourself, read the output, and
reason about what's wrong. Walk through these steps in order during the demo.

### Step 1: Find the Failing Pod

```bash
kubectl get pods -n scenario-crashloop
```

```
NAME                            READY   STATUS             RESTARTS      AGE
crashloop-demo-877b6bdf-587x5   0/1     CrashLoopBackOff   5 (60s ago)   3m
```

Note the pod name, `0/1` READY, the `CrashLoopBackOff` status, and the climbing
`RESTARTS` count. Save the pod name into a variable so the next commands are easy
to copy/paste:

```bash
POD=$(kubectl get pods -n scenario-crashloop -o jsonpath='{.items[0].metadata.name}')
echo "$POD"
```

### Step 2: Describe the Pod

```bash
kubectl describe pod "$POD" -n scenario-crashloop
```

Scroll to the **`Last State`** and **`Events`** sections. You'll see the container
terminating with **`Exit Code: 1`** and Kubernetes backing off between restarts:

```
Last State:     Terminated
  Reason:       Error
  Exit Code:    1
...
Warning  BackOff  ...  Back-off restarting failed container
```

This tells you the container is *starting and then exiting on its own* (an
application error) — it is not being killed by Kubernetes (which would show
`OOMKilled` or a failed probe).

### Step 3: Read the Logs

The describe output tells you *that* it crashed; the logs tell you *why*. Because
the container is currently in a backoff/crashed state, use `--previous` to read
the logs from the last crashed instance:

```bash
kubectl logs "$POD" -n scenario-crashloop --previous
```

```
Application starting...
Process ID: 1
Attempting to load configuration...
ERROR: Configuration file not found at /app/config/application.conf
Details: [Errno 2] No such file or directory: '/app/config/application.conf'
FATAL: Cannot start application without configuration
HINT: Expected a volume mounted at /app/config containing application.conf
```

> If `--previous` returns "previous terminated container not found", the pod may
> currently be running between restarts — just drop the flag and run
> `kubectl logs "$POD" -n scenario-crashloop`.

**Root cause:** the app needs a config file at `/app/config/application.conf`, but
no volume is mounted there, so the file doesn't exist and the app exits with code 1.

## Part B — Diagnose It with Copilot CLI

Same investigation, but instead of eyeballing the output you hand it to the
GitHub Copilot CLI (`copilot`) and let it translate the raw Kubernetes output
into a plain-English explanation with concrete next steps. Great for newer team
members or for triaging fast.

> **Important — don't pipe into Copilot.** The GitHub Copilot CLI (`copilot`)
> does **not** read piped `stdin` as context. If you run
> `kubectl logs ... | copilot -p "..."`, Copilot sees an empty prompt and
> replies that there's no log data. Instead, embed the command's output
> **inside** the prompt using shell command substitution `$(...)`. That way the
> actual text is part of the `-p` argument Copilot receives.

### Step 1: Explain the Pod Status

```bash
copilot -p "Explain this Kubernetes pod status in plain English and tell me what is wrong:

$(kubectl get pods -n scenario-crashloop)"
```

Copilot will explain that the pod is in CrashLoopBackOff and restarting repeatedly.

### Step 2: Explain the Pod Events

```bash
copilot -p "Explain these pod events in plain English and tell me why the container is restarting:

$(kubectl describe pod "$POD" -n scenario-crashloop)"
```

Copilot summarizes the `Exit Code: 1` / `BackOff` events and points to an
application-level startup failure rather than a resource or probe problem.

### Step 3: Explain the Logs and Get a Fix

This is the key step — feed the crash logs in and ask for a remediation plan:

```bash
copilot -p "Explain these logs in plain English and tell me exactly how to fix the errors:

$(kubectl logs "$POD" -n scenario-crashloop --previous 2>&1)"
```

Copilot reads the `FileNotFoundError`, identifies the missing
`/app/config/application.conf`, and recommends mounting the config (e.g. via a
ConfigMap) at `/app/config` — which is exactly the fix in the next section.

> **Tip:** Because this `copilot` is agentic, you can also let it run the
> commands itself instead of substituting output — just add `--allow-all-tools`
> and describe the task:
>
> ```bash
> copilot --allow-all-tools -p "The pod in namespace scenario-crashloop is in CrashLoopBackOff. Investigate with kubectl, explain the root cause in plain English, and tell me how to fix it."
> ```

### One-liner: hand Copilot everything at once

For a fast triage, combine status, events, and logs into a single prompt:

```bash
copilot -p "This Kubernetes pod is failing. Explain what is wrong in plain English and give me step-by-step instructions to fix it.

=== STATUS ===
$(kubectl get pods -n scenario-crashloop)

=== DESCRIBE ===
$(kubectl describe pod "$POD" -n scenario-crashloop)

=== LOGS ===
$(kubectl logs "$POD" -n scenario-crashloop --previous 2>&1)"
```

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

**PowerShell equivalent:**

```powershell
# Create a config file
@"
debug=true
database_url=postgresql://localhost/mydb
"@ | Set-Content -Path app.conf

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

The manifest references the registry via a `${ACR_LOGIN_SERVER}` placeholder, so
use the deploy helper, which discovers the cluster's attached ACR at runtime and
substitutes it (run from the repo's `scenarios/` folder):

```bash
./deploy.sh 01-crashloopbackoff
```

Windows / PowerShell: `./deploy.ps1 01-crashloopbackoff`

> Plain `kubectl apply -f deployment.yaml` will fail because the placeholder is
> not a valid image name. If you prefer raw kubectl, substitute first:
> `ACR=$(az acr list -g ghcp-demo-rg --query "[0].loginServer" -o tsv); sed "s|\${ACR_LOGIN_SERVER}|$ACR|g" deployment.yaml | kubectl apply -f -`

### 2. Monitor Pod Status

```bash
kubectl get pods -n scenario-crashloop -w
```

Watch as the pod repeatedly crashes and restarts.

### 3. Examine Logs

```bash
# Capture the pod name
POD=$(kubectl get pods -n scenario-crashloop -o jsonpath='{.items[0].metadata.name}')

# Get logs from the last crashed instance
kubectl logs -n scenario-crashloop "$POD" --previous

# Or current logs if it happens to be running between restarts
kubectl logs -n scenario-crashloop "$POD"
```

### 4. Get Detailed Descriptions

```bash
kubectl describe pod -n scenario-crashloop "$POD"
```

### 5. Use Copilot to Explain

```bash
# Embed the logs into the prompt with $(...) — do NOT pipe into copilot
copilot -p "Explain these logs in plain English and how to fix the errors:

$(kubectl logs -n scenario-crashloop "$POD" --previous 2>&1)"

# Or embed the events the same way
copilot -p "Explain these Kubernetes events in plain English and how to troubleshoot them:

$(kubectl get events -n scenario-crashloop)"
```

## Cleanup

```bash
kubectl delete namespace scenario-crashloop
```

## Key Takeaways

- **CrashLoopBackOff** means the container keeps exiting immediately
- Always check pod logs with `--previous` flag to see logs from crashed container
- Most often caused by configuration, environment, or permission issues
- The `copilot` CLI does not read piped `stdin` — embed kubectl output in the prompt with `$(...)` to turn raw logs into a plain-English explanation with fixes
- Event descriptions provide insight into why restarts are happening
