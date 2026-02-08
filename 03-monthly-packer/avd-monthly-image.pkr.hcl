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

  # Existierende Resource Group für Build (Location wird daraus abgeleitet)
  build_resource_group_name = "packer-temp-rg"

  # Source Image aus SIG (neueste Version für monatliches Update)
  shared_image_gallery {
    subscription   = var.subscription_id
    resource_group = var.sig_rg_name
    gallery_name   = "avd_sig"
    image_name     = var.sig_image_name
    image_version  = "latest"
  }

  # Ziel: Zurück in die SIG mit neuer Version
  shared_image_gallery_destination {
    subscription         = var.subscription_id
    resource_group       = var.sig_rg_name
    gallery_name         = "avd_sig"
    image_name           = var.sig_image_name
    storage_account_type = "Standard_LRS"
    image_version        = var.sig_image_version

    target_region {
      name = "westeurope"
    }
  }

  # Windows OS & VM Size
  os_type  = "Windows"
  vm_size  = "Standard_D4s_v3"

  # Sicherheitsoptionen: Trusted Launch (MUSS mit SIG Image Definition übereinstimmen!)
  security_type       = "TrustedLaunch"
  secure_boot_enabled = true
  vtpm_enabled        = true

  # Communicator
  communicator      = "winrm"
  winrm_username    = "packer"
  winrm_password    = var.winrm_password
  winrm_use_ssl     = false
  winrm_insecure    = true
  winrm_timeout     = "15m"

  azure_tags = {
    CreatedBy = "Packer"
    Project   = "AVD"
  }
}

build {
  sources = ["source.azure-arm.avd"]

  #### ////  Windows Updateinstallation

  provisioner "powershell" {
   script = "scripts/windows-updates.ps1"
  }

  provisioner "windows-restart" {}

  #### //// Office 365 Updateinstallation
  provisioner "powershell" {
   script = "scripts/update-microsoft365.ps1"
  }

  #### //// Update Software using Chocolatey
  provisioner "powershell" {
   script = "scripts/update-software.ps1"
  }

  provisioner "windows-restart" {}

  provisioner "powershell" {
    inline = [
      "Write-Host '[FINISHING] Starte Sysprep...'",
      "C:\\Windows\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /shutdown /quiet /mode:vm"
    ]
  }
}
