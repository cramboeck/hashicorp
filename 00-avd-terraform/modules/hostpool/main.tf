resource "azurerm_virtual_desktop_host_pool" "this" {
  name                = var.hostpool_name
  resource_group_name = var.resource_group_name
  location            = var.location
  type                = "Pooled"
  load_balancer_type  = "BreadthFirst"
  maximum_sessions_allowed   = var.maximum_sessions_allowed
  preferred_app_group_type = "Desktop"
  start_vm_on_connect = true
  validate_environment = false
  tags = var.tags
  friendly_name            = var.friendly_name
  custom_rdp_properties    = var.custom_rdp_properties

  scheduled_agent_updates {
    enabled = true
    schedule {
      day_of_week = "Sunday"
      hour_of_day = "1"
    }
  }
}
