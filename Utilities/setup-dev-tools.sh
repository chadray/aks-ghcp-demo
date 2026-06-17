#!/usr/bin/env bash
#
# setup-dev-tools.sh — bash equivalent of setup-dev-tools.ps1
#
# Installs/upgrades the tools needed for this demo:
#   - Azure CLI (az)
#   - Helm
#   - kubectl
#   - Docker (Desktop on macOS, Engine on Linux)
#   - GitHub CLI (gh)
#   - GitHub Copilot CLI extension (gh copilot)
#
# Supports macOS (Homebrew) and Debian/Ubuntu Linux (apt).
# On other distros, install the prerequisites manually and re-run to install
# the gh-copilot extension.
#
# Usage:
#   ./setup-dev-tools.sh

set -euo pipefail

# ---- styling ----------------------------------------------------------------
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

section() { printf "\n${CYAN}=== %s ===${NC}\n" "$1"; }
ok()      { printf "${GREEN}%s${NC}\n" "$1"; }
warn()    { printf "${YELLOW}WARN:${NC} %s\n" "$1" >&2; }
err()     { printf "${RED}ERROR:${NC} %s\n" "$1" >&2; }

require_command() {
    local name="$1"
    if ! command -v "$name" >/dev/null 2>&1; then
        err "Required command '$name' is not available."
        exit 1
    fi
}

# ---- platform detection -----------------------------------------------------
PLATFORM=""
case "$(uname -s)" in
    Darwin) PLATFORM="macos" ;;
    Linux)
        if [[ -r /etc/os-release ]]; then
            # shellcheck disable=SC1091
            . /etc/os-release
            case "${ID:-}:${ID_LIKE:-}" in
                *debian*|*ubuntu*) PLATFORM="debian" ;;
                *) PLATFORM="linux-other" ;;
            esac
        else
            PLATFORM="linux-other"
        fi
        ;;
    *) PLATFORM="unknown" ;;
esac

case "$PLATFORM" in
    macos)        require_command brew ;;
    debian)       require_command apt-get; require_command sudo; require_command curl ;;
    linux-other)  warn "Unrecognized Linux distribution. Install prerequisites manually; this script will only manage the gh-copilot extension." ;;
    unknown)      err "Unsupported OS: $(uname -s)"; exit 1 ;;
esac

# ---- per-tool installers ----------------------------------------------------
# Each function: install if missing, then attempt upgrade; verify command exists.

ensure_brew_package() {
    local display="$1" cmd="$2" formula="$3" cask="${4:-}"

    section "$display"

    if command -v "$cmd" >/dev/null 2>&1; then
        echo "$display already installed. Upgrading if newer is available..."
        if [[ -n "$cask" ]]; then
            brew upgrade --cask "$cask" 2>/dev/null || true
        else
            brew upgrade "$formula" 2>/dev/null || true
        fi
    else
        echo "Installing $display..."
        if [[ -n "$cask" ]]; then
            brew install --cask "$cask"
        else
            brew install "$formula"
        fi
    fi

    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$display ready."
    else
        warn "$display installed, but command '$cmd' was not found in PATH yet. Open a new shell and retry."
    fi
}

ensure_apt_package() {
    local display="$1" cmd="$2" package="$3"

    section "$display"

    if command -v "$cmd" >/dev/null 2>&1; then
        echo "$display already installed. Upgrading if newer is available..."
        sudo apt-get install -y --only-upgrade "$package" >/dev/null 2>&1 || true
    else
        echo "Installing $display..."
        sudo apt-get update -qq
        sudo apt-get install -y "$package"
    fi

    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$display ready."
    else
        warn "$display installed, but command '$cmd' was not found in PATH yet. Open a new shell and retry."
    fi
}

install_az_debian() {
    section "Azure CLI (az)"
    if command -v az >/dev/null 2>&1; then
        echo "Azure CLI already installed. Upgrading..."
        sudo apt-get update -qq && sudo apt-get install -y --only-upgrade azure-cli >/dev/null 2>&1 || true
    else
        echo "Installing Azure CLI via Microsoft install script..."
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    fi
    command -v az >/dev/null 2>&1 && ok "Azure CLI ready." || warn "az not on PATH yet."
}

install_gh_debian() {
    section "GitHub CLI (gh)"
    if command -v gh >/dev/null 2>&1; then
        echo "gh already installed. Upgrading..."
        sudo apt-get update -qq && sudo apt-get install -y --only-upgrade gh >/dev/null 2>&1 || true
    else
        echo "Adding GitHub CLI apt repository..."
        type -p curl >/dev/null || sudo apt-get install -y curl
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
            | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
            | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
        sudo apt-get update -qq
        sudo apt-get install -y gh
    fi
    command -v gh >/dev/null 2>&1 && ok "GitHub CLI ready." || warn "gh not on PATH yet."
}

install_helm_debian() {
    section "Helm"
    if command -v helm >/dev/null 2>&1; then
        echo "Helm already installed. Re-running installer to upgrade..."
    else
        echo "Installing Helm via official script..."
    fi
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    command -v helm >/dev/null 2>&1 && ok "Helm ready." || warn "helm not on PATH yet."
}

# ---- main: install prerequisites per platform -------------------------------
case "$PLATFORM" in
    macos)
        ensure_brew_package "Azure CLI (az)"   "az"      "azure-cli"
        ensure_brew_package "Helm"             "helm"    "helm"
        ensure_brew_package "kubectl"          "kubectl" "kubectl"
        ensure_brew_package "Docker Desktop"   "docker"  ""           "docker"
        ensure_brew_package "GitHub CLI (gh)"  "gh"      "gh"
        ;;
    debian)
        install_az_debian
        install_helm_debian
        ensure_apt_package "kubectl" "kubectl" "kubectl"
        ensure_apt_package "Docker"  "docker"  "docker.io"
        install_gh_debian
        ;;
    linux-other)
        warn "Skipping prerequisite install. Ensure az/helm/kubectl/docker/gh are on PATH."
        ;;
esac

# ---- gh-copilot extension (cross-platform) ----------------------------------
section "GitHub Copilot CLI (gh copilot)"

if ! command -v gh >/dev/null 2>&1; then
    warn "gh not installed; cannot manage gh-copilot extension."
else
    if gh extension list 2>/dev/null | grep -q "gh-copilot"; then
        echo "gh-copilot already installed. Upgrading..."
        if gh extension upgrade gh-copilot; then
            ok "gh copilot ready."
        else
            warn "Could not upgrade gh-copilot. You may need to run: gh auth login"
        fi
    else
        echo "Installing gh-copilot extension..."
        if gh extension install github/gh-copilot; then
            ok "gh copilot ready."
        else
            warn "Could not install gh-copilot. You may need to run: gh auth login"
        fi
    fi
fi

printf "\n${GREEN}Done. If any command was just installed, open a new shell before using it.${NC}\n"
