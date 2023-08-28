##############################
# random_string for k8s resources uniqueness
##############################
resource "random_string" "value" {
  length  = 3
  upper = false
  lower = true
  special = false
}

locals {
  tags                         = { azd-env-name : var.environment_name }
  sha                          = base64encode(sha256("${var.environment_name}${var.location}${data.azurerm_client_config.current.subscription_id}"))
  resource_token               = substr(replace(lower(local.sha), "[^A-Za-z0-9_]", ""), 0, 13)
  organization                 = "contoso"
  project                      = "k8s-multi-tenant"
}

##############################
# Create resource group
##############################
resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.organization}-${random_string.value.result}"
  location = var.location
  // Tag the resource group with the azd environment name
  // This should also be applied to all resources created in this module
  tags = { azd-env-name : var.environment_name }
}

##############################
# Create user Managed Identity 
##############################
# resource "azurerm_user_assigned_identity" "umi_project" {
#   name                = "umi-${local.resource_token}"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
# }

##############################
# Create dev center
##############################
resource "azapi_resource" "devcenter" {
  type = "Microsoft.DevCenter/devcenters@2023-04-01"
  name = "dc-${local.organization}-${random_string.value.result}"
  location = azurerm_resource_group.rg.location
  parent_id = azurerm_resource_group.rg.id
  identity {
    type = "SystemAssigned"
    identity_ids = [ ]
    # type = "SystemAssigned, UserAssigned"
    # identity_ids = [ azurerm_user_assigned_identity.umi_project.id ]
  }
  body = jsonencode({
    properties = {}
  })
}

##############################
# Create key vault
# To store the GitHub token to connect to the GitHub repo (catalog)
##############################
resource "azurerm_key_vault" "keyvault" {
  name                = "akv-${local.resource_token}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id
  enable_rbac_authorization = true
}

##############################
# Create RBAC Assignment
#   - Identity: dev center user managed identity
#   - Role: Owner
#   - Scope: Subscription
##############################
# rbac dev center target sub owner uai
# resource "azurerm_role_assignment" "devcenter_uai_sub_owner_uai" {
#   scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
#   role_definition_name = "Owner"
#   principal_id         = azurerm_user_assigned_identity.umi_project.principal_id
# }

##############################
# Create RBAC Assignment
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
# Create RBAC Assignment
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
# Create RBAC Assignment
#   - Identity: dev center user managed identity
#   - Role: Key Vault Secrets User
#   - Scope: Key Vault
##############################
# resource "azurerm_role_assignment" "devcenter_uai_keyvault_secret_reader" {
#   scope                = azurerm_key_vault.keyvault.id
#   role_definition_name = "Key Vault Secrets User"
#   principal_id         = azurerm_user_assigned_identity.umi_project.principal_id
# }

##############################
# Create RBAC Assignment
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
# Create Key Vault Secret
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
# Create dev center catalog
##############################
resource "azapi_resource" "default_catalog" {
  type = "Microsoft.DevCenter/devcenters/catalogs@2023-04-01"
  name = "catalog-${local.organization}-${random_string.value.result}"
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

##############################
# Create dev center environment type
##############################
resource "azapi_resource" "environment_type_dev" {
  type = "Microsoft.DevCenter/devcenters/environmentTypes@2023-04-01"
  name = "et-development"
  parent_id = azapi_resource.devcenter.id
  body = jsonencode({
    properties = {}
  })
}

##############################
# Create dev center project
##############################
resource "azapi_resource" "project" {
  type = "Microsoft.DevCenter/projects@2023-04-01"
  name = "pr-${local.project}-${random_string.value.result}"
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

##############################
# Create dev center project environment type definition
##############################
resource "azapi_resource" "environment_type_dev_definition" {
  type = "Microsoft.DevCenter/projects/environmentTypes@2023-04-01"
  name = azapi_resource.environment_type_dev.name
  location = azurerm_resource_group.rg.location
  parent_id = azapi_resource.project.id
  identity {
    type = "SystemAssigned"
    # identity_ids = [azurerm_user_assigned_identity.umi_project.id]
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

# Wait for environment type dev definition to be created and managed identity replicated
resource "time_sleep" "wait_30_seconds" {
  depends_on = [azapi_resource.environment_type_dev_definition]

  create_duration = "30s"
}

# lookup principal id for the project smi
data "azuread_service_principal" "environment_type_smi" {
  display_name = "${azapi_resource.project.name}/environmentTypes/${azapi_resource.environment_type_dev.name}"

  depends_on = [ time_sleep.wait_30_seconds ]
}


##############################
# Create RBAC Assignment
#   - Identity: dev center project smi
#   - Role: Key Vault Secrets User
#   - Scope: Key Vault
##############################
resource "azurerm_role_assignment" "project_keyvault_secret_reader" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.azuread_service_principal.environment_type_smi.object_id
}

##############################
# Create RBAC Assignment
#   - Identity: dev center project smi
#   - Role: Owner
#   - Scope: Subscription
##############################
resource "azurerm_role_assignment" "project_owner_sub" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Owner"
  principal_id         = data.azuread_service_principal.environment_type_smi.object_id
}

##############################
# Allow Environment Type on project
##############################
data "azapi_resource" "allowed_env_types" {
  type = "Microsoft.DevCenter/projects/allowedEnvironmentTypes@2023-04-01"
  name = azapi_resource.environment_type_dev.name
  parent_id = azapi_resource.project.id

  depends_on = [ azapi_resource.environment_type_dev_definition ]
}

##############################
# Create RBAC Assignment
#   - Identity: Terraform admin (a developer identity could be used instead)
#   - Role: Deployment Environments User
#   - Scope: Project
##############################
resource "azurerm_role_assignment" "devcenter_environment_user" {
  scope                = azapi_resource.project.id
  role_definition_name = "Deployment Environments User"
  principal_id         = data.azurerm_client_config.current.object_id
}

