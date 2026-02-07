resource "azurerm_shared_image_gallery" "this" {
  name                = var.sig_name
  resource_group_name = var.resource_group_name
  location            = var.location
  description         = "Shared Image Gallery für AVD-Builds"
}

resource "azurerm_shared_image" "this" {
  name                = var.image_name
  gallery_name        = azurerm_shared_image_gallery.this.name
  resource_group_name = var.resource_group_name
  location            = var.location

  os_type             = "Windows"
  hyper_v_generation  = "V2"
  architecture        = "x64"

  accelerated_network_support_enabled = true
  hibernation_enabled                 = true
  trusted_launch_enabled              = true

  identifier {
    publisher = var.publisher
    offer     = var.offer
    sku       = var.sku
  }
}
