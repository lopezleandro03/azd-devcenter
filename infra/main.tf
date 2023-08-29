##############################
# random_string for resource names uniqueness
##############################
resource "random_string" "value" {
  length  = 3
  upper   = false
  lower   = true
  special = false
}

##############################
# local variables
# - Organization is used to define the DevCenter resource name
# - Projects map is used to define the DevCenter projects. In this case we will model two teams as projects (Team-one, Team-two)
# - Environment types map is used to define the DevCenter environment types which will then be used to create the environment type definitions on each project
##############################
locals {
  organization = "cloudyjourney"

  projects = {
    "Team-one" = {
      name = "Team-one-${random_string.value.result}"
      description = "Project used by Team-one to manage their environments"
    },
    "Team-two" = {
      name = "Team-two-${random_string.value.result}"
      description = "Project used by Team-two to manage their environments"
    }
  }

  environment_types = {
    "development" = {
      name        = "et-development"
      description = "Development environment"
      target_subscription_id = data.azurerm_client_config.current.subscription_id
    },
    "sandbox" = {
      name        = "et-sandbox"
      description = "Sandbox environment"
      target_subscription_id = data.azurerm_client_config.current.subscription_id
    }
  }

  tags = { azd-env-name : var.environment_name }

}

##############################
# Resource group
##############################
resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.organization}-${random_string.value.result}"
  location = var.location
  // Tag the resource group with the azd environment name
  // This should also be applied to all resources created in this module
  tags = { azd-env-name : var.environment_name }
}

##############################
# DevCenter
##############################
resource "azapi_resource" "devcenter" {
  type      = "Microsoft.DevCenter/devcenters@2023-04-01"
  name      = "dc-${local.organization}-${random_string.value.result}"
  location  = azurerm_resource_group.rg.location
  parent_id = azurerm_resource_group.rg.id
  identity {
    type         = "SystemAssigned"
    identity_ids = [] # only used when type contains UserAssigned to reference the user assigned identity
  }
  body = jsonencode({
    properties = {}
  })

  tags = { azd-env-name : var.environment_name }
}

##############################
# Key vault
# To store the GitHub token to connect to the GitHub repo that will act as our DevCenter catalog
##############################
resource "azurerm_key_vault" "keyvault" {
  name                      = "akv-devcenter-${random_string.value.result}"
  location                  = azurerm_resource_group.rg.location
  resource_group_name       = azurerm_resource_group.rg.name
  sku_name                  = "standard"
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  enable_rbac_authorization = true

  tags = { azd-env-name : var.environment_name }
}

##############################
# RBAC assignment: grant DevCenter system managed identity Owner access to the subscription
#   - Identity: dev center system managed identity
#   - Role: Owner
#   - Scope: Subscription
##############################
resource "azurerm_role_assignment" "devcenter_sai_sub_owner_sai" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Owner"
  principal_id         = azapi_resource.devcenter.identity[0].principal_id
}

##############################
# RBAC assignment: grant Terraform admin access to the key vault secrets for resource's management
#   - Identity: Terraform admin
#   - Role: Key Vault Administrator
#   - Scope: Key Vault
##############################
resource "azurerm_role_assignment" "tf_admin" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

##############################
# RBAC assignment: grant DevCenter system managed identity Key Vault Secrets User access to the key vault
#   - Identity: dev center system managed identity
#   - Role: Key Vault Secrets User
#   - Scope: Key Vault
##############################
resource "azurerm_role_assignment" "devcenter_sai_keyvault_secret_reader" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azapi_resource.devcenter.identity[0].principal_id
}

##############################
# Key Vault Secret: add GitHub token as secret
##############################
resource "azurerm_key_vault_secret" "github_token" {
  name         = "github-token"
  value        = var.github_token
  key_vault_id = azurerm_key_vault.keyvault.id

  depends_on = [
    azurerm_role_assignment.devcenter_sai_keyvault_secret_reader,
    # azurerm_role_assignment.devcenter_uai_keyvault_secret_reader, 
    azurerm_role_assignment.tf_admin
  ]
}

##############################
# DevCenter Catalog
##############################
resource "azapi_resource" "default_catalog" {
  type      = "Microsoft.DevCenter/devcenters/catalogs@2023-04-01"
  name      = "catalog-${local.organization}-${random_string.value.result}"
  parent_id = azapi_resource.devcenter.id
  body = jsonencode({
    properties = {
      gitHub = {
        branch           = "main"
        path             = ""
        secretIdentifier = azurerm_key_vault_secret.github_token.id
        uri              = "https://github.com/${var.github_owner}/${var.github_repo}.git"
      }
    }
  })
}

##############################
# DevCenter environment types
##############################
resource "azapi_resource" "environment_type" {
  for_each = local.environment_types

  type      = "Microsoft.DevCenter/devcenters/environmentTypes@2023-04-01"
  name      = each.value.name
  parent_id = azapi_resource.devcenter.id
  body = jsonencode({
    properties = {}
  })
}

##############################
# DevCenter Projects
##############################
module "project" {
  for_each = local.projects

  source              = "./modules/devcenter_project"
  resource_group_id   = azurerm_resource_group.rg.id
  location            = azurerm_resource_group.rg.location
  devcenter_id        = azapi_resource.devcenter.id
  project_name        = each.value.name
  project_description = each.value.name
  environment_types   = local.environment_types
  current_user        = data.azurerm_client_config.current.object_id
}