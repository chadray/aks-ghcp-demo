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

## Diagnosing with Copilot CLI

This scenario showcases where Copilot CLI truly adds value - parsing complex logs and identifying patterns.

### Step 1: Get Pod Status (Looks Good)

```bash
kubectl get pods -n scenario-applogs | gh copilot explain
```

Output will show the pod is running - no obvious problems.

### Step 2: Test the Application

```bash
# Port forward to the application
kubectl port-forward -n scenario-applogs svc/applogs-demo 8080:8080 &

# Make a request
curl http://localhost:8080/api/data
```

You'll see errors intermittently.

### Step 3: Check Logs (This is where the issue is!)

```bash
kubectl logs -n scenario-applogs <pod-name> | gh copilot explain
```

Copilot will parse the logs and identify:

- Database connection timeout errors
- Connection pool exhaustion
- Error patterns and frequency

### Step 4: Get More Context

```bash
# Get the last 50 lines of logs
kubectl logs -n scenario-applogs <pod-name> --tail=50 | gh copilot explain

# Stream logs in real-time and explain
kubectl logs -n scenario-applogs <pod-name> -f | gh copilot explain
```

### Step 5: Interactive Analysis

```bash
# Use interactive mode with Copilot
gh copilot explain

# Paste log output or kubectl command results
# Ask specific questions about error patterns
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
# Pipe logs directly to Copilot
kubectl logs -n scenario-applogs <pod-name> | gh copilot explain

# Or save and analyze
kubectl logs -n scenario-applogs <pod-name> > app-logs.txt
cat app-logs.txt | gh copilot explain

# Get specific error patterns
kubectl logs -n scenario-applogs <pod-name> | grep ERROR | gh copilot explain
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

### 8. Verify Fix

```bash
# Monitor the logs for errors
kubectl logs -n scenario-applogs <pod-name> -f | grep -E "(ERROR|SUCCESS)"

# Check if error rate decreased
kubectl logs -n scenario-applogs <pod-name> --since=5m | grep ERROR | wc -l
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

## Advanced: Log Analysis with Copilot

Save logs to a file for deeper analysis:

```bash
# Get all logs since pod start
kubectl logs -n scenario-applogs <pod-name> > pod-logs.txt

# Ask Copilot specific questions
echo "What is causing the database errors?" | gh copilot explain pod-logs.txt

# Or use as context for troubleshooting
cat pod-logs.txt | gh copilot suggest
```

Copilot will help you:

- Identify error patterns
- Suggest root causes
- Recommend fixes
- Estimate severity
