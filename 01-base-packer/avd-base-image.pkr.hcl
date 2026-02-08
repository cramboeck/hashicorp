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

  # Location MUSS gesetzt sein!
  location = "westeurope"

  # Temporäre Resource Group für Build
  build_resource_group_name = "packer-temp-rg"

  temp_compute_name = "pkr-base-vm"
  temp_nic_name     = "pkr-base-vm-nic"

  # 🧱 Ziel: Shared Image Gallery
  shared_image_gallery_destination {
    subscription             = var.subscription_id
    resource_group           = var.sig_rg_name
    gallery_name             = "avd_sig"
    image_name               = var.sig_image_name
    image_version            = var.sig_image_version
    storage_account_type     = "Standard_LRS"

    target_region {
      name = "westeurope"
    }
  }

  # 📦 Basisimage (Marketplace) - Windows 11 25H2 Multisession mit Office 365
  image_publisher = "MicrosoftWindowsDesktop"
  image_offer     = "office-365"
  image_sku       = "win11-25h2-avd-m365"  # Windows 11 25H2 Multisession + Office
  image_version   = "latest"
  os_type         = "Windows"
  vm_size         = "Standard_D4s_v5"  # Größere VM für schnelleren Build

  # 🔐 Sicherheitsoptionen: Trusted Launch
  security_type       = "TrustedLaunch"
  secure_boot_enabled = true
  vtpm_enabled        = true

  # 🔌 Kommunikation via WinRM
  # WinRM muss beim VM-Boot aktiviert werden!
  communicator      = "winrm"
  winrm_username    = "packer"
  winrm_password    = var.winrm_password
  winrm_use_ssl     = false
  winrm_insecure    = true
  winrm_timeout     = "30m"

  azure_tags = {
    CreatedBy = "Packer"
    Project   = "AVD"
    BuildType = "base-image"
  }
}

build {
  sources = ["source.azure-arm.avd"]

  #### Schritt 1: AzCopy installieren ####
  provisioner "powershell" {
    inline = [
      "Write-Host 'Installing AzCopy...'",
      "New-Item -Path 'c:\\install' -ItemType Directory -Force | Out-Null",
      "Invoke-WebRequest -Uri 'https://aka.ms/downloadazcopy-v10-windows' -OutFile 'c:\\install\\azcopy.zip' -UseBasicParsing",
      "Expand-Archive -Path 'c:\\install\\azcopy.zip' -DestinationPath 'c:\\install' -Force",
      "$azPath = Get-ChildItem -Path 'c:\\install\\azcopy_windows_amd64*\\azcopy.exe' -Recurse -ErrorAction Stop | Select-Object -ExpandProperty FullName",
      "Copy-Item -Path $azPath -Destination 'c:\\install\\azcopy.exe' -Force",
      "Write-Host 'AzCopy installed successfully'"
    ]
  }

  #### Schritt 2: Language Packs installieren ####
  provisioner "file" {
    source      = "data/languages.json"
    destination = "C:/Install/languages.json"
  }

  provisioner "powershell" {
    script = "scripts/install-languages.ps1"
  }

  #### Schritt 3: Reboot nach Language Packs ####
  provisioner "windows-restart" {
    restart_timeout = "15m"
  }

  #### Schritt 4: Sysprep für Image-Erstellung ####
  provisioner "powershell" {
    inline = [
      "Write-Host 'Starting Sysprep...'",
      "& C:\\Windows\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /shutdown /quiet /mode:vm"
    ]
  }
}
