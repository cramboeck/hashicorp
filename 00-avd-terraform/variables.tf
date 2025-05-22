
variable "client_id" {
  description = "Client ID der Azure App Registration (Service Principal) für die Authentifizierung."
  type        = string
}

variable "client_secret" {
  description = "Client Secret der Azure App Registration (Service Principal)."
  type        = string
  sensitive   = true
}

variable "subscription_id" {
  description = "Azure Subscription ID, unter der die Ressourcen bereitgestellt werden."
  type        = string
}

variable "tenant_id" {
  description = "Azure Active Directory Tenant ID."
  type        = string
}



variable "customer" {
  description = "Kundenkürzel oder Name (z.B. 'meier', 'acme')"
  type        = string
}

variable "environment" {
  description = "Umgebung (z.B. 'dev', 'test', 'prod')"
  type        = string
}

variable "location" {
  description = "Azure-Region (z.B. 'West Europe')"
  type        = string
}
