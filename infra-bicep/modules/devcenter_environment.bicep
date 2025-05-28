// Parameters
@description('The location for the resources')
param location string

@description('The name of the project')
param projectName string

@description('The ID of the project')
param projectId string

@description('The name of the environment')
param environmentName string

@description('The target subscription ID')
param targetSubscriptionId string

// Extract project name from project ID
var projectNameFromId = split(projectId, '/')[8]

// Create environment type definition
resource environmentTypeDefinition 'Microsoft.DevCenter/projects/environmentTypes@2023-04-01' = {
  name: '${projectNameFromId}/${environmentName}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    deploymentTargetId: '/subscriptions/${targetSubscriptionId}'
    status: 'Enabled'
  }
}

// We need a delay to allow the system-assigned identity to propagate to AAD
resource deploymentDelay 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'deploymentDelay-${projectName}-${environmentName}'
  location: location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '8.0'
    retentionInterval: 'P1D'
    scriptContent: 'Start-Sleep -Seconds 30'
  }
  dependsOn: [
    environmentTypeDefinition
  ]
}

// Grant the environment type's system-assigned identity Owner access to the target subscription
// This is a workaround since we can't directly query for the service principal in Bicep
resource ownerRoleAssignment 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'ownerRoleAssignment-${projectName}-${environmentName}'
  location: location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '8.0'
    retentionInterval: 'P1D'
    scriptContent: '''
      $envTypeId = "${projectName}/environmentTypes/${environmentName}"
      $sp = Get-AzADServicePrincipal -DisplayName $envTypeId
      if ($sp) {
        $roleDefinitionId = (Get-AzRoleDefinition -Name "Owner").Id
        New-AzRoleAssignment -RoleDefinitionId $roleDefinitionId -PrincipalId $sp.Id -Scope "/subscriptions/${targetSubscriptionId}"
      } else {
        Write-Error "Service Principal for $envTypeId not found"
      }
    '''
    arguments: '-ProjectName "${projectName}" -EnvName "${environmentName}" -TargetSubscriptionId "${targetSubscriptionId}"'
  }
  dependsOn: [
    deploymentDelay
  ]
}