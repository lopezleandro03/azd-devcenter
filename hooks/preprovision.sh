#!/bin/bash

# Check if environment variables are set
if [ -z "$GITHUB_OWNER" ]; then
    echo "GITHUB_OWNER environment variable is not set."
    exit 1
fi

if [ -z "$GITHUB_REPO" ]; then
    echo "GITHUB_REPO environment variable is not set."
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "GITHUB_TOKEN environment variable is not set."
    exit 1
fi

# Check if Azure CLI is logged in
echo "Checking Azure CLI login status..."
if ! az account show &> /dev/null; then
    echo "ERROR: You are not logged in to Azure CLI. Please log in with 'az login' first."
    echo "Terraform requires access to your Azure subscription."
    exit 1
fi

echo "Azure CLI is logged in."
echo "Environment variables are set."