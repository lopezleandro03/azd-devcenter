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

Write-Information "Environment variables are set."