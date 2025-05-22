terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.22.0"
    }
  }
}

module "resource_group" {
  source              = "./modules/resource_group"
  resource_group_name = local.resource_group_name
  location            = var.location
  tags                = local.common_tags
}

module "hostpool" {
  source              = "./modules/hostpool"
  resource_group_name = local.resource_group_name
  location            = var.location
  hostpool_name       = local.hostpool_name
  tags                = local.common_tags
}

module "application_group" {
  source                  = "./modules/application_group"
  resource_group_name     = local.resource_group_name
  location                = var.location
  hostpool_id             = module.hostpool.id
  application_group_name  = local.application_group_name
  tags                    = local.common_tags
}

module "workspace" {
  source               = "./modules/workspace"
  resource_group_name  = local.resource_group_name
  location             = var.location
  application_group_id = module.application_group.id
  workspace_name       = local.workspace_name
  tags                 = local.common_tags
}

module "shared_image_gallery" {
  source              = "./modules/shared_image_gallery"
  resource_group_name = local.resource_group_name
  location            = var.location

  sig_name    = local.sig_name
  image_name  = local.sig_image_name
  publisher   = local.sig_publisher
  offer       = local.sig_offer
  sku         = local.sig_sku
}

module "avd_workspace_binding" {
  source               = "./modules/avd_workspace_binding"
  resource_group_name  = local.resource_group_name
  workspace_id         = module.workspace.id
  application_group_id = module.application_group.id
}

resource "local_file" "packer_vars" {
  filename = "${path.module}/../packer/terraform.auto.pkrvars.json"

  content = jsonencode({
    sig_name               = local.sig_name
    sig_image_name         = local.sig_image_name
    sig_image_version      = local.sig_image_version
    sig_rg_name            = local.resource_group_name
    subscription_id        = var.subscription_id
    tenant_id              = var.tenant_id
    client_id              = var.client_id
    client_secret          = var.client_secret
    location               = var.location
    winrm_password         = random_password.winrm.result
  })
}

resource "random_password" "winrm" {
  length               = 16
  special              = true
  override_special = "%$!"
  upper                = true
  lower                = true
  numeric = true
}

variable "generate_winrm_password" {
  type        = bool
  default     = true
  description = "Steuert, ob ein neues WinRM-Passwort erzeugt werden soll"
}