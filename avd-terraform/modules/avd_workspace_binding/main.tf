resource "azurerm_virtual_desktop_workspace_application_group_association" "this" {
  workspace_id         = var.workspace_id
  application_group_id = var.application_group_id
}
