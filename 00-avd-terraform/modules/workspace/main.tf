resource "azurerm_virtual_desktop_workspace" "this" {
  name                = var.workspace_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags = var.tags
}
