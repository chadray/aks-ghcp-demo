<#
.SYNOPSIS
  Dynamic scenario deployer for the AKS + GitHub Copilot CLI demo.

.DESCRIPTION
  The scenario manifests reference the container registry via the
  ${ACR_LOGIN_SERVER} placeholder instead of a hard-coded registry name.
  This script discovers the AKS cluster and its attached Azure Container
  Registry at runtime, substitutes the placeholder, and applies the manifest.

.PARAMETER Scenario
  The scenario folder to deploy, e.g. 01-crashloopbackoff.

.PARAMETER Build
  Build & push the scenario image to the registry first (tags :v1).
  For 02-imagepullbackoff the :latest tag is intentionally NOT pushed so the
  ImagePullBackOff demo still fails.

.PARAMETER ResourceGroup
  Resource group of the cluster (default: ghcp-demo-rg).

.PARAMETER ClusterName
  AKS cluster name (default: aks-ghcp-demo).

.PARAMETER AcrName
  Registry name (default: discovered from the resource group).

.PARAMETER AcrLoginServer
  Registry login server (default: discovered).

.EXAMPLE
  ./deploy.ps1 01-crashloopbackoff

.EXAMPLE
  ./deploy.ps1 03-application-logs -Build
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Scenario,
  [switch]$Build,
  [string]$ResourceGroup = $(if ($env:RESOURCE_GROUP) { $env:RESOURCE_GROUP } else { 'ghcp-demo-rg' }),
  [string]$ClusterName  = $(if ($env:CLUSTER_NAME)  { $env:CLUSTER_NAME }  else { 'aks-ghcp-demo' }),
  [string]$AcrName      = $env:ACR_NAME,
  [string]$AcrLoginServer = $env:ACR_LOGIN_SERVER
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScenarioDir = Join-Path $ScriptDir $Scenario
$Manifest = Join-Path $ScenarioDir 'deployment.yaml'

if (-not (Test-Path $Manifest)) {
  Write-Error "$Manifest not found."
  exit 1
}

Write-Host "Resource group: $ResourceGroup"
Write-Host "Cluster:        $ClusterName"

# ─── Resolve the registry dynamically ──────────────────────────────────────────
if (-not $AcrLoginServer) {
  if (-not $AcrName) {
    Write-Host "Discovering Azure Container Registry in $ResourceGroup..."
    $AcrName = az acr list -g $ResourceGroup --query "[0].name" -o tsv
    if (-not $AcrName) {
      Write-Error "No ACR found in resource group '$ResourceGroup'. Set -AcrName or -AcrLoginServer."
      exit 1
    }
  }
  $AcrLoginServer = az acr show -n $AcrName --query loginServer -o tsv
}
if (-not $AcrName) {
  $AcrName = $AcrLoginServer.Split('.')[0]
}

Write-Host "Registry:       $AcrLoginServer"
Write-Host ""

# ─── Optional: build & push the image ──────────────────────────────────────────
if ($Build) {
  $ImageName = switch ($Scenario) {
    '01-crashloopbackoff'        { 'crashloop-demo' }
    '02-imagepullbackoff'        { 'imagepull-demo' }
    '03-application-logs'        { 'applogs-demo' }
    '04-keyvault-secret-volume'  { 'keyvault-demo' }
    default { ($Scenario -replace '^[0-9]+-', '') + '-demo' }
  }
  Write-Host "Building ${ImageName}:v1 in $AcrName ..."
  az acr build -r $AcrName -t "${ImageName}:v1" --platform linux/amd64 $ScenarioDir
  Write-Host ""
}

# ─── Ensure kubectl is pointed at the cluster ──────────────────────────────────
kubectl cluster-info *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Host "Fetching cluster credentials..."
  az aks get-credentials -g $ResourceGroup -n $ClusterName --overwrite-existing | Out-Null
}

# ─── Substitute the placeholder and apply ──────────────────────────────────────
Write-Host "Applying $Scenario/deployment.yaml with registry $AcrLoginServer..."
(Get-Content -Raw $Manifest).Replace('${ACR_LOGIN_SERVER}', $AcrLoginServer) | kubectl apply -f -

Write-Host ""
Write-Host "Done. Watch the pods with:"
$ns = (Select-String -Path $Manifest -Pattern 'namespace:\s*(\S+)' | Select-Object -First 1).Matches.Groups[1].Value
Write-Host "  kubectl get pods -n $ns -w"
