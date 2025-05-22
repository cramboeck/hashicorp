packer {
  required_plugins {
    azure-arm = {
      source  = "github.com/hashicorp/azure"
      version = ">= 2.3.3"
    }
  }
}

source "azure-arm" "avd" {

  #Authentication variables
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id

  #location                           = var.location
  build_resource_group_name          = "packer-temp-rg"
 

  # Source Image definition 
  #image_publisher = "MicrosoftWindowsDesktop"
  #image_offer     = "office-365"
  #image_sku       = "win11-24h2-avd-m365"
  #image_version   = "latest"
  #managed_image_resource_group_name = var.sig_rg_name
  #managed_image_name                = var.sig_image_name

  shared_image_gallery {
    subscription = var.subscription_id
    resource_group = var.sig_rg_name
    gallery_name = "avd_sig"
    image_name = var.sig_image_name
    image_version = var.sig_image_version
}


# Image Galley Destination definition
    shared_image_gallery_destination {
    subscription = var.subscription_id
    resource_group = var.sig_rg_name
    gallery_name = "avd_sig"  
    image_name = var.sig_image_name
    storage_account_type = "Standard_LRS" 
    image_version = "1.0.2"
        target_region {
      name = "westeurope"
    }
  }

  # windows os & vm size 
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

  #### //// INSTALLING AZCOPY to C:\install or other Prerequisites  //// ####

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

  #### //// INSTALLING Greenshot using custom PADT Toolkit Package //// ####

provisioner "powershell" {
  inline = [
    # Download software archive from Blob (replace <SAS_URL> below)
    "c:\\install\\azcopy.exe copy 'https://ramboeckit.blob.core.windows.net/azureimagebuilder/PADT-Greenshot.zip?sp=r&st=2025-05-21T11:22:05Z&se=2025-05-29T19:22:05Z&spr=https&sv=2024-11-04&sr=b&sig=HfpGm%2Fk%2FLjDW9QuO%2FajcOFtdMf%2Bi7jSJtVk87KNkcUc%3D' 'c:\\install\\PADT-Greenshot.zip' --recursive",
    # Extract the downloaded archive
    "Expand-Archive -Path 'c:\\install\\PADT-Greenshot.zip' -DestinationPath 'c:\\install' -Force",
    "C:\\Install\\PADT-Greenshot\\Invoke-AppDeployToolkit.ps1 -DeployMode Silent"
  ]
}

  #### //// INSTALLING CountrySwitch using  custom PADT Toolkit Package //// ####
provisioner "powershell" {
  inline = [
    # Download software archive from Blob (replace <SAS_URL> below)
    "c:\\install\\azcopy.exe copy 'https://ramboeckit.blob.core.windows.net/azureimagebuilder/PADT-CountrySwitch.zip?sp=r&st=2025-05-21T11:56:15Z&se=2025-06-07T19:56:15Z&spr=https&sv=2024-11-04&sr=b&sig=1YiADYMqo327e%2B4ALULRnbnwghfWNIrK0SX2y%2FvZAyU%3D' 'c:\\install\\PADT-CountrySwitch.zip' --recursive",
    # Extract the downloaded archive
    "Expand-Archive -Path 'c:\\install\\PADT-CountrySwitch.zip' -DestinationPath 'c:\\install' -Force",
    "C:\\Install\\PADT-CountrySwitch\\Invoke-AppDeployToolkit.ps1 -DeployMode Silent"
  ]
}

  #### //// INSTALLING Microsoft 365 using C2R Custom Configuration - includes multiple languages //// ####

provisioner "powershell" {
  inline = [
    # Download software archive from Blob (replace <SAS_URL> below)
    "c:\\install\\azcopy.exe copy 'https://ramboeckit.blob.core.windows.net/azureimagebuilder/PADT-Greenshot.zip?sp=r&st=2025-05-21T11:22:05Z&se=2025-05-29T19:22:05Z&spr=https&sv=2024-11-04&sr=b&sig=HfpGm%2Fk%2FLjDW9QuO%2FajcOFtdMf%2Bi7jSJtVk87KNkcUc%3D' 'c:\\install\\PADT-Greenshot.zip' --recursive",
    # Extract the downloaded archive
    "Expand-Archive -Path 'c:\\install\\PADT-Greenshot.zip' -DestinationPath 'c:\\install' -Force",
    "C:\\Install\\PADT-Greenshot\\Invoke-AppDeployToolkit.ps1 -DeployMode Silent"
  ]
}


  # Default Provisioners in Powershell using Chocolatey
  provisioner "powershell" {
    script = "scripts/install-software.ps1"
  }

  #### //// Download and installation for VDOT  //// ####
  provisioner "powershell" {
    inline = [
      # Download software archive from Blob (replace <SAS_URL> below)
      "c:\\install\\azcopy.exe copy 'https://ramboeckit.blob.core.windows.net/azureimagebuilder/VDOT.zip?sp=r&st=2025-05-21T14:21:19Z&se=2025-06-06T22:21:19Z&spr=https&sv=2024-11-04&sr=b&sig=%2B6R7lzU%2BIqTS%2FH9TsNONuSVz7WPKJO3h3hfiR9rIrIU%3D' 'c:\\install\\VDOT.zip' --recursive",
      # Extract the downloaded archive
      "Expand-Archive -Path 'c:\\install\\VDOT.zip' -DestinationPath 'c:\\install' -Force",
      "C:\\Install\\VDOT\\Windows_VDOT.ps1 -AcceptEula -Optimizations All"
    ]
  }

  provisioner "powershell" {
    script = "scripts/optimize.ps1"
  }

  #provisioner "powershell" {
  #  script = "scripts/windows-updates.ps1"
  #}

  # Cleanup Sources
  provisioner "powershell" {
    inline = [
      "Remove-Item -Recurse -Force C:\\Install\\*"
    ]
  }
  # Restart the machine
  provisioner "windows-restart" {}

  # Sysprep the machine
  provisioner "powershell" {
    inline = [
      "Write-Host '[FINISHING] Starte Sysprep...'",
      "C:\\Windows\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /shutdown /quiet /mode:vm"
    ]
  }
}
