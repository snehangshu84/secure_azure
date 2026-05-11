# variables.tf

variable "location" {
  description = "The Azure region where resources will be deployed."
  type        = string
  default     = "eastus"
}

variable "prefix" {
  description = "A unique prefix for all deployed resources."
  type        = string
  default     = "myappprefix"
}

variable "cidr_block" {
  description = "The overall primary CIDR block for the Virtual Network."
  type        = string
  default     = "10.0.0.0/16"
}
