variable "resource_group_id" {
  type        = string
  description = "The ID of the resource group in which to create the Dev Center project."
}

variable "location" {
  type        = string
  description = "The location/region in which to create the Dev Center project."
}

variable "devcenter_id" {
  type        = string
  description = "The ID of the Dev Center project."
}

variable "project_name" {
  type        = string
  description = "The name of the Dev Center project."
}

variable "project_description" {
  type        = string
  description = "The description of the Dev Center project."
}

variable "project_members" {
  type        = list(string)
  description = "The members of the Dev Center project."
}

variable "environment_types" {
  type = map(object({
    name                   = string
    description            = string
    target_subscription_id = string
  }))
  description = "The environment types to create on the Dev Center project."
}