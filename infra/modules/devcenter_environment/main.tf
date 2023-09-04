
##############################
# Environment type definition
##############################
resource "azapi_resource" "environment_type_definition" {
  type      = "Microsoft.DevCenter/projects/environmentTypes@2023-04-01"
  name      = var.environment_name
  location  = var.location
  parent_id = var.project_id
  identity {
    type = "SystemAssigned"
    # identity_ids = [] # only used when type contains UserAssigned to reference the user assigned identity
    identity_ids = []
  }
  body = jsonencode({
    properties = {
      # creatorRoleAssignment = {
      #   roles = {"Owner" = []}
      # }
      deploymentTargetId = "/subscriptions/${var.target_subscription_id}"
      status             = "Enabled"
      # userRoleAssignments = {}
    }
  })
}

# Wait for environment type dev definition to be created and managed identity replicated to AAD
# Doing this inmediately after would fail with a "identity not found" error
resource "time_sleep" "wait_30_seconds" {
  depends_on = [azapi_resource.environment_type_definition]

  create_duration = "30s"
}

# Lookup principal_id for the project system assigned identity
data "azuread_service_principal" "environment_type_smi" {
  display_name = "${var.project_name}/environmentTypes/${var.environment_name}"

  depends_on = [time_sleep.wait_30_seconds]
}

##############################
# Create RBAC Assignment: grant project system assigned identity Owner access to target subscription
#   - Identity: dev center project smi
#   - Role: Owner
#   - Scope: Subscription
##############################
resource "azurerm_role_assignment" "project_owner_sub" {
  scope                = "/subscriptions/${var.target_subscription_id}"
  role_definition_name = "Owner"
  principal_id         = data.azuread_service_principal.environment_type_smi.object_id
}

##############################
# Allow Environment Type
##############################
data "azapi_resource" "allowed_env_types" {
  type      = "Microsoft.DevCenter/projects/allowedEnvironmentTypes@2023-04-01"
  name      = var.environment_name
  parent_id = var.project_id

  depends_on = [azapi_resource.environment_type_definition]
}