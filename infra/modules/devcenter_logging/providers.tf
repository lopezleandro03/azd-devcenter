terraform {
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~>1.8.0"
    }
    azurerm = {
      version = "~>3.47.0"
      source  = "hashicorp/azurerm"
    }
  }
}