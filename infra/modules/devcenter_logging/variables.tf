variable "law_name" {
  description = "The name of the Log Analytics Workspace"
  type        = string
}

variable "devcenter_id" {
  description = "The id of the DevCenter resource"
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