# Scenario 2: ImagePullBackOff

## Overview

This scenario demonstrates the **ImagePullBackOff** failure pattern - when Kubernetes cannot pull a container image from a registry.

**What happens**: Kubernetes tries to pull the image specified in the pod spec, but the image doesn't exist, is misspelled, or the credentials are invalid. The image pull fails, and Kubernetes enters a backoff retry loop.

## The Problem

The deployment references a container image that doesn't exist:

```yaml
image: docker.io/mycompany/myapp:v99.99.99
imagePullPolicy: Always
```

Since this image repository and tag don't exist:

1. The image pull command fails
2. Kubernetes waits and retries with exponential backoff
3. Each retry fails with "manifest not found" or similar error
4. Pod stays in `ImagePullBackOff` status

## Symptoms

When you run this scenario, you'll see:

```bash
$ kubectl get pods -n scenario-imagepull
NAME                              READY   STATUS             RESTARTS   AGE
imagepull-demo-5a8b3c2-def45      0/1     ImagePullBackOff   0          2m
```

**Key indicators**:

- `READY`: 0/1 (not ready)
- `STATUS`: ImagePullBackOff (cannot pull image)
- `RESTARTS`: Usually 0 (never actually started)

## Diagnosing with Copilot CLI

The pattern is the same for every command: run `kubectl`, then pipe the output
into the GitHub Copilot CLI (`copilot`) with a prompt asking it to explain the
output in plain English and troubleshoot the errors.

### Step 1: Get Pod Status

```bash
kubectl get pods -n scenario-imagepull | copilot -p "Explain this pod status in plain English and tell me what is wrong"
```

Copilot will explain that the pod cannot pull its image.

### Step 2: Describe the Pod

```bash
kubectl describe pod <pod-name> -n scenario-imagepull | copilot -p "Explain these pod events in plain English and how to troubleshoot the errors"
```

Look for the "Events" section showing image pull errors. You'll see messages like:

```
Failed to pull image "docker.io/mycompany/myapp:v99.99.99": rpc error: code = Unknown
desc = failed to pull and unpack image "docker.io/mycompany/myapp:v99.99.99":
failed to resolve reference "docker.io/mycompany/myapp:v99.99.99":
manifest not found
```

Pass this to Copilot to get a plain-English explanation:

```bash
kubectl describe pod <pod-name> -n scenario-imagepull | copilot -p "Explain these pod events in plain English and how to fix the image pull error"
```

Copilot will identify the image pull failure as the root cause.

## Root Causes in Real-World Scenarios

1. **Typo in Image Name**: Wrong repository or tag name
   - Example: `myapp:latest` vs `my-app:latest`

2. **Wrong Registry**: Image doesn't exist in the specified registry
   - Example: Using Docker Hub instead of Azure Container Registry

3. **Invalid Image Tag**: Tag doesn't exist for that image
   - Example: Specifying `v2.0.0` when only `v1.0.0` exists

4. **Image Was Deleted**: Image existed before but was removed
   - Example: Registry cleanup or expired images

5. **Authentication Issues**: Cannot access private registry
   - Example: Missing image pull secrets for private ACR

6. **Registry Down**: Registry service is unavailable
   - Example: Temporary outage or network connectivity issues

## Solutions

### Solution 1: Correct the Image Name

```yaml
# Before (wrong)
image: docker.io/mycompany/myapp:v99.99.99

# After (correct)
image: docker.io/library/myapp:v1.0.0
```

Then apply the fix:

```bash
kubectl set image deployment/imagepull-demo \
  app=docker.io/library/python:3.11-slim \
  -n scenario-imagepull
```

**PowerShell equivalent:**

```powershell
kubectl set image deployment/imagepull-demo `
  app=docker.io/library/python:3.11-slim `
  -n scenario-imagepull
```

### Solution 2: Check Available Tags

```bash
# If it's a public image on Docker Hub
docker search myapp

# If it's in Azure Container Registry
az acr repository show-tags \
  --name myregistry \
  --repository myapp
```

