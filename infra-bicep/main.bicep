// Parameters
@description('The supported Azure location where the resource deployed')
param location string

@description('The name of the azd environment to be deployed')
param environmentName string

@description('The github token to be used to access the github repo')
@secure()
param githubToken string

@description('The name of the github owner')
param githubOwner string = 'azure'

@description('The name of the github repo')
param githubRepo string = 'deployment-environments'

// Variables
var organization = 'cloudyjourney'
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 3)

var projectsList = {
  'Team-one': {
    name: 'Team-one-${uniqueSuffix}'
    description: 'Project used by Team-one to manage their environments'
    members: [currentUserId]  // Default to current user, modify as needed
  }
  'Team-two': {
    name: 'Team-two-${uniqueSuffix}'
    description: 'Project used by Team-two to manage their environments'
    members: [currentUserId]  // Default to current user, modify as needed
  }
  'Team-three': {
    name: 'Team-three-${uniqueSuffix}'
    description: 'Project used by Team-three to manage their environments'
    members: [currentUserId]  // Default to current user, modify as needed
  }
  'Team-four': {
    name: 'Team-four-${uniqueSuffix}'
    description: 'Project used by Team-four to manage their environments'
    members: [currentUserId]  // Default to current user, modify as needed
  }
}

var environmentTypes = {
  development: {
    name: 'et-development'
    description: 'Development environment'
    targetSubscriptionId: subscription().subscriptionId
  }
  sandbox: {
    name: 'et-sandbox'
    description: 'Sandbox environment'
    targetSubscriptionId: subscription().subscriptionId
  }
  'ephemeral-24hs': {
    name: 'et-ephemeral-24hs'
    description: 'This environment type will destroy environments after 24hs'
    targetSubscriptionId: subscription().subscriptionId
  }
}

var tags = {
  'azd-env-name': environmentName
}

// Get current user ID for role assignments
var currentUserId = ''  // This will need to be replaced with the actual user ID since Bicep cannot directly get it

// Resources
resource devCenter 'Microsoft.DevCenter/devcenters@2023-04-01' = {
  name: 'dc-${organization}-${uniqueSuffix}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
  tags: tags
}

// Log Analytics Workspace
module logging 'modules/devcenter_logging.bicep' = {
  name: 'loggingDeploy'
  params: {
    location: location
    lawName: 'law-${organization}-${uniqueSuffix}'
    devCenterName: devCenter.name
    tags: tags
  }
}

// Key Vault for GitHub token
module keyVault 'modules/devcenter_key_vault.bicep' = {
  name: 'keyVaultDeploy'
  params: {
    location: location
    keyVaultName: 'kv-${organization}-${uniqueSuffix}'
    devCenterPrincipalId: devCenter.identity.principalId
    currentUserObjectId: currentUserId  // Will need to be replaced with actual objectId
    githubToken: githubToken
    tags: tags
  }
}

// DevCenter Catalog
resource defaultCatalog 'Microsoft.DevCenter/devcenters/catalogs@2023-04-01' = {
  parent: devCenter
  name: 'catalog-${organization}-${uniqueSuffix}'
  properties: {
    gitHub: {
      branch: 'main'
      path: ''
      secretIdentifier: '${keyVault.outputs.keyVaultId}/secrets/github-token'
      uri: 'https://github.com/${githubOwner}/${githubRepo}.git'
    }
  }
}

// DevCenter environment types
resource environmentType 'Microsoft.DevCenter/devcenters/environmentTypes@2023-04-01' = [for env in items(environmentTypes): {
  parent: devCenter
  name: env.value.name
  properties: {}
}]

// Deploy projects - one module per project
module projectDeployments 'modules/devcenter_project.bicep' = [for project in items(projectsList): {
  name: 'projectDeploy-${project.key}'
  params: {
    location: location
    devCenterId: devCenter.id
    projectName: project.value.name
    projectDescription: project.value.description
    projectMembers: project.value.members
    environmentTypes: environmentTypes
  }
  dependsOn: [
    environmentType
  ]
}]

// Outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = subscription().tenantId