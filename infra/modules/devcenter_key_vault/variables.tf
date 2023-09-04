variable "key_vault_name" {
  description = "The name of the key vault"
  type        = string
}

variable "location" {
  description = "The location of the resource"
  type        = string
}

variable "resource_group_name" {
  description = "The id of the resource group"
  type        = string
}

variable "tags" {
  description = "The tags to associate with the resource"
  type        = map(string)
}

variable "rbac_assignments" {
  description = "The RBAC assignments to apply to the key vault"
  type        = map(object({
    role_definition_name = string
    principal_id         = string
  }))
}

variable "secrets" {
  description = "The secrets to store in the key vault"
  type        = map(object({
    description = string
    value       = string
  }))
}