**PowerShell equivalent:**

```powershell
# If it's a public image on Docker Hub
docker search myapp

# If it's in Azure Container Registry
az acr repository show-tags `
  --name myregistry `
  --repository myapp
```

### Solution 3: Add Image Pull Secret for Private Registry

```bash
# Create secret for private registry
kubectl create secret docker-registry regcred \
  --docker-server=<registry-url> \
  --docker-username=<username> \
  --docker-password=<password> \
  -n scenario-imagepull

# Reference in deployment
spec:
  imagePullSecrets:
  - name: regcred
  containers:
  - name: app
    image: myregistry.azurecr.io/myapp:v1.0.0
```

**PowerShell equivalent:**

```powershell
# Create secret for private registry
kubectl create secret docker-registry regcred `
  --docker-server=<registry-url> `
  --docker-username=<username> `
  --docker-password=<password> `
  -n scenario-imagepull

# (The 'spec:' YAML fragment above is the same on Windows.)
```

### Solution 4: Use IfNotPresent Pull Policy

For development, use `IfNotPresent` to avoid repeated pull attempts:

```yaml
imagePullPolicy: IfNotPresent
```

## Try It Yourself

### 1. Deploy the Scenario

```bash
kubectl apply -f deployment.yaml
```

### 2. Monitor Pod Status

```bash
kubectl get pods -n scenario-imagepull -w
```

The pod will remain in `ImagePullBackOff` status.

### 3. Get Detailed Information

```bash
# See the specific error
kubectl describe pod -n scenario-imagepull <pod-name>

# Look for lines like:
# Events:
#   Type     Reason                Age                From                Message
#   ----     ------                ----               ----                -------
#   Normal   Scheduled             2m                 default-scheduler   Successfully assigned
#   Normal   BackOff               1m (x5 over 1m)   kubelet             Back-off pulling image
#   Warning  Failed                1m (x5 over 1m)   kubelet             Failed to pull image
```

### 4. Use Copilot to Analyze

```bash
# Get the events and have Copilot explain and troubleshoot them
kubectl describe pod -n scenario-imagepull <pod-name> | copilot -p "Explain these pod events in plain English and how to fix the errors"

# Or extract just the error message
kubectl describe pod -n scenario-imagepull <pod-name> | grep "Failed to pull" | copilot -p "Explain this error in plain English and how to fix it"
```

### 5. Fix It

Option A: Use correct image

```bash
kubectl set image deployment/imagepull-demo \
  app=docker.io/library/python:3.11-slim \
  -n scenario-imagepull
```

**PowerShell equivalent:**

```powershell
kubectl set image deployment/imagepull-demo `
  app=docker.io/library/python:3.11-slim `
  -n scenario-imagepull
```

Option B: Use Azure Container Registry

```bash
# First push an image to ACR
az acr build --registry <registry-name> --image myapp:v1.0 .

# Then update deployment
kubectl set image deployment/imagepull-demo \
  app=<registry-name>.azurecr.io/myapp:v1.0 \
  -n scenario-imagepull
```

**PowerShell equivalent:**

```powershell
# First push an image to ACR
az acr build --registry <registry-name> --image myapp:v1.0 .

# Then update deployment
kubectl set image deployment/imagepull-demo `
  app=<registry-name>.azurecr.io/myapp:v1.0 `
  -n scenario-imagepull
```

### 6. Verify It's Fixed

```bash
kubectl get pods -n scenario-imagepull -w

# Should show STATUS: Running once image is pulled
```

## Cleanup

```bash
kubectl delete namespace scenario-imagepull
```

## Key Takeaways

- **ImagePullBackOff** means the container image cannot be found or pulled
- Always check image names carefully for typos in repository or tags
- Use `kubectl describe` to see detailed error messages about pull failures
- For private registries, ensure image pull secrets are created and referenced
- Copilot CLI can help parse registry error messages and identify the root cause
- Use `imagePullPolicy: IfNotPresent` to avoid repeated pull attempts in dev environments
