# ============================================================================
# Terraform Backend Configuration
# ============================================================================
#
# HINWEIS: Für den ersten Test verwenden wir ein lokales Backend.
# Für Production sollten Sie ein Remote-Backend (Azure Storage) verwenden.
#
# Um Remote-Backend zu aktivieren:
# 1. Erstellen Sie einen Azure Storage Account
# 2. Kommentieren Sie den unteren Block ein
# 3. Passen Sie die Werte an
# 4. Führen Sie "terraform init -migrate-state" aus
# ============================================================================

# Lokales Backend (Standard für Tests)
# Terraform State wird lokal gespeichert in: terraform.tfstate

# Remote Backend (für Production - aktuell deaktiviert)
# Backup der originalen Konfiguration in: backend.tf.remote-backup
#
# terraform {
#   backend "azurerm" {
#     resource_group_name  = "Storage-RG"
#     storage_account_name = "ramboeckit"
#     container_name       = "tfstate"
#     key                  = "avd/terraform.tfstate"
#   }
# }
