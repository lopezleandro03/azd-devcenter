
##############################
# DevCenter project
##############################
resource "azapi_resource" "project" {
  type      = "Microsoft.DevCenter/projects@2023-04-01"
  name      = var.project_name
  location  = var.location
  parent_id = var.resource_group_id
  body = jsonencode({
    properties = {
      description = var.project_description
      devCenterId = var.devcenter_id
    }
  })
}

##############################
# DevCenter project's environment type definitions
##############################
module "environment_type_definition" {
  for_each = var.environment_types

  source                 = "../devcenter_environment"
  location               = var.location
  project_name           = var.project_name
  project_id             = azapi_resource.project.id
  environment_name       = each.value.name
  target_subscription_id = each.value.target_subscription_id
}

##############################
# Create RBAC Assignment: grant project memebers access to the DevCenter project
#   - Identity: each project member define in root main.tf
#   - Role: Deployment Environments User
#   - Scope: Project
##############################
resource "azurerm_role_assignment" "devcenter_environment_user" {
  for_each = toset(var.project_members)

  scope                = azapi_resource.project.id
  role_definition_name = "Deployment Environments User"
  principal_id         = each.key
}