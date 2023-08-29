
##############################
# DevCenter project
##############################
resource "azapi_resource" "project" {
  type = "Microsoft.DevCenter/projects@2023-04-01"
  name = var.project_name
  location = var.location
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

  source = "../devcenter_environment"
  location = var.location
  project_name = var.project_name
  project_id = azapi_resource.project.id
  environment_name = each.value.name
  target_subscription_id = each.value.target_subscription_id
}

##############################
# Create RBAC Assignment: grant current user access to the DevCenter project
#   - Identity: Terraform admin (a developer identity could be used instead)
#   - Role: Deployment Environments User
#   - Scope: Project
##############################
resource "azurerm_role_assignment" "devcenter_environment_user" {
  count = var.make_current_user_ade_user ? 1 : 0

  scope                = azapi_resource.project.id
  role_definition_name = "Deployment Environments User"
  principal_id         = var.current_user
}