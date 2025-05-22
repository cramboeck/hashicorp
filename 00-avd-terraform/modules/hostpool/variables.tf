variable "resource_group_name" {
  type = string
}

variable "location" {
 description = "Azure Location"
  type = string
}

variable "hostpool_name" {
  description = "Hostpoolname - bspw. AVD-Prod-HP"
  type = string
}

variable "maximum_sessions_allowed" {
    description = "value"
    type = number
    default = 10
}

variable "tags" {
  description = "Tags, die auf den AVD Hostpool angewendet werden sollen"
  type        = map(string)
}