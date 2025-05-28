#!/bin/bash

# Get current directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFRA_DIR="$SCRIPT_DIR/../infra-bicep"

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

# Create a parameters file for the Bicep deployment with the current values
cat > "$INFRA_DIR/generated.parameters.json" << EOF
{
    "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "location": {
            "value": "${AZURE_LOCATION}"
        },
        "environmentName": {
            "value": "${AZURE_ENV_NAME}"
        },
        "githubToken": {
            "value": "${GITHUB_TOKEN}"
        },
        "githubOwner": {
            "value": "${GITHUB_OWNER}"
        },
        "githubRepo": {
            "value": "${GITHUB_REPO}"
        }
    }
}
EOF

echo "Parameters file generated at $INFRA_DIR/generated.parameters.json"
echo "Environment variables are set for Bicep deployment."