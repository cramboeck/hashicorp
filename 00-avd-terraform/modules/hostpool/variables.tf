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

variable "friendly_name" {
  type        = string
  description = "Friendly name for the host pool"
  default     = "Terraform Managed Hostpool"
}

variable "custom_rdp_properties" {
  type        = string
  description = "Custom RDP properties for the host pool"
  default     = "enablecredsspsupport:i:1;videoplaybackmode:i:1;audiomode:i:0;devicestoredirect:s:*;drivestoredirect:s:*;redirectclipboard:i:1;redirectcomports:i:1;redirectprinters:i:1;redirectsmartcards:i:1;redirectwebauthn:i:1;usbdevicestoredirect:s:*;use multimon:i:0;enablerdsaadauth:i:1;screen mode id:i:1;smart sizing:i:1;dynamic resolution:i:1;"
}