variable "resource_group_name" {
  description = "Name der Resource Group"
  type        = string
}

variable "location" {
  description = "Azure Region, in der die Resource Group erstellt wird"
  type        = string
}

variable "application_group_id" {
  description = "Hostpoolname - bspw. AVD-Prod-HP"
  type = string
}

variable "workspace_name" {
  type = string
  description = "Workspacename"
}

variable "tags" {
  description = "Tags, die auf den AVD Workspace angewendet werden sollen"
  type        = map(string)
}
