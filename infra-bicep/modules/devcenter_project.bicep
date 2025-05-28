// Parameters
@description('The location for the resources')
param location string

@description('The ID of the DevCenter')
param devCenterId string

@description('The name of the project')
param projectName string

@description('The description of the project')
param projectDescription string

@description('The list of object IDs of project members')
param projectMembers array

@description('The environment types to create')
param environmentTypes object

// Create DevCenter Project
resource project 'Microsoft.DevCenter/projects@2023-04-01' = {
  name: projectName
  location: location
  properties: {
    description: projectDescription
    devCenterId: devCenterId
  }
}

// Create environment type definitions for each environment type
module environmentTypeDefinition 'devcenter_environment.bicep' = [for env in items(environmentTypes): {
  name: 'environmentDeploy-${env.key}-${projectName}'
  params: {
    location: location
    projectName: projectName
    projectId: project.id
    environmentName: env.value.name
    targetSubscriptionId: env.value.targetSubscriptionId
  }
}]

// Assign RBAC roles to project members
resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for memberId in projectMembers: {
  name: guid(project.id, memberId, 'Deployment Environments User')
  scope: project
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '18e40d4e-8d2e-438d-97e1-9528336e149c') // Deployment Environments User
    principalId: memberId
    principalType: 'User'
  }
}]