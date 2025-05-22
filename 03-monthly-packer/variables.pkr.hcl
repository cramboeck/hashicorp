variable "location" {
  type = string
}
variable "client_id" {
  description = "Azure Client ID (App Registration)"
  type        = string
}

variable "client_secret" {
  description = "Azure Client Secret"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "winrm_password" {
  description = "Temporäres Passwort für den Packer-Benutzer"
  type        = string
  sensitive   = true
  
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
  description = "Version des Images in der SIG (z.B. 2025.05.19)"
}

variable "sig_rg_name" {
  type        = string
  description = "Resource Group, in der sich die Shared Image Gallery befindet"
}

