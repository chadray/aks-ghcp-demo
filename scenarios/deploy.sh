#!/usr/bin/env bash
#
# Dynamic scenario deployer for the AKS + GitHub Copilot CLI demo.
#
# The scenario manifests reference the container registry via the
# ${ACR_LOGIN_SERVER} placeholder instead of a hard-coded registry name.
# This script discovers the AKS cluster and its attached Azure Container
# Registry at runtime, substitutes the placeholder, and applies the manifest.
#
# Usage:
#   ./deploy.sh <scenario-folder> [--build]
#
# Examples:
#   ./deploy.sh 01-crashloopbackoff
#   ./deploy.sh 03-application-logs --build
#
# Configuration (all optional — sensible defaults / auto-discovery):
#   RESOURCE_GROUP    Resource group of the cluster   (default: ghcp-demo-rg)
#   CLUSTER_NAME      AKS cluster name                (default: aks-ghcp-demo)
#   ACR_NAME          Registry name                   (default: discovered)
#   ACR_LOGIN_SERVER  Registry login server           (default: discovered)
#
# Flags:
#   --build           Build & push the scenario image to the registry first
#                     (tags :v1; for 02-imagepullbackoff :latest is intentionally
#                      NOT pushed so the ImagePullBackOff demo still fails).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Parse args ────────────────────────────────────────────────────────────────
SCENARIO="${1:-}"
BUILD=false
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --build) BUILD=true ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
  shift
done

if [[ -z "$SCENARIO" ]]; then
  echo "Usage: ./deploy.sh <scenario-folder> [--build]" >&2
  echo "  e.g. ./deploy.sh 01-crashloopbackoff" >&2
  exit 1
fi

SCENARIO_DIR="${SCRIPT_DIR}/${SCENARIO}"
MANIFEST="${SCENARIO_DIR}/deployment.yaml"
if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: ${MANIFEST} not found." >&2
  exit 1
fi

# ─── Resolve cluster + registry dynamically ────────────────────────────────────
RESOURCE_GROUP="${RESOURCE_GROUP:-ghcp-demo-rg}"
CLUSTER_NAME="${CLUSTER_NAME:-aks-ghcp-demo}"

echo "Resource group: $RESOURCE_GROUP"
echo "Cluster:        $CLUSTER_NAME"

# Discover the registry attached to the cluster if not provided.
if [[ -z "${ACR_LOGIN_SERVER:-}" ]]; then
  if [[ -z "${ACR_NAME:-}" ]]; then
    echo "Discovering Azure Container Registry in $RESOURCE_GROUP..."
    ACR_NAME="$(az acr list -g "$RESOURCE_GROUP" --query "[0].name" -o tsv)"
    if [[ -z "$ACR_NAME" ]]; then
      echo "ERROR: No ACR found in resource group '$RESOURCE_GROUP'." >&2
      echo "       Set ACR_NAME or ACR_LOGIN_SERVER explicitly." >&2
      exit 1
    fi
  fi
  ACR_LOGIN_SERVER="$(az acr show -n "$ACR_NAME" --query loginServer -o tsv)"
fi

# Derive ACR_NAME from the login server when only the login server was provided.
if [[ -z "${ACR_NAME:-}" ]]; then
  ACR_NAME="${ACR_LOGIN_SERVER%%.*}"
fi

echo "Registry:       $ACR_LOGIN_SERVER"
echo ""

# ─── Optional: build & push the image ──────────────────────────────────────────
if [[ "$BUILD" == true ]]; then
  IMAGE_NAME="$(basename "$SCENARIO_DIR" | sed -E 's/^[0-9]+-//')-demo"
  # Map scenario folder -> image repo name used in the manifests.
  case "$SCENARIO" in
    01-crashloopbackoff)  IMAGE_NAME="crashloop-demo" ;;
    02-imagepullbackoff)  IMAGE_NAME="imagepull-demo" ;;
    03-application-logs)  IMAGE_NAME="applogs-demo" ;;
    04-keyvault-secret-volume) IMAGE_NAME="keyvault-demo" ;;
  esac

  echo "Building ${IMAGE_NAME}:v1 in $ACR_NAME ..."
  az acr build -r "$ACR_NAME" -t "${IMAGE_NAME}:v1" --platform linux/amd64 "$SCENARIO_DIR"
  echo ""
fi

# ─── Ensure kubectl is pointed at the cluster ──────────────────────────────────
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "Fetching cluster credentials..."
  az aks get-credentials -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --overwrite-existing >/dev/null
fi

# ─── Substitute the placeholder and apply ──────────────────────────────────────
echo "Applying ${SCENARIO}/deployment.yaml with registry ${ACR_LOGIN_SERVER}..."
sed "s|\${ACR_LOGIN_SERVER}|${ACR_LOGIN_SERVER}|g" "$MANIFEST" | kubectl apply -f -

echo ""
echo "Done. Watch the pods with:"
NS="$(grep -m1 'namespace:' "$MANIFEST" | awk '{print $2}')"
echo "  kubectl get pods -n ${NS:-default} -w"
