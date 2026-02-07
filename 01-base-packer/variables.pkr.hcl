variable "location" {
  type        = string
  description = "Azure Region (z.B. 'westeurope', 'northeurope')"
}

variable "sig_name" {
  type        = string
  description = "Name der Shared Image Gallery"
}

variable "sig_image_name" {
  type        = string
  description = "Name der Image Definition in der SIG"
}

variable "sig_image_version" {
  type        = string
  description = "Version des Images (z.B. '2025.02.07')"
}

variable "sig_rg_name" {
  type        = string
  description = "Resource Group Name für die Shared Image Gallery"
}

variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
}

variable "tenant_id" {
  type        = string
  description = "Azure Tenant ID"
}

variable "client_id" {
  type        = string
  description = "Azure Service Principal Client ID"
}

variable "client_secret" {
  type        = string
  description = "Azure Service Principal Client Secret"
  sensitive   = true
}

variable "winrm_password" {
  type        = string
  description = "Temporäres WinRM Passwort für Packer"
  sensitive   = true
}

variable "publisher" {
  type        = string
  description = "Azure Marketplace Image Publisher"
  default     = "MicrosoftWindowsDesktop"
}

variable "offer" {
  type        = string
  description = "Azure Marketplace Image Offer"
  default     = "office-365"
}

variable "sku" {
  type        = string
  description = "Azure Marketplace Image SKU"
  default     = "win11-25h2-avd-m365"
}
