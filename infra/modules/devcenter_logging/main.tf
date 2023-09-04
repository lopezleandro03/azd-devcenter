##############################
# Log Analytics Workspace
##############################
resource "azurerm_log_analytics_workspace" "law" {
  name                = var.law_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

##############################
# Diagnostic Settings
##############################
resource "azurerm_monitor_diagnostic_setting" "settings" {
  name                       = "logs"
  target_resource_id         = var.devcenter_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category_group = "audit"

    retention_policy {
      enabled = false
    }
  }

  enabled_log {
    category_group = "allLogs"

    retention_policy {
      enabled = false
    }
  }
}