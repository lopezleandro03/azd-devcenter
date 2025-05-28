// Parameters
@description('The location for the resources')
param location string

@description('The name of the Key Vault')
param keyVaultName string

@description('The principal ID of the DevCenter system-assigned identity')
param devCenterPrincipalId string

@description('The object ID of the current user or service principal')
param currentUserObjectId string

@description('The GitHub token to store in Key Vault')
@secure()
param githubToken string

@description('Tags to apply to resources')
param tags object = {}

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
  }
  tags: tags
}

// RBAC Assignments
resource rbacDevCenter 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, devCenterPrincipalId, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: devCenterPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource rbacAdmin 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, currentUserObjectId, 'Key Vault Administrator')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483') // Key Vault Administrator
    principalId: currentUserObjectId
    principalType: 'User'
  }
}

// We need a delay after RBAC assignment before creating secrets
resource deploymentDelay 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'deploymentDelay'
  location: location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '8.0'
    retentionInterval: 'P1D'
    scriptContent: 'Start-Sleep -Seconds 30'
  }
  dependsOn: [
    rbacDevCenter
    rbacAdmin
  ]
}

// Secret for GitHub token
resource githubTokenSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'github-token'
  properties: {
    value: githubToken
  }
  dependsOn: [
    deploymentDelay
  ]
}

// Outputs
output keyVaultId string = keyVault.id