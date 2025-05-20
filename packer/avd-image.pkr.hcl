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

  #location                           = var.location
  build_resource_group_name          = "packer-temp-rg"
  managed_image_resource_group_name = var.sig_rg_name
  managed_image_name                = var.sig_image_name

  # Basisimage (z. B. Windows 11 AVD mit M365)
  image_publisher = "MicrosoftWindowsDesktop"
  image_offer     = "office-365"
  image_sku       = "win11-24h2-avd-m365"
  image_version   = "latest"
  os_type         = "Windows"
  vm_size =  "Standard_D2s_v4"

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

  
  #### //// INSTALLING GREENSHOT using PADT Toolkit Package //// ####
  provisioner "file" {
    source      = "scripts/PADT-Greenshot"
    destination = "C:/Install/"
  }
  provisioner "powershell" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -NoProfile -File C:\\Install\\PADT-Greenshot\\Invoke-AppDeployToolkit.ps1 -DeployMode Silent" 
    ]
  }

  #### //// INSTALLING CountrySwitch using PADT Toolkit Package //// ####
  provisioner "file" {
    source      = "scripts/PADT-CountrySwitch"
    destination = "C:/Install/"
  }

  provisioner "powershell" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -NoProfile -File C:\\Install\\PADT-CountrySwitch\\Invoke-AppDeployToolkit.ps1 -DeployMode Silent" 
    ]
  }

  # Cleanup Sources
  provisioner "powershell" {
    inline = [
      "Remove-Item -Recurse -Force C:\\Install\\*"
    ]
  }


  # Default Provisioners in Powershell
  provisioner "powershell" {
    script = "scripts/install-software.ps1"
  }

  provisioner "powershell" {
    script = "scripts/install-vdot.ps1"
  }

  provisioner "powershell" {
    script = "scripts/optimize.ps1"
  }

  #provisioner "powershell" {
  #  script = "scripts/windows-updates.ps1"
  #}

  provisioner "windows-restart" {}

  provisioner "powershell" {
    inline = [
      "Write-Host '📦 Starte Sysprep...'",
      "C:\\Windows\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /shutdown /quiet /mode:vm"
    ]
  }
}
