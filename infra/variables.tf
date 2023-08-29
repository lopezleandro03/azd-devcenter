variable "location" {
  description = "The supported Azure location where the resource deployed"
  type        = string
}

variable "environment_name" {
  description = "The name of the azd environment to be deployed"
  type        = string
}

variable "github_token" {
  description = "The github token to be used to access the github repo"
  sensitive   = true
  type        = string
}

variable "github_owner" {
  description = "The name of the github owner"
  type        = string
  default     = "azure"
}

variable "github_repo" {
  description = "The name of the github repo"
  type        = string
  default     = "deployment-environments"
}

variable "tenant_id" {
  description = "The tenant id of the Azure subscription"
  type        = string
}