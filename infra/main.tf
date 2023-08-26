locals {
  tags                         = { azd-env-name : var.environment_name }
  sha                          = base64encode(sha256("${var.environment_name}${var.location}${data.azurerm_client_config.current.subscription_id}"))
  resource_token               = substr(replace(lower(local.sha), "[^A-Za-z0-9_]", ""), 0, 13)
}

resource "azurecaf_name" "rg_name" {
  name          = var.environment_name
  resource_type = "azurerm_resource_group"
  random_length = 0
  clean_input   = true
}

# Deploy resource group
resource "azurerm_resource_group" "rg" {
  name     = azurecaf_name.rg_name.result
  location = var.location
  // Tag the resource group with the azd environment name
  // This should also be applied to all resources created in this module
  tags = { azd-env-name : var.environment_name }
}

# Add resources to be provisioned below.
# To learn more, https://developer.hashicorp.com/terraform/tutorials/azure-get-started/azure-change
# Note that a tag:
#   azd-service-name: "<service name in azure.yaml>"
# should be applied to targeted service host resources, such as:
#  azurerm_linux_web_app, azurerm_windows_web_app for appservice
#  azurerm_function_app for function

# Deploy devcenter
resource "azapi_resource" "devcenter" {
  type = "Microsoft.DevCenter/devcenters@2023-04-01"
  name = "devcenter-${local.resource_token}"
  location = azurerm_resource_group.rg.location
  parent_id = azurerm_resource_group.rg.id
  identity {
    type = "SystemAssigned"
  }
  body = jsonencode({
    properties = {}
  })
}

# key vault
resource "azurerm_key_vault" "keyvault" {
  name                = "akv-${local.resource_token}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id
  enable_rbac_authorization = true
}

# rbac tf client
resource "azurerm_role_assignment" "tf_admin" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# rbac dev center secret reader
resource "azurerm_role_assignment" "devcenter_keyvault_secret_reader" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azapi_resource.devcenter.identity[0].principal_id
}

# add GitHub token to key vault
resource "azurerm_key_vault_secret" "github_token" {
  name         = "github-token"
  value        = var.github_token
  key_vault_id = azurerm_key_vault.keyvault.id

  depends_on = [ azurerm_role_assignment.devcenter_keyvault_secret_reader, azurerm_role_assignment.tf_admin ]
}

# Attach catalog
resource "azapi_resource" "default_catalog" {
  type = "Microsoft.DevCenter/devcenters/catalogs@2023-04-01"
  name = "default_catalog"
  parent_id = azapi_resource.devcenter.id
  body = jsonencode({
    properties = {
      gitHub = {
        branch = "main"
        path = ""
        secretIdentifier = azurerm_key_vault_secret.github_token.id
        uri = "https://github.com/${var.github_owner}/${var.github_repo}.git"
      }
    }
  })
}

# Environment type
resource "azapi_resource" "environment_type_dev" {
  type = "Microsoft.DevCenter/devcenters/environmentTypes@2023-04-01"
  name = "development"
  parent_id = azapi_resource.devcenter.id
  body = jsonencode({
    properties = {}
  })
}

# project kaas
resource "azapi_resource" "project" {
  type = "Microsoft.DevCenter/projects@2023-04-01"
  name = "project-kaas"
  location = azurerm_resource_group.rg.location
  parent_id = azurerm_resource_group.rg.id
  body = jsonencode({
    properties = {
      description = "Project for Kubernetes multi-tenant as a service"
      devCenterId = azapi_resource.devcenter.id
      maxDevBoxesPerUser = 1
    }
  })
}

# environment type
resource "azapi_resource" "environment_type_dev_definition" {
  type = "Microsoft.DevCenter/projects/environmentTypes@2023-04-01"
  name = azapi_resource.environment_type_dev.name
  location = azurerm_resource_group.rg.location
  parent_id = azapi_resource.project.id
  tags = {
    tagName1 = "tagValue1"
    tagName2 = "tagValue2"
  }
  identity {
    type = "SystemAssigned"
    identity_ids = []
  }
  body = jsonencode({
    properties = {
      # creatorRoleAssignment = {
      #   roles = {"Owner" = []}
      # }
      deploymentTargetId = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
      status = "Enabled"
      # userRoleAssignments = {}
    }
  })

  depends_on = [ azapi_resource.environment_type_dev ]
}

# allow environment type dev on project kaas
data "azapi_resource" "allowed_env_types" {
  type = "Microsoft.DevCenter/projects/allowedEnvironmentTypes@2023-04-01"
  name = azapi_resource.environment_type_dev.name
  parent_id = azapi_resource.project.id

  depends_on = [ azapi_resource.environment_type_dev_definition ]
}

# add dev rbac deployment environment user
resource "azurerm_role_assignment" "devcenter_environment_user" {
  scope                = azapi_resource.project.id
  role_definition_name = "Deployment Environments User"
  principal_id         = data.azurerm_client_config.current.object_id
}