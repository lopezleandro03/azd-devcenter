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

echo "Environment variables are set."