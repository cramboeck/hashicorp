variable "resource_group_name" {
  description = "Name der Resource Group"
  type        = string
}

variable "location" {
  description = "Azure Region, in der die Resource Group erstellt wird"
  type        = string
}

variable "tags" {
  description = "Tags, die auf die Resource Group angewendet werden sollen"
  type        = map(string)
}
