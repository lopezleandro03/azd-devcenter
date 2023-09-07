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
      name        = "Team-one-${random_string.value.result}"
      description = "Project used by Team-one to manage their environments"
      members     = [data.azurerm_client_config.current.object_id] # make the current user a member of the project, add your devs here
    },
    "Team-two" = {
      name        = "Team-two-${random_string.value.result}"
      description = "Project used by Team-two to manage their environments"
      members     = [data.azurerm_client_config.current.object_id] # make the current user a member of the project, add your devs here
    },
    "Team-three" = {
      name        = "Team-three-${random_string.value.result}"
      description = "Project used by Team-three to manage their environments"
      members     = [data.azurerm_client_config.current.object_id] # make the current user a member of the project, add your devs here
    },
    "Team-four" = {
      name        = "Team-four-${random_string.value.result}"
      description = "Project used by Team-four to manage their environments"
      members     = [data.azurerm_client_config.current.object_id] # make the current user a member of the project, add your devs here
    }
  }

  # TODO: add ability to specify creator roles, user role assignments and user managed identities
  environment_types = {
    "development" = {
      name                   = "et-development"
      description            = "Development environment"
      target_subscription_id = data.azurerm_client_config.current.subscription_id
    },
    "sandbox" = {
      name                   = "et-sandbox"
      description            = "Sandbox environment"
      target_subscription_id = data.azurerm_client_config.current.subscription_id
    },
    "ephemeral-24hs" = {
      name                   = "et-ephemeral-24hs"
      description            = "This environment type will destroy environments after 24hs" # This automation could be set using GitHub Actions and the Azure CLI for DevCenter.
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
  tags = local.tags
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

  tags = local.tags
}

##############################
# Enable logging 
##############################
module "logging" {
  source              = "./modules/devcenter_logging"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  devcenter_id        = azapi_resource.devcenter.id
  law_name            = "law-${local.organization}-${random_string.value.result}"
  tags                = local.tags
}

##############################
# Key vault
# To store the GitHub token to connect to the GitHub repo that will act as our DevCenter catalog
##############################
module "key_vault" {
  source              = "./modules/devcenter_key_vault"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  key_vault_name      = "kv-${local.organization}-${random_string.value.result}"
  tags                = local.tags

  rbac_assignments = {
    "azd-devcenter-sai" = {
      description          = "Grant DevCenter system managed identity Key Vault Secrets User access to the key vault"
      role_definition_name = "Key Vault Secrets User"
      principal_id         = azapi_resource.devcenter.identity[0].principal_id
    },
    "azd-terraform-admin" = {
      description          = "Grant Terraform admin access to the key vault secrets for resource's management"
      role_definition_name = "Key Vault Administrator"
      principal_id         = data.azurerm_client_config.current.object_id
    }
  }

  secrets = {
    "github-token" = {
      description = "The GitHub token to connect to the GitHub repo that will act as our DevCenter catalog"
      value       = var.github_token
    }
  }
}

##############################
# GitHub token ref
##############################
data "azurerm_key_vault_secret" "github_token" {
  name         = "github-token"
  key_vault_id = module.key_vault.key_vault_id

  depends_on = [ module.key_vault ]
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
        secretIdentifier = data.azurerm_key_vault_secret.github_token.id
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
  project_members     = each.value.members
  environment_types   = local.environment_types
}