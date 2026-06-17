# Scenario 3: Application Error in Logs

## Overview

This scenario demonstrates the case where a pod **appears healthy** but has errors in its logs. The container:

- Starts successfully
- Passes health/readiness checks
- Shows as `Running` in Kubernetes
- **But** has business logic errors that only appear when reading the logs

This is a common real-world scenario where the application is partially functional but has underlying issues that require log analysis to diagnose.

## The Problem

The application:

1. ✅ Starts up and initializes successfully
2. ✅ Responds to health checks (`/health`)
3. ✅ Responds to readiness checks (`/ready`)
4. ✅ Pod status shows `Running`
5. ❌ **BUT**: When handling requests, it fails ~40% of the time with database connection errors
6. ❌ These errors are only visible in the application logs

From Kubernetes perspective, the pod is healthy. From an application perspective, it's failing silently.

## Symptoms

When you run this scenario, you'll see:

```bash
$ kubectl get pods -n scenario-applogs
NAME                              READY   STATUS    RESTARTS   AGE
applogs-demo-5a8b3c2-def45        1/1     Running   0          2m

$ kubectl top pods -n scenario-applogs
NAME                              CPU(m)  MEMORY(Mi)
applogs-demo-5a8b3c2-def45        50m     45Mi
```

**Key indicators**:

