# Input variables for the module

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
  sensitive = true
  type        = string
}

variable "github_owner" {
  description = "The name of the github owner"
  type        = string
}

variable "github_repo" {
  description = "The name of the github repo"
  type        = string
}
