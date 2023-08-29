# Configure desired versions of terraform, azurerm provider
terraform {
  required_version = ">= 1.1.7, < 2.0.0"
  required_providers {
    azurerm = {
      version = "~>3.47.0"
      source  = "hashicorp/azurerm"
    }
    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = "~>1.2.24"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~>1.8.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.15.0"
    }
    time = {
      source = "hashicorp/time"
    }
    null = {
      source = "hashicorp/null"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "azapi" {
  default_location = var.location
}

provider "azuread" {
  tenant_id = var.tenant_id
}

# Enable features for azurerm
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Access client_id, tenant_id, subscription_id and object_id configuration values
data "azurerm_client_config" "current" {}
