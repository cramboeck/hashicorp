variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "hostpool_id" {
  type = string
}

variable "application_group_name" {
  type = string
}

variable "tags" {
  description = "Tags, die auf die AVD Application Group angewendet werden sollen"
  type        = map(string)
}
