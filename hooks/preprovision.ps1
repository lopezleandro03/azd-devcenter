<#
.SYNOPSIS
    This script is executed before the provisioning process starts to check if the
    environment is ready for provisioning.
#>

# Check if environment variables are set
if ($null -eq $env:GITHUB_OWNER) {
    Write-Error "GITHUB_OWNER environment variable is not set."
    exit 1
}

if ($null -eq $env:GITHUB_REPO) {
    Write-Error "GITHUB_REPO environment variable is not set."
    exit 1
}

if ($null -eq $env:GITHUB_TOKEN) {
    Write-Error "GITHUB_TOKEN environment variable is not set."
    exit 1
}

# Check if Azure CLI is logged in
Write-Information "Checking Azure CLI login status..."
try {
    $null = az account show 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "ERROR: You are not logged in to Azure CLI. Please log in with 'az login' first."
        Write-Error "Terraform requires access to your Azure subscription."
        exit 1
    }
}
catch {
    Write-Error "ERROR: You are not logged in to Azure CLI. Please log in with 'az login' first."
    Write-Error "Terraform requires access to your Azure subscription."
    exit 1
}

Write-Information "Azure CLI is logged in."
Write-Information "Environment variables are set."