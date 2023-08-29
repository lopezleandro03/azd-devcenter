
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
      maxDevBoxesPerUser = 1
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
  current_user =  var.current_user
}
