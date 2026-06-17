<#
.SYNOPSIS
    Setup script for Scenario 4: Key Vault Secret Volume (Windows / PowerShell).

.DESCRIPTION
    Retrieves deployment outputs and generates the final Kubernetes manifests
    with the correct values substituted in, then applies them to the cluster.

.PARAMETER ResourceGroup
    The Azure resource group containing the deployment.

.PARAMETER DeploymentName
    The Bicep deployment name. Defaults to 'main'.

.EXAMPLE
    ./setup.ps1 -ResourceGroup my-rg
    ./setup.ps1 my-rg main

.NOTES
    Prerequisites:
      - Azure CLI authenticated (az login)
      - Infrastructure deployed via main.bicep
      - kubectl configured for the AKS cluster
      - PowerShell 5.1+ or PowerShell 7+
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ResourceGroup,

    [Parameter(Position = 1)]
    [string]$DeploymentName = 'main'
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== Scenario 4: Key Vault Secret Volume Setup ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/4] Retrieving deployment outputs..."
$outputsJson = az deployment group show `
    --resource-group $ResourceGroup `
    --name $DeploymentName `
    --query properties.outputs `
    --output json
if ($LASTEXITCODE -ne 0) { throw "Failed to retrieve deployment outputs." }

$outputs = $outputsJson | ConvertFrom-Json
$KeyVaultName             = $outputs.keyVaultName.value
$WorkloadIdentityClientId = $outputs.workloadIdentityClientId.value
$TenantId                 = $outputs.tenantId.value
$AcrLoginServer           = $outputs.acrLoginServer.value

# Fall back to discovering the registry if the deployment predates the ACR output.
if (-not $AcrLoginServer) {
    $AcrLoginServer = az acr list -g $ResourceGroup --query "[0].loginServer" -o tsv
}

Write-Host "  Key Vault Name:            $KeyVaultName"
Write-Host "  Workload Identity Client:  $WorkloadIdentityClientId"
Write-Host "  Tenant ID:                 $TenantId"
Write-Host "  ACR Login Server:          $AcrLoginServer"
Write-Host ""

Write-Host "[2/4] Seeding demo secret into Key Vault..."
$currentUserOid = az ad signed-in-user show --query id -o tsv 2>$null
$kvResourceId   = az keyvault show --name $KeyVaultName --resource-group $ResourceGroup --query id -o tsv

az role assignment create `
    --role "Key Vault Secrets Officer" `
    --assignee-object-id $currentUserOid `
    --assignee-principal-type User `
    --scope $kvResourceId `
    --output none 2>$null

az keyvault update --name $KeyVaultName --resource-group $ResourceGroup `
    --public-network-access Enabled --default-action Allow --output none 2>$null

Start-Sleep -Seconds 15

$secretValue = "SuperSecretValue-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
az keyvault secret set `
    --vault-name $KeyVaultName `
    --name "demo-secret" `
    --value $secretValue `
    --output none
if ($LASTEXITCODE -ne 0) { throw "Failed to set demo-secret in Key Vault." }

az keyvault update --name $KeyVaultName --resource-group $ResourceGroup `
    --default-action Deny --output none 2>$null
az keyvault update --name $KeyVaultName --resource-group $ResourceGroup `
    --public-network-access Disabled --output none 2>$null

Write-Host "  Secret 'demo-secret' created."
Write-Host ""

Write-Host "[3/4] Generating deployment manifest..."
$templatePath  = Join-Path $ScriptDir 'deployment.yaml'
$generatedPath = Join-Path $ScriptDir 'deployment-generated.yaml'

$content = Get-Content -Path $templatePath -Raw
$content = $content.Replace('${WORKLOAD_IDENTITY_CLIENT_ID}', $WorkloadIdentityClientId)
$content = $content.Replace('${KEY_VAULT_NAME}',              $KeyVaultName)
$content = $content.Replace('${TENANT_ID}',                   $TenantId)
$content = $content.Replace('${ACR_LOGIN_SERVER}',            $AcrLoginServer)
Set-Content -Path $generatedPath -Value $content -NoNewline

Write-Host "  Generated: deployment-generated.yaml"
Write-Host ""

Write-Host "[4/4] Applying Kubernetes manifests..."
kubectl apply -f $generatedPath
if ($LASTEXITCODE -ne 0) { throw "kubectl apply failed." }
Write-Host ""

Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Monitor the pod:"
Write-Host "  kubectl get pods -n scenario-keyvault -w"
Write-Host ""
Write-Host "View logs:"
Write-Host "  kubectl logs -n scenario-keyvault -l app=keyvault-demo -f"
Write-Host ""
Write-Host "Troubleshoot with Copilot:"
Write-Host '  copilot -p "Explain these pod events in plain English and how to fix them:'
Write-Host ''
Write-Host '  $(kubectl describe pod -n scenario-keyvault -l app=keyvault-demo)"'
