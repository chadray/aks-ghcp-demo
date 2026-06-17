# Scenario 2: ImagePullBackOff

## Overview

This scenario demonstrates the **ImagePullBackOff** failure pattern - when Kubernetes cannot pull a container image from a registry.

**What happens**: Kubernetes tries to pull the image specified in the pod spec,
but the image tag doesn't exist in the registry (or the name is misspelled, or
the credentials are invalid). The image pull fails, and Kubernetes enters a
backoff retry loop. In this lab the cluster is attached to the
`ghcpdemoacr` ACR, and the deployment asks for a tag (`:latest`) that was never
pushed.

## The Problem

The deployment references an image **tag** that was never pushed to the
Azure Container Registry attached to the cluster:

```yaml
image: ghcpdemoacr.azurecr.io/imagepull-demo:latest
imagePullPolicy: Always
```

The `imagepull-demo` repository **does** exist in ACR, but only the `:v1` tag
was ever pushed — `:latest` does not exist. This mirrors the most common
real-world cause of `ImagePullBackOff`: deploying a tag that isn't in the
registry (typo, forgotten `docker push`, or a CI build that tagged something
different).

Because the AKS cluster is already attached to this ACR (`az aks update
--attach-acr`), authentication is **not** the problem — the registry is
reachable and authorized, but the manifest for `:latest` simply isn't there:

