##############################
# Key vault
# To store the GitHub token to connect to the GitHub repo that will act as our DevCenter catalog
##############################
resource "azurerm_key_vault" "key_vault" {
  name                      = var.key_vault_name
  location                  = var.location
  resource_group_name       = var.resource_group_name
  sku_name                  = "standard"
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  enable_rbac_authorization = true

  tags = var.tags
}

##############################
# RBAC assignments
##############################
resource "azurerm_role_assignment" "rbac_assignments" {
  for_each = var.rbac_assignments

  scope                = azurerm_key_vault.key_vault.id
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
}

##############################
# Wait for RBAC propagation
##############################
resource "time_sleep" "rbac_propagation" {
  depends_on = [ azurerm_role_assignment.rbac_assignments ]

  create_duration = "30s"
}

##############################
# Secrets
##############################
resource "azurerm_key_vault_secret" "secrets" {
  for_each = var.secrets

  name         = each.key
  value        = each.value.value
  key_vault_id = azurerm_key_vault.key_vault.id

  depends_on = [ time_sleep.rbac_propagation ]
}