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

  #location = var.location

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
  vm_size         = "Standard_D2s_v4"

  # 🔐 Sicherheitsoptionen: Trusted Launch
  security_type       = "TrustedLaunch"
  secure_boot_enabled = true
  vtpm_enabled        = true

  # 🔌 Kommunikation via WinRM
  # HINWEIS: WinRM über HTTP ist für temporäre Packer-Build-VMs akzeptabel,
  # da diese VMs nur während des Builds existieren und in einem isolierten Netzwerk laufen.
  # In Produktionsumgebungen sollte WinRM über HTTPS mit Zertifikaten konfiguriert werden.
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

  #### //// INSTALLING AZCOPY to C:\install //// ####

provisioner "powershell" {
  inline = [
    # Create folder structure
    "New-Item -Path 'c:\\install' -ItemType Directory -Force | Out-Null",

    # Download AzCopy
    "Invoke-WebRequest -Uri 'https://aka.ms/downloadazcopy-v10-windows' -OutFile 'c:\\install\\azcopy.zip'",

    # Extract AzCopy archive
    "Expand-Archive -Path 'c:\\install\\azcopy.zip' -DestinationPath 'c:\\install' -Force",

    # Move azcopy.exe to final path
    "$azPath = Get-ChildItem -Path 'c:\\install\\azcopy_windows_amd64*\\azcopy.exe' -Recurse -ErrorAction Stop | Select-Object -ExpandProperty FullName",
    "Copy-Item -Path $azPath -Destination 'c:\\install\\azcopy.exe' -Force",

    ]
  }

 provisioner "powershell" {
    script = "scripts/Enable-WinRM.ps1"
  }
  
  provisioner "file" {
    source      = "data/languages.json"
    destination = "C:/Install/languages.json"
  }

  provisioner "powershell" {
    script = "scripts/install-languages.ps1"
  }

  provisioner "windows-restart" {}

  provisioner "powershell" {
    inline = [
      "Write-Host '[FINISHING] Starte Sysprep...'",
      "C:\\Windows\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /shutdown /quiet /mode:vm"
    ]
  }
}
