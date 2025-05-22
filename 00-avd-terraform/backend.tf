terraform {
  backend "azurerm" {
    resource_group_name  = "Storage-RG"
    storage_account_name = "ramboeckit"
    container_name       = "tfstate"
    key                  = "avd/terraform.tfstate"
  }
}
