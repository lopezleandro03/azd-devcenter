// Parameters
@description('The location for the resources')
param location string

@description('The name of the Log Analytics workspace')
param lawName string

@description('The name of the DevCenter')
param devCenterName string

@description('Tags to apply to resources')
param tags object = {}

// Log Analytics Workspace
resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: lawName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
  tags: tags
}

// Reference to the dev center
resource devCenterResource 'Microsoft.DevCenter/devcenters@2023-04-01' existing = {
  name: devCenterName
}

// Diagnostic Settings
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'logs'
  scope: devCenterResource
  properties: {
    workspaceId: law.id
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}