1. The kubelet resolves the registry and authenticates successfully
2. It requests the manifest for the `:latest` tag
3. The registry returns **not found** (the tag doesn't exist)
4. Kubernetes retries with exponential backoff and the pod stays in
   `ImagePullBackOff`

## Symptoms

When you run this scenario, you'll see:

```bash
$ kubectl get pods -n scenario-imagepull
NAME                            READY   STATUS             RESTARTS   AGE
imagepull-demo-8bbf4564-mk5km   0/1     ImagePullBackOff   0          2m
```

**Key indicators**:

- `READY`: 0/1 (not ready)
- `STATUS`: ImagePullBackOff (cannot pull image)
- `RESTARTS`: Usually 0 (never actually started)

## Part A — Diagnose It Manually

This is the "old school" workflow: run `kubectl` yourself, read the output, and
reason about what's wrong. Walk through these steps in order during the demo.

### Step 1: Find the Failing Pod

```bash
kubectl get pods -n scenario-imagepull
```

```
NAME                            READY   STATUS             RESTARTS   AGE
imagepull-demo-8bbf4564-mk5km   0/1     ImagePullBackOff   0          2m
```

Note the `0/1` READY, the `ImagePullBackOff` status, and that `RESTARTS` is `0`
— the container never started because its image could not be pulled. Save the
pod name into a variable so the next commands are easy to copy/paste:

```bash
POD=$(kubectl get pods -n scenario-imagepull -o jsonpath='{.items[0].metadata.name}')
echo "$POD"
```

### Step 2: Describe the Pod

The `Events` section is where image-pull failures show up — there are no
application logs to read because the container never ran.

```bash
kubectl describe pod "$POD" -n scenario-imagepull
```

Scroll to the **`Events`** section. You'll see `Failed` / `ErrImagePull` /
`ImagePullBackOff` with a message like:

```
Failed to pull image "ghcpdemoacr.azurecr.io/imagepull-demo:latest": ...
failed to resolve reference "ghcpdemoacr.azurecr.io/imagepull-demo:latest":
ghcpdemoacr.azurecr.io/imagepull-demo:latest: not found
```

The key phrase is **`not found`** — the registry answered, but there is no
manifest for that tag. (Contrast with `401 Unauthorized` / `no basic auth
credentials`, which would point at an authentication problem instead.)

### Step 3: Confirm Which Tags Actually Exist

Prove the root cause by listing what's really in the registry:

```bash
az acr repository show-tags --name ghcpdemoacr --repository imagepull-demo -o table
```

```
Result
--------
v1
```

Only `v1` exists — the deployment asked for `:latest`, which was never pushed.

**Root cause:** the deployment references `ghcpdemoacr.azurecr.io/imagepull-demo:latest`,
but only the `:v1` tag exists in ACR, so the pull fails with `not found`.

## Part B — Diagnose It with Copilot CLI

Same investigation, but instead of eyeballing the output you hand it to the
GitHub Copilot CLI (`copilot`) and let it translate the raw Kubernetes output
into a plain-English explanation with concrete next steps.

> **Important — don't pipe into Copilot.** The GitHub Copilot CLI (`copilot`)
> does **not** read piped `stdin` as context. If you run
> `kubectl describe pod ... | copilot -p "..."`, Copilot sees an empty prompt
> and replies that there's no data. Instead, embed the command's output
> **inside** the prompt using shell command substitution `$(...)`.

### Step 1: Explain the Pod Status

```bash
copilot -p "Explain this Kubernetes pod status in plain English and tell me what is wrong:

$(kubectl get pods -n scenario-imagepull)"
```

Copilot will explain that the pod cannot pull its image.

### Step 2: Explain the Pod Events and Get a Fix

This is the key step — feed the describe output in and ask for a remediation plan:

```bash
copilot -p "Explain these pod events in plain English and tell me exactly how to fix the image pull error:

$(kubectl describe pod "$POD" -n scenario-imagepull)"
```

Copilot reads the `not found` message, identifies the missing `:latest` tag, and
recommends pointing the deployment at a tag that exists (or pushing `:latest`).

> **Tip:** Because this `copilot` is agentic, you can also let it run the
> commands itself instead of substituting output — just add `--allow-all-tools`
> and describe the task:
>
> ```bash
> copilot --allow-all-tools -p "The pod in namespace scenario-imagepull is in ImagePullBackOff. Investigate with kubectl and az acr, explain the root cause in plain English, and tell me how to fix it."
> ```

### One-liner: hand Copilot everything at once

For a fast triage, combine status, events, and the registry tag list into a
single prompt:

```bash
copilot -p "This Kubernetes pod cannot pull its image. Explain what is wrong in plain English and give me step-by-step instructions to fix it.

=== STATUS ===
$(kubectl get pods -n scenario-imagepull)

=== DESCRIBE ===
$(kubectl describe pod "$POD" -n scenario-imagepull)

=== TAGS THAT EXIST IN ACR ===
$(az acr repository show-tags --name ghcpdemoacr --repository imagepull-demo -o table 2>&1)"
```

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

### Solution 1: Point at a Tag That Exists (the fix for this lab)

The `:v1` tag exists in ACR but the deployment asked for `:latest`. Update the
deployment to use the real tag:

```bash
kubectl set image deployment/imagepull-demo \
  app=ghcpdemoacr.azurecr.io/imagepull-demo:v1 \
  -n scenario-imagepull
```

**PowerShell equivalent:**

```powershell
kubectl set image deployment/imagepull-demo `
  app=ghcpdemoacr.azurecr.io/imagepull-demo:v1 `
  -n scenario-imagepull
```

### Solution 2: Or Push the Missing Tag

If `:latest` is the tag you really want, build and push it to ACR:

```bash
az acr build --registry ghcpdemoacr --image imagepull-demo:latest scenarios/02-imagepullbackoff
```

Then Kubernetes will pull it on the next backoff retry (or delete the pod to
force an immediate retry).

### Solution 3: Check Available Tags Before Deploying

```bash
az acr repository show-tags --name ghcpdemoacr --repository imagepull-demo -o table
```

### Solution 4: Add an Image Pull Secret for a Private Registry

Not needed in this lab (the cluster is attached to ACR), but for a private
registry that the cluster is *not* attached to:

```bash
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
    image: <registry-url>/myapp:v1
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
# Capture the pod name
POD=$(kubectl get pods -n scenario-imagepull -o jsonpath='{.items[0].metadata.name}')

# See the specific error in the Events section
kubectl describe pod -n scenario-imagepull "$POD"

# Look for lines like:
# Events:
#   Warning  Failed   ...  kubelet  Failed to pull image ".../imagepull-demo:latest": ... not found
#   Warning  Failed   ...  kubelet  Error: ErrImagePull
#   Normal   BackOff  ...  kubelet  Back-off pulling image ".../imagepull-demo:latest"
```

### 4. Use Copilot to Analyze

```bash
# Embed the events into the prompt with $(...) — do NOT pipe into copilot
copilot -p "Explain these pod events in plain English and how to fix the errors:

$(kubectl describe pod -n scenario-imagepull "$POD")"
```

### 5. Fix It

The `:v1` tag exists in ACR but the deployment asked for `:latest`. Point it at
the real tag:

```bash
kubectl set image deployment/imagepull-demo \
  app=ghcpdemoacr.azurecr.io/imagepull-demo:v1 \
  -n scenario-imagepull
```

**PowerShell equivalent:**

```powershell
kubectl set image deployment/imagepull-demo `
  app=ghcpdemoacr.azurecr.io/imagepull-demo:v1 `
  -n scenario-imagepull
```

Alternatively, push the missing tag instead:

```bash
az acr build --registry ghcpdemoacr --image imagepull-demo:latest scenarios/02-imagepullbackoff
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
- A `not found` message means the tag doesn't exist; a `401 Unauthorized` / `no basic auth credentials` message means an authentication problem — read the error to tell them apart
- Always check image names and tags carefully for typos
- Use `kubectl describe` to see detailed pull errors — there are no app logs because the container never started
- Confirm what's really in the registry with `az acr repository show-tags`
- The `copilot` CLI does not read piped `stdin` — embed `kubectl`/`az` output in the prompt with `$(...)` to get a plain-English explanation with fixes
