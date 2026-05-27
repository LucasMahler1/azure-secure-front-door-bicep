#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'rg-afdsec-eastus2',
    [string]$Location          = 'eastus2',
    [string]$TemplateFile      = (Join-Path $PSScriptRoot 'main.bicep'),
    [string]$ParameterFile     = (Join-Path $PSScriptRoot 'main.bicepparam'),
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

function Test-AzLogin {
    try {
        $null = az account show 2>$null
        if ($LASTEXITCODE -ne 0) { throw 'not logged in' }
    } catch {
        Write-Host 'Not logged in to Azure CLI. Running az login...' -ForegroundColor Yellow
        az login | Out-Null
    }
}

Test-AzLogin

Write-Host "Ensuring resource group '$ResourceGroupName' exists in $Location..." -ForegroundColor Cyan
az group create --name $ResourceGroupName --location $Location --only-show-errors | Out-Null

if ($WhatIf) {
    Write-Host 'Running what-if...' -ForegroundColor Cyan
    az deployment group what-if `
        --resource-group $ResourceGroupName `
        --template-file $TemplateFile `
        --parameters $ParameterFile
    return
}

Write-Host 'Deploying Bicep template (this can take 10-15 minutes)...' -ForegroundColor Cyan
$deploymentName = "afdsec-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$deployJson = az deployment group create `
    --resource-group $ResourceGroupName `
    --name $deploymentName `
    --template-file $TemplateFile `
    --parameters $ParameterFile `
    --output json
if ($LASTEXITCODE -ne 0) { throw 'Deployment failed.' }

$deploy = $deployJson | ConvertFrom-Json
$outputs = $deploy.properties.outputs
$appServiceId       = $outputs.appServiceId.value
$appServiceName     = $outputs.appServiceName.value
$frontDoorHost      = $outputs.frontDoorHostname.value

Write-Host "App Service: $appServiceName" -ForegroundColor Green
Write-Host "Front Door hostname: $frontDoorHost" -ForegroundColor Green

Write-Host 'Approving pending Private Endpoint connection on App Service...' -ForegroundColor Cyan
$pending = az network private-endpoint-connection list `
    --id $appServiceId `
    --query "[?properties.privateLinkServiceConnectionState.status=='Pending'].id" `
    --output tsv

if ([string]::IsNullOrWhiteSpace($pending)) {
    Write-Host 'No pending private endpoint connection found yet. It may take a moment to appear; rerun this script or approve manually if needed.' -ForegroundColor Yellow
} else {
    foreach ($peId in ($pending -split "`n" | Where-Object { $_ })) {
        Write-Host "  Approving $peId" -ForegroundColor DarkCyan
        az network private-endpoint-connection approve `
            --id $peId `
            --description 'Approved for Front Door Premium' | Out-Null
    }
    Write-Host 'Private Endpoint connection approved.' -ForegroundColor Green
}

Write-Host ''
Write-Host 'Done.' -ForegroundColor Green
Write-Host "Test with: curl -I https://$frontDoorHost/"
