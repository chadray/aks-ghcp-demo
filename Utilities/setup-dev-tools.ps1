$ErrorActionPreference = "Stop"

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' is not available."
    }
}

function Ensure-WingetPackage {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$DisplayName,
        [Parameter(Mandatory = $true)][string]$CommandName
    )

    Write-Host "`n=== $DisplayName ===" -ForegroundColor Cyan

    $isInstalled = $false
    $listOutput = winget list --id $Id --exact --accept-source-agreements 2>$null
    if ($LASTEXITCODE -eq 0 -and ($listOutput | Select-String -SimpleMatch $Id)) {
        $isInstalled = $true
    }

    if (-not $isInstalled) {
        Write-Host "Installing $DisplayName..."
        winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements
    } else {
        Write-Host "$DisplayName already installed."
    }

    Write-Host "Upgrading $DisplayName to latest (if available)..."
    winget upgrade --id $Id --exact --silent --accept-package-agreements --accept-source-agreements

    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        Write-Host "$DisplayName ready." -ForegroundColor Green
    } else {
        Write-Warning "$DisplayName installed/upgraded, but command '$CommandName' was not found in PATH yet. Open a new shell and retry."
    }
}

Require-Command winget

Ensure-WingetPackage -Id "Microsoft.AzureCLI"      -DisplayName "Azure CLI (az)"    -CommandName "az"
Ensure-WingetPackage -Id "Helm.Helm"               -DisplayName "Helm"              -CommandName "helm"
Ensure-WingetPackage -Id "Kubernetes.kubectl"      -DisplayName "kubectl"           -CommandName "kubectl"
Ensure-WingetPackage -Id "Docker.DockerDesktop"    -DisplayName "Docker Desktop"    -CommandName "docker"
Ensure-WingetPackage -Id "GitHub.cli"              -DisplayName "GitHub CLI (gh)"   -CommandName "gh"

Write-Host "`n=== GitHub Copilot CLI (gh copilot) ===" -ForegroundColor Cyan
$extInstalled = (gh extension list 2>$null | Select-String -SimpleMatch "gh-copilot")

if (-not $extInstalled) {
    Write-Host "Installing gh-copilot extension..."
    gh extension install github/gh-copilot
} else {
    Write-Host "gh-copilot already installed. Upgrading..."
    gh extension upgrade gh-copilot
}

if ($LASTEXITCODE -ne 0) {
    Write-Warning "Could not verify/upgrade gh-copilot extension. You may need to run: gh auth login"
} else {
    Write-Host "gh copilot ready." -ForegroundColor Green
}

Write-Host "`nDone. If any command was just installed, open a new PowerShell window before using it." -ForegroundColor Green