- `READY`: 1/1 ✅ (Kubernetes thinks it's ready)
- `STATUS`: Running ✅ (appears healthy)
- `RESTARTS`: 0 ✅ (never crashed)
- But when querying the application: 40% error rate

**You must read logs to find the problem!**

## Part A — Diagnose It Manually

This is the "old school" workflow: run `kubectl` yourself and read the output.
The catch with this scenario is that **pod status tells you nothing is wrong** —
you have to go into the logs.

### Step 1: Check Pod Status (Looks Healthy)

```bash
kubectl get pods -n scenario-applogs
```

```
NAME                            READY   STATUS    RESTARTS   AGE
applogs-demo-58cf69c8d8-j2mfn   1/1     Running   0          2m
```

`1/1 Running`, `0` restarts — from Kubernetes' point of view this pod is
perfectly healthy. Save the pod name for the next steps:

```bash
POD=$(kubectl get pods -n scenario-applogs -l app=demo-app -o jsonpath='{.items[0].metadata.name}')
echo "$POD"
```

### Step 2: Generate Some Traffic

The errors only happen while the app handles requests, so drive a little load
through the `/api/data` endpoint (it fails ~40% of the time on purpose):

```bash
kubectl run loadgen --rm -i --restart=Never --image=curlimages/curl -n scenario-applogs -- \
  sh -c 'for i in $(seq 1 30); do curl -s -o /dev/null http://applogs-demo:8080/api/data; done; echo done'
```

### Step 3: Read the Logs (the problem lives here)

```bash
kubectl logs "$POD" -n scenario-applogs
```

You'll see normal `INFO` lines interleaved with bursts of errors:

```
[...] [INFO]  [PID:1] [REQ:00013] Processing /api/data request
[...] [ERROR] [PID:1] [REQ:00013] Database connection timeout after 30000ms
[...] [ERROR] [PID:1] [REQ:00013] Failed to retrieve customer data from database
[...] [WARN]  [PID:1] [REQ:00013] Retrying operation (attempt 1/3)
[...] [ERROR] [PID:1] [REQ:00013] Retry failed: Connection pool exhausted
```

### Step 4: Quantify It

Filter for just the error lines and count them to gauge severity:

```bash
# Show only the error/warning lines
kubectl logs "$POD" -n scenario-applogs | grep -E 'ERROR|WARN'

# Count errors
kubectl logs "$POD" -n scenario-applogs | grep -c ERROR
```

**Root cause:** the application is up and passing health probes, but ~40% of
`/api/data` calls fail with database connection timeouts and connection-pool
exhaustion. None of this is visible in `kubectl get pods` — only in the logs.

## Part B — Diagnose It with Copilot CLI

This scenario is where Copilot CLI really shines: parsing a wall of log lines
and summarizing the error pattern, frequency, and likely root cause for you.

> **Important — don't pipe into Copilot.** The GitHub Copilot CLI (`copilot`)
> does **not** read piped `stdin` as context. If you run
> `kubectl logs ... | copilot -p "..."`, Copilot sees an empty prompt and
> replies that there's no log data. Instead, embed the command's output
> **inside** the prompt using shell command substitution `$(...)`.

### Step 1: Confirm the Pod Looks Fine

```bash
copilot -p "Explain this Kubernetes pod status in plain English and tell me if anything is wrong:

$(kubectl get pods -n scenario-applogs)"
```

Copilot will note the pod is Running and healthy — no obvious problem yet.

### Step 2: Hand It the Logs and Ask for the Pattern

This is the key step — feed the logs in and let Copilot find the issue:

```bash
copilot -p "Explain these application logs in plain English. What is the error pattern, how often is it happening, and how do I fix it?

$(kubectl logs "$POD" -n scenario-applogs)"
```

Copilot will identify the database connection timeouts, the connection-pool
exhaustion, the retry-then-fail pattern, and suggest remediations.

### Step 3: Focus on Just the Errors

For a tighter signal, send only the error lines:

```bash
copilot -p "These are the error lines from a service. Explain what is going wrong in plain English and how to fix it:

$(kubectl logs "$POD" -n scenario-applogs | grep -E 'ERROR|WARN')"
```

> **Tip:** Because this `copilot` is agentic, you can also let it run the
> commands itself instead of substituting output — just add `--allow-all-tools`
> and describe the task:
>
> ```bash
> copilot --allow-all-tools -p "The pod in namespace scenario-applogs is Running but may be logging errors. Pull its logs with kubectl, explain the error pattern in plain English, and tell me how to fix it."
> ```

### One-liner: status + logs in a single prompt

```bash
copilot -p "This pod looks healthy but may be failing requests. Explain what is wrong in plain English and how to fix it.

=== STATUS ===
$(kubectl get pods -n scenario-applogs)

=== LOGS ===
$(kubectl logs "$POD" -n scenario-applogs)"
```

## Root Causes in Real-World Scenarios

1. **Resource Exhaustion**: Database connection pool limit hit
2. **Memory Leaks**: Gradual memory increase causes issues over time
3. **Network Issues**: Intermittent network failures to backend services
4. **Rate Limiting**: Being rate-limited by external APIs
5. **Data Issues**: Specific data inputs cause processing errors
6. **Configuration Errors**: Wrong settings for external services
7. **Timing Issues**: Race conditions that occur intermittently
8. **Third-party Service Issues**: Backend services returning errors

## Solutions

### Solution 1: Increase Connection Pool

```yaml
env:
  - name: DB_POOL_SIZE
    value: "30"
  - name: DB_TIMEOUT
    value: "60000"
```

### Solution 2: Add Retry Logic

```yaml
env:
  - name: RETRY_ATTEMPTS
    value: "3"
  - name: RETRY_BACKOFF_MS
    value: "1000"
```

### Solution 3: Scale Replicas

If one pod can't handle the load:

```bash
kubectl scale deployment applogs-demo --replicas=3 -n scenario-applogs
```

### Solution 4: Add Monitoring and Alerts

```bash
# Export metrics to monitoring system
kubectl logs -n scenario-applogs <pod-name> | grep ERROR | wc -l
```

**PowerShell equivalent:**

```powershell
# Export metrics to monitoring system
(kubectl logs -n scenario-applogs <pod-name> | Select-String "ERROR").Count
```

## Try It Yourself

### 1. Deploy the Scenario

```bash
kubectl apply -f deployment.yaml
```

### 2. Verify Pod is Running

```bash
kubectl get pods -n scenario-applogs
kubectl describe pod -n scenario-applogs <pod-name>
```

Everything looks healthy!

### 3. Generate Load

```bash
# Create a simple load generator
kubectl run -it --rm load-gen --image=curlimages/curl --restart=Never -- \
  /bin/sh -c "for i in {1..100}; do curl http://applogs-demo:8080/api/data; sleep 1; done"
```

Or from your local machine:

```bash
for i in {1..20}; do
  curl http://localhost:8080/api/data 2>/dev/null
  echo ""
  sleep 0.5
done
```

**PowerShell equivalent:**

```powershell
1..20 | ForEach-Object {
  try { curl.exe http://localhost:8080/api/data 2>$null } catch {}
  Write-Host ""
  Start-Sleep -Milliseconds 500
}
```

### 4. Read the Application Logs

```bash
# Get current logs
kubectl logs -n scenario-applogs <pod-name>

# Get logs from the last 5 minutes
kubectl logs -n scenario-applogs <pod-name> --since=5m

# Follow logs in real-time
kubectl logs -n scenario-applogs <pod-name> -f
```

You'll see output like:

```
[2024-04-21T10:15:30.123456] [INFO] [PID:1] [REQ:00001] Processing /api/data request
[2024-04-21T10:15:30.234567] [DEBUG] [PID:1] [REQ:00001] Attempting database connection
[2024-04-21T10:15:30.456789] [ERROR] [PID:1] [REQ:00001] Database connection timeout after 30000ms
[2024-04-21T10:15:30.567890] [ERROR] [PID:1] [REQ:00001] Failed to retrieve customer data from database
[2024-04-21T10:15:30.678901] [WARN] [PID:1] [REQ:00001] Retrying operation (attempt 1/3)
[2024-04-21T10:15:30.789012] [ERROR] [PID:1] [REQ:00001] Retry failed: Connection pool exhausted
```

### 5. Use Copilot to Analyze

```bash
# Capture the pod name
POD=$(kubectl get pods -n scenario-applogs -l app=demo-app -o jsonpath='{.items[0].metadata.name}')

# Embed the logs into the prompt with $(...) — do NOT pipe into copilot
copilot -p "Explain these logs in plain English and how to troubleshoot the errors:

$(kubectl logs -n scenario-applogs "$POD")"

# Focus on just the error lines
copilot -p "Explain these errors in plain English and how to fix them:

$(kubectl logs -n scenario-applogs "$POD" | grep ERROR)"
```

### 6. Check Error Rate

```bash
# Count errors in logs
kubectl logs -n scenario-applogs <pod-name> | grep -c ERROR

# Get error percentage
total=$(kubectl logs -n scenario-applogs <pod-name> | grep -c "Processing request")
errors=$(kubectl logs -n scenario-applogs <pod-name> | grep -c ERROR)
echo "Error rate: $(echo "scale=2; $errors * 100 / $total" | bc)%"
```

**PowerShell equivalent:**

```powershell
# Count errors in logs
(kubectl logs -n scenario-applogs <pod-name> | Select-String "ERROR").Count

# Get error percentage
$total  = (kubectl logs -n scenario-applogs <pod-name> | Select-String "Processing request").Count
$errors = (kubectl logs -n scenario-applogs <pod-name> | Select-String "ERROR").Count
$rate   = if ($total -gt 0) { [math]::Round($errors * 100 / $total, 2) } else { 0 }
Write-Host "Error rate: $rate%"
```

### 7. Implement Fix

Common fixes:

```bash
# Increase replicas to distribute load
kubectl scale deployment applogs-demo --replicas=3 -n scenario-applogs

# Update with more resources
kubectl set resources deployment applogs-demo \
  --requests=cpu=200m,memory=256Mi \
  --limits=cpu=400m,memory=512Mi \
  -n scenario-applogs
```

**PowerShell equivalent:**

```powershell
# Increase replicas to distribute load
kubectl scale deployment applogs-demo --replicas=3 -n scenario-applogs

# Update with more resources
kubectl set resources deployment applogs-demo `
  --requests=cpu=200m,memory=256Mi `
  --limits=cpu=400m,memory=512Mi `
  -n scenario-applogs
```

### 8. Verify Fix

```bash
# Monitor the logs for errors
kubectl logs -n scenario-applogs <pod-name> -f | grep -E "(ERROR|SUCCESS)"

# Check if error rate decreased
kubectl logs -n scenario-applogs <pod-name> --since=5m | grep ERROR | wc -l
```

**PowerShell equivalent:**

```powershell
# Monitor the logs for errors
kubectl logs -n scenario-applogs <pod-name> -f | Select-String "ERROR|SUCCESS"

# Check if error rate decreased
(kubectl logs -n scenario-applogs <pod-name> --since=5m | Select-String "ERROR").Count
```

## Cleanup

```bash
kubectl delete namespace scenario-applogs
```

## Key Takeaways

- **Not all issues are visible in pod status** - a `Running` pod can still have problems
- **Logs are the primary diagnostic tool** - they contain the real error messages
- **Kubernetes health checks only verify availability, not correctness** - a pod can pass `/health` but still be failing
- **Error patterns in logs reveal root causes** - frequency, timing, and error messages tell the story
- **Copilot CLI excels at log analysis** - it can summarize large logs and identify patterns quickly
- **Real-world applications often fail partially** - not a total crash, but degraded functionality
- **Monitoring and alerting are critical** - you need to know when error rates exceed thresholds
- The `copilot` CLI does not read piped `stdin` — embed `kubectl logs` output in the prompt with `$(...)` to turn a wall of logs into a plain-English summary with fixes

## Advanced: Log Analysis with Copilot

Save logs to a file for deeper analysis, then embed the file contents into the
prompt with `$(...)`:

```bash
# Get all logs since pod start
kubectl logs -n scenario-applogs "$POD" > pod-logs.txt

# Ask Copilot specific questions about the saved logs
copilot -p "What is causing the database errors in these logs? Explain in plain English and how to fix it:

$(cat pod-logs.txt)"

# Or have it suggest next troubleshooting steps
copilot -p "Based on these logs, what should I do next to troubleshoot and fix the errors?

$(cat pod-logs.txt)"
```

Copilot will help you:

- Identify error patterns
- Suggest root causes
- Recommend fixes
- Estimate severity
