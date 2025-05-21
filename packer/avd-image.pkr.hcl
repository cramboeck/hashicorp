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
  vm_size         = "Standard_D2s_v4"

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

  #### //// INSTALLING Greenshot using PADT Toolkit Package //// ####

provisioner "powershell" {
  inline = [
    # Download software archive from Blob (replace <SAS_URL> below)
    "c:\\install\\azcopy.exe copy 'https://ramboeckit.blob.core.windows.net/azureimagebuilder/PADT-Greenshot.zip?sp=r&st=2025-05-21T10:47:08Z&se=2025-06-07T18:47:08Z&spr=https&sv=2024-11-04&sr=b&sig=8RFNUowi6kiipJ%2BM6Yt0iKtp6b5zSoDA%2FItWj2YfayA%3D' 'c:\\install\\PADT-Greenshot.zip' --recursive",
    # Extract the downloaded archive
    "Expand-Archive -Path 'c:\\install\\PADT-Greenshot.zip' -DestinationPath 'c:\\install' -Force",
    "C:\\Install\\PADT-Greenshot\\Invoke-AppDeployToolkit.ps1 -DeployMode Silent"
  ]
}

  #### //// INSTALLING CountrySwitch using PADT Toolkit Package //// ####
provisioner "powershell" {
  inline = [
    # Download software archive from Blob (replace <SAS_URL> below)
    "c:\\install\\azcopy.exe copy 'https://ramboeckit.blob.core.windows.net/softwarerepo/PADT-CountrySwitch.zip?sp=r&st=2025-05-20T21:37:11Z&se=2025-05-21T05:37:11Z&spr=https&sv=2024-11-04&sr=b&sig=Ka87g71%2FtrK6BIrup1d%2BvlY2OBoFOto5V98AJuznCA8%3D' 'c:\\install\\PADT-CountrySwitch.zip' --recursive",
    # Extract the downloaded archive
    "Expand-Archive -Path 'c:\\install\\PADT-CountrySwitch.zip' -DestinationPath 'c:\\install' -Force",
    "C:\\Install\\PADT-CountrySwitch\\Invoke-AppDeployToolkit.ps1 -DeployMode Silent"
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
