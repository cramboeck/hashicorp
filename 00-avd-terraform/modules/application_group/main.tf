resource "azurerm_virtual_desktop_application_group" "this" {
  name                = var.application_group_name
  location            = var.location
  resource_group_name = var.resource_group_name
  host_pool_id        = var.hostpool_id
  type                = "Desktop"
  tags                = var.tags  
}
