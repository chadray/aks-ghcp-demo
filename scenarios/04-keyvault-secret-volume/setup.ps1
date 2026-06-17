<#
.SYNOPSIS
    Setup script for Scenario 4: Key Vault Secret Volume (Windows / PowerShell).

.DESCRIPTION
    Seeds a secret into Key Vault, then deploys the workload in an intentionally
    BROKEN state by injecting an incorrect Key Vault private DNS record so the
    Secrets Store CSI driver cannot reach Key Vault and the secret volume fails
    to mount. Use -FixDns to restore the correct record and resolve the scenario.

.PARAMETER ResourceGroup
    The Azure resource group containing the deployment.

.PARAMETER DeploymentName
    The Bicep deployment name. Defaults to 'main'.

.PARAMETER FixDns
    Repair the private DNS fault (restore the correct record) and exit.

.EXAMPLE
    ./setup.ps1 -ResourceGroup my-rg
    ./setup.ps1 -ResourceGroup my-rg -FixDns

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
    [string]$DeploymentName = 'main',

    [switch]$FixDns
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$DnsZone = 'privatelink.vaultcore.azure.net'
$WrongIp = '10.1.16.250'   # in the PE subnet but with no listener -> mount times out

# Overwrite the Key Vault private DNS A record with a wrong IP (inject the fault).
function Invoke-BreakDns {
    az network private-dns record-set a delete `
        -g $ResourceGroup -z $DnsZone -n $KeyVaultName --yes 2>$null | Out-Null
    az network private-dns record-set a create `
        -g $ResourceGroup -z $DnsZone -n $KeyVaultName --ttl 10 --output none
    az network private-dns record-set a add-record `
        -g $ResourceGroup -z $DnsZone -n $KeyVaultName -a $WrongIp --output none
    kubectl -n kube-system rollout restart deployment/coredns 2>$null | Out-Null
}

# Restore the correct A record from the Key Vault private endpoint (the fix).
function Invoke-FixDns {
    $nicId = az network private-endpoint show `
        -g $ResourceGroup -n "$KeyVaultName-pe" `
        --query "networkInterfaces[0].id" -o tsv 2>$null
    $correctIp = $null
    if ($nicId) {
        $correctIp = az network nic show --ids $nicId `
            --query "ipConfigurations[0].privateIPAddress" -o tsv 2>$null
    }
    if (-not $correctIp) {
        throw "Could not determine the private endpoint IP for $KeyVaultName-pe."
    }
    az network private-dns record-set a delete `
        -g $ResourceGroup -z $DnsZone -n $KeyVaultName --yes 2>$null | Out-Null
    az network private-dns record-set a create `
        -g $ResourceGroup -z $DnsZone -n $KeyVaultName --ttl 3600 --output none
    az network private-dns record-set a add-record `
        -g $ResourceGroup -z $DnsZone -n $KeyVaultName -a $correctIp --output none
    Write-Host "  Restored $KeyVaultName -> $correctIp"
    kubectl -n kube-system rollout restart deployment/coredns 2>$null | Out-Null
    kubectl rollout restart deployment/keyvault-demo -n scenario-keyvault 2>$null | Out-Null
}

Write-Host "=== Scenario 4: Key Vault Secret Volume Setup ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/5] Retrieving deployment outputs..."
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

# Fix mode: restore the correct private DNS record and exit.
if ($FixDns) {
    Write-Host "[fix] Restoring the Key Vault private DNS record..."
    Invoke-FixDns
    Write-Host ""
    Write-Host "=== DNS repaired. The pod should mount the secret on its next attempt. ===" -ForegroundColor Green
    Write-Host "Watch it recover:"
    Write-Host "  kubectl get pods -n scenario-keyvault -w"
    return
}

Write-Host "[2/5] Seeding demo secret into Key Vault..."
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

# Inject the fault: break the Key Vault private DNS record so the FQDN resolves
# to a wrong IP with no listener. The CSI driver can no longer reach Key Vault,
# so the secret volume fails to mount (FailedMount / context deadline exceeded).
Write-Host "[3/5] Breaking Key Vault private DNS (injecting the fault)..."
Invoke-BreakDns
Write-Host "  Record '$KeyVaultName' in $DnsZone now points to $WrongIp (wrong)."
Write-Host ""

Write-Host "[4/5] Generating deployment manifest..."
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

Write-Host "[5/5] Applying Kubernetes manifests..."
kubectl apply -f $generatedPath
if ($LASTEXITCODE -ne 0) { throw "kubectl apply failed." }
# Force a brand-new mount attempt so the broken DNS takes effect.
kubectl delete pods -n scenario-keyvault -l app=keyvault-demo --ignore-not-found --wait=false 2>$null | Out-Null
kubectl rollout restart deployment/keyvault-demo -n scenario-keyvault 2>$null | Out-Null
Write-Host ""

Write-Host "=== Setup Complete (the pod will FAIL to mount the secret) ===" -ForegroundColor Green
Write-Host ""
Write-Host "Expected: the pod stays in ContainerCreating with a FailedMount event because"
Write-Host "$KeyVaultName.vault.azure.net now resolves to the wrong IP ($WrongIp)."
Write-Host ""
Write-Host "Monitor the pod:"
Write-Host "  kubectl get pods -n scenario-keyvault -w"
Write-Host ""
Write-Host "Troubleshoot with Copilot:"
Write-Host '  $POD = kubectl get pods -n scenario-keyvault -l app=keyvault-demo -o jsonpath=''{.items[0].metadata.name}'''
Write-Host '  copilot -p "Explain these pod events in plain English and how to fix them:'
Write-Host ''
Write-Host '  $(kubectl describe pod $POD -n scenario-keyvault)"'
Write-Host ""
Write-Host "When you are ready to FIX it (restore the correct private DNS record):"
Write-Host "  ./setup.ps1 -ResourceGroup $ResourceGroup -FixDns"
