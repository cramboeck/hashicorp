$log = "C:\InstallLogs\install-office.log"
$officeTemp = "$env:TEMP\OfficeInstall"

New-Item -ItemType Directory -Path $officeTemp -Force | Out-Null
Set-Location $officeTemp

# 1. ODT-Tool herunterladen
Invoke-WebRequest -Uri "https://aka.ms/OfficeDeploymentTool" -OutFile "$officeTemp\odt.exe" -UseBasicParsing

# 2. Entpacken
Start-Process -FilePath "$officeTemp\odt.exe" -ArgumentList "/quiet /extract:$officeTemp" -Wait

# 3. Erstelle XML-Konfiguration
$xml = @"
<Configuration>
  <Add OfficeClientEdition="64" Channel="MonthlyEnterprise">
    <Product ID="O365ProPlusRetail">
      <Language ID="de-de" />
      <Language ID="en-us" />
      <ExcludeApp ID="OneDrive" />
    </Product>
  </Add>
  <Display Level="None" AcceptEULA="TRUE" />
  <Property Name="SharedComputerLicensing" Value="1" />
</Configuration>
"@
$xmlPath = "$officeTemp\config.xml"
$xml | Out-File -FilePath $xmlPath -Encoding UTF8

# 4. Office installieren
Start-Process -FilePath "$officeTemp\setup.exe" -ArgumentList "/configure $xmlPath" -Wait

Add-Content -Path $log -Value "✅ Office-Installation abgeschlossen: $(Get-Date)"
