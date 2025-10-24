packer {
  required_plugins {
    azure-arm = {
      source  = "github.com/hashicorp/azure"
      version = ">= 2.3.3"
    }
  }
}

source "azure-arm" "avd" {
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id

  build_resource_group_name = "packer-temp-rg"
  temp_compute_name         = "pkr-monthly-vm"
  temp_nic_name             = "pkr-monthly-vm-nic"

  # 🔄 Basisimage - Verwendet neueste Version aus SIG für monatliche Updates
  shared_image_gallery {
    subscription   = var.subscription_id
    resource_group = var.sig_rg_name
    gallery_name   = var.sig_name
    image_name     = var.sig_image_name
    image_version  = "latest"  # Nutzt automatisch die neueste verfügbare Version
  }

  # 🧱 Ziel: Neue Version in Shared Image Gallery
  shared_image_gallery_destination {
    subscription         = var.subscription_id
    resource_group       = var.sig_rg_name
    gallery_name         = var.sig_name
    image_name           = var.sig_image_name
    image_version        = var.sig_image_version
    storage_account_type = "Standard_LRS"

    target_region {
      name                   = var.location
      replicas               = 1
      storage_account_type   = "Standard_LRS"
    }
  }

  # 🔐 Sicherheitsoptionen: Trusted Launch
  security_type       = "TrustedLaunch"
  secure_boot_enabled = true
  vtpm_enabled        = true

  # 🔌 Kommunikation via WinRM
  # HINWEIS: WinRM über HTTP ist für temporäre Packer-Build-VMs akzeptabel,
  # da diese VMs nur während des Builds existieren und in einem isolierten Netzwerk laufen.
  # In Produktionsumgebungen sollte WinRM über HTTPS mit Zertifikaten konfiguriert werden.
  communicator    = "winrm"
  winrm_username  = "packer"
  winrm_password  = var.winrm_password
  winrm_use_ssl   = false
  winrm_insecure  = true
  winrm_timeout   = "15m"

  azure_tags = {
    CreatedBy = "Packer"
    Project   = "AVD"
    Stage     = "MonthlyUpdate"
  }
}

build {
  sources = ["source.azure-arm.avd"]

  #### //// Windows Updates ####
  provisioner "powershell" {
    script = "scripts/Install_WindowsUpdates.ps1"
  }

  provisioner "windows-restart" {}

  #### //// Microsoft Office 365 Updates ####
  provisioner "powershell" {
    script = "scripts/Update-MSOffice365.ps1"
  }

  #### //// Software Updates (Chocolatey) ####
  provisioner "powershell" {
    script = "scripts/Update-Software.ps1"
  }

  #### //// VDOT Re-Optimization (Optional) ####
  provisioner "powershell" {
    script = "scripts/Install-VDOT.ps1"
  }

  provisioner "windows-restart" {}

  #### //// Sysprep & Generalize ####
  provisioner "powershell" {
    inline = [
      "Write-Host '[FINISHING] Starte Sysprep...'",
      "C:\\Windows\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /shutdown /quiet /mode:vm"
    ]
  }
}
