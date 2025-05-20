variable "resource_group_name" {
  description = "Name der Resource Group, in der die SIG erstellt wird"
  type        = string
}

variable "location" {
  description = "Azure Region"
  type        = string
}

variable "sig_name" {
  description = "Name der Shared Image Gallery"
  type        = string
}

variable "image_name" {
  description = "Name der Image Definition"
  type        = string
}

variable "publisher" {
  description = "Publisher für die SIG-Image-Definition"
  type        = string
  default     = "ramboeck"
}

variable "offer" {
  description = "Offer-Name für das Image"
  type        = string
  default     = "avd"
}

variable "sku" {
  description = "SKU-Name für das Image"
  type        = string
  default     = "enterprise"
}
