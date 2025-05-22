locals {
  # Normalisierte Eingaben
  normalized_customer = lower(replace(var.customer, " ", ""))
  normalized_location = lower(replace(var.location, " ", ""))
  name_prefix         = "${local.normalized_customer}-${var.environment}-${local.normalized_location}"

  # Ressourcen-Namen
  resource_group_name      = "${local.name_prefix}-rg"
  hostpool_name            = "${local.name_prefix}-hostpool"
  application_group_name   = "${local.name_prefix}-ag-desktop"
  workspace_name           = "${local.name_prefix}-ws"

  # shared image gallery
  sig_name       = "avd_sig"
  sig_image_name = "avd-goldenimage"
  sig_offer      = "avd"
  sig_sku        = "enterprise"
  sig_publisher  = "ramboeck"
  sig_image_version = formatdate("2025.01.19",timestamp())

  # Einheitliche Tags
  common_tags = {
    Customer    = title(var.customer)
    Environment = var.environment
    Region      = var.location
    ManagedBy   = "Terraform"
  }
}
