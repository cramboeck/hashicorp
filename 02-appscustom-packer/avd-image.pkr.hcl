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
    image_version = "2025.05.24"
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
    # Download software archive from Blob
    # URL mit SAS Token wird aus Variable gelesen (oder überspringen wenn leer)
    "if ('${var.padt_greenshot_url}' -ne '') { c:\\install\\azcopy.exe copy '${var.padt_greenshot_url}' 'c:\\install\\PADT-Greenshot.zip' --recursive }",
    # Extract the downloaded archive
    "if (Test-Path 'c:\\install\\PADT-Greenshot.zip') { Expand-Archive -Path 'c:\\install\\PADT-Greenshot.zip' -DestinationPath 'c:\\install' -Force }",
    "if (Test-Path 'C:\\Install\\PADT-Greenshot\\Invoke-AppDeployToolkit.ps1') { C:\\Install\\PADT-Greenshot\\Invoke-AppDeployToolkit.ps1 -DeployMode Silent }"
  ]
}

  #### //// INSTALLING CountrySwitch using  custom PADT Toolkit Package //// ####
provisioner "powershell" {
  inline = [
    # Download software archive from Blob
    "if ('${var.padt_countryswitch_url}' -ne '') { c:\\install\\azcopy.exe copy '${var.padt_countryswitch_url}' 'c:\\install\\PADT-CountrySwitch.zip' --recursive }",
    # Extract the downloaded archive
    "if (Test-Path 'c:\\install\\PADT-CountrySwitch.zip') { Expand-Archive -Path 'c:\\install\\PADT-CountrySwitch.zip' -DestinationPath 'c:\\install' -Force }",
    "if (Test-Path 'C:\\Install\\PADT-CountrySwitch\\Invoke-AppDeployToolkit.ps1') { C:\\Install\\PADT-CountrySwitch\\Invoke-AppDeployToolkit.ps1 -DeployMode Silent }"
  ]
}

  #### //// INSTALLING Microsoft 365 using C2R Custom Configuration - includes multiple languages //// ####

provisioner "powershell" {
  inline = [
    # Download software archive from Blob
    "if ('${var.padt_microsoft365_url}' -ne '') { c:\\install\\azcopy.exe copy '${var.padt_microsoft365_url}' 'c:\\install\\PADT-Microsoft365.zip' --recursive }",
    # Extract the downloaded archive
    "if (Test-Path 'c:\\install\\PADT-Microsoft365.zip') { Expand-Archive -Path 'c:\\install\\PADT-Microsoft365.zip' -DestinationPath 'c:\\install' -Force }",
    "if (Test-Path 'c:\\install\\PADT-Microsoft365\\Invoke-AppDeployToolkit.ps1') { c:\\install\\PADT-Microsoft365\\Invoke-AppDeployToolkit.ps1 -DeployMode Silent }"
  ]
}

  # Default Provisioners in Powershell using Chocolatey
  provisioner "powershell" {
    script = "scripts/install-software.ps1"
  }

  #### //// Download and installation for VDOT  //// ####
  provisioner "powershell" {
    inline = [
      # Download software archive from Blob
      "if ('${var.vdot_url}' -ne '') { c:\\install\\azcopy.exe copy '${var.vdot_url}' 'c:\\install\\VDOT.zip' --recursive }",
      # Extract the downloaded archive
      "if (Test-Path 'c:\\install\\VDOT.zip') { Expand-Archive -Path 'c:\\install\\VDOT.zip' -DestinationPath 'c:\\install' -Force }",
      "C:\\Install\\VDOT\\Windows_VDOT.ps1 -AcceptEula -Optimizations All"
    ]
  }

  #provisioner "powershell" {
  #  script = "scripts/optimize.ps1"
  #}

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
