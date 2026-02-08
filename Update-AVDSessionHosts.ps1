#Requires -Version 5.1
#Requires -Modules Az.DesktopVirtualization, Az.Compute, Az.Resources

<#
.SYNOPSIS
    AVD Session Host Rolling Update Script

.DESCRIPTION
    Führt ein Rolling Update der AVD Session Hosts mit neuem Image aus der Shared Image Gallery durch.
    Wenn keine Session Hosts vorhanden sind, wird automatisch ein Initial Deployment durchgeführt.

    Funktionen:
    - Initial Deployment: Erstellt neue Session Hosts wenn keine vorhanden sind
    - Rolling Update: Drain Mode, Session-Beendigung abwarten, Host ersetzen
    - Blue/Green Deployment: Neuen Host erstellen, dann alten entfernen
    - DryRun Modus: Simulation ohne Änderungen

.PARAMETER ResourceGroupName
    Name der Resource Group mit dem AVD Host Pool

.PARAMETER HostPoolName
    Name des AVD Host Pools

.PARAMETER ImageVersion
    Version des Images aus der Shared Image Gallery (z.B. "2025.02.15")
    Wenn nicht angegeben, wird die neueste Version verwendet

.PARAMETER MaxSessionsBeforeUpdate
    Maximale Anzahl aktiver Sessions bevor Update startet (default: 0 = keine aktiven Sessions)

.PARAMETER SessionWaitTimeout
    Maximale Wartezeit in Minuten für Session-Beendigung (default: 60)

.PARAMETER UpdateStrategy
    Update-Strategie: "RollingUpdate" (Standard) oder "BlueGreen"

.PARAMETER DryRun
    Simulation ohne tatsächliche Änderungen

.PARAMETER InitialHostCount
    Anzahl der Session Hosts bei Initial Deployment (default: 1)

.PARAMETER VMSize
    VM-Größe für neue Session Hosts (default: Standard_D4s_v5)

.PARAMETER SessionHostPrefix
    Namens-Präfix für neue Session Hosts (default: avd-host)

.PARAMETER SubnetId
    Vollständige Subnet Resource ID. Wenn nicht angegeben, wird automatisch ein VNet gesucht.

.PARAMETER VNetName
    Name des VNets (optional, wird mit VNetResourceGroupName und SubnetName kombiniert)

.PARAMETER VNetResourceGroupName
    Resource Group des VNets (optional, falls VNet in anderer RG als Host Pool liegt)

.PARAMETER SubnetName
    Name des Subnets im VNet (default: default)

.EXAMPLE
    .\Update-AVDSessionHosts.ps1 -ResourceGroupName "avd-rg" -HostPoolName "hp-prod" -ImageVersion "2025.02.15"

.EXAMPLE
    .\Update-AVDSessionHosts.ps1 -ResourceGroupName "avd-rg" -HostPoolName "hp-prod" -UpdateStrategy "BlueGreen" -DryRun

.EXAMPLE
    # Initial Deployment - 2 neue Session Hosts erstellen wenn keine vorhanden
    .\Update-AVDSessionHosts.ps1 -ResourceGroupName "avd-rg" -HostPoolName "hp-prod" -InitialHostCount 2 -VMSize "Standard_D4s_v5"

.NOTES
    Author: Christoph Ramböck
    Version: 1.0
    Created: 2025-02-07
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$HostPoolName,

    [Parameter(Mandatory = $false)]
    [string]$ImageVersion = "latest",

    [Parameter(Mandatory = $false)]
    [int]$MaxSessionsBeforeUpdate = 0,

    [Parameter(Mandatory = $false)]
    [int]$SessionWaitTimeout = 60,

    [Parameter(Mandatory = $false)]
    [ValidateSet("RollingUpdate", "BlueGreen")]
    [string]$UpdateStrategy = "RollingUpdate",

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [int]$InitialHostCount = 1,

    [Parameter(Mandatory = $false)]
    [string]$VMSize = "Standard_D4s_v5",

    [Parameter(Mandatory = $false)]
    [string]$SessionHostPrefix = "avd-host",

    [Parameter(Mandatory = $false)]
    [string]$SubnetId = "",

    [Parameter(Mandatory = $false)]
    [string]$VNetName = "",

    [Parameter(Mandatory = $false)]
    [string]$VNetResourceGroupName = "",

    [Parameter(Mandatory = $false)]
    [string]$SubnetName = "default"
)

#region Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        default   { "White" }
    }

    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage -ForegroundColor $color

    # Optional: Log to file
    $logFile = "AVD-SessionHost-Update-$(Get-Date -Format 'yyyyMMdd').log"
    $logMessage | Out-File -FilePath $logFile -Append -Encoding UTF8
}

function Get-AVDSessionHostSessions {
    param(
        [string]$ResourceGroupName,
        [string]$HostPoolName,
        [string]$SessionHostName
    )

    try {
        $sessions = Get-AzWvdUserSession -ResourceGroupName $ResourceGroupName `
            -HostPoolName $HostPoolName `
            -SessionHostName $SessionHostName -ErrorAction SilentlyContinue

        return $sessions
    }
    catch {
        Write-Log "Fehler beim Abrufen der Sessions für $SessionHostName : $_" -Level ERROR
        return @()
    }
}

function Set-AVDSessionHostDrainMode {
    param(
        [string]$ResourceGroupName,
        [string]$HostPoolName,
        [string]$SessionHostName,
        [bool]$AllowNewSession
    )

    try {
        Write-Log "Setze Drain Mode für $SessionHostName : AllowNewSession = $AllowNewSession" -Level INFO

        if (-not $DryRun) {
            Update-AzWvdSessionHost -ResourceGroupName $ResourceGroupName `
                -HostPoolName $HostPoolName `
                -Name $SessionHostName `
                -AllowNewSession:$AllowNewSession | Out-Null
        }

        return $true
    }
    catch {
        Write-Log "Fehler beim Setzen des Drain Mode: $_" -Level ERROR
        return $false
    }
}

function Wait-ForSessionsToEnd {
    param(
        [string]$ResourceGroupName,
        [string]$HostPoolName,
        [string]$SessionHostName,
        [int]$TimeoutMinutes,
        [int]$MaxSessions = 0
    )

    Write-Log "Warte auf Beendigung der Sessions auf $SessionHostName (Timeout: $TimeoutMinutes Minuten)" -Level INFO

    $startTime = Get-Date
    $timeout = $startTime.AddMinutes($TimeoutMinutes)

    while ((Get-Date) -lt $timeout) {
        $sessions = Get-AVDSessionHostSessions -ResourceGroupName $ResourceGroupName `
            -HostPoolName $HostPoolName `
            -SessionHostName $SessionHostName

        $activeSessionCount = ($sessions | Where-Object { $_.SessionState -eq "Active" }).Count

        Write-Log "Aktive Sessions auf ${SessionHostName}: $activeSessionCount" -Level INFO

        if ($activeSessionCount -le $MaxSessions) {
            Write-Log "Bedingung erfüllt: $activeSessionCount <= $MaxSessions Sessions" -Level SUCCESS
            return $true
        }

        Write-Log "Warte weitere 60 Sekunden..." -Level INFO
        Start-Sleep -Seconds 60
    }

    Write-Log "Timeout erreicht! Es sind noch $activeSessionCount Sessions aktiv." -Level WARNING

    if ($Force) {
        Write-Log "Force-Modus aktiviert: Fahre trotz aktiver Sessions fort" -Level WARNING
        return $true
    }

    return $false
}

function Get-LatestImageVersion {
    param(
        [string]$ResourceGroupName,
        [string]$GalleryName,
        [string]$ImageDefinitionName
    )

    try {
        $versions = Get-AzGalleryImageVersion -ResourceGroupName $ResourceGroupName `
            -GalleryName $GalleryName `
            -GalleryImageDefinitionName $ImageDefinitionName `
            | Sort-Object -Property Name -Descending

        if ($versions) {
            return $versions[0].Name
        }

        return $null
    }
    catch {
        Write-Log "Fehler beim Abrufen der Image-Versionen: $_" -Level ERROR
        return $null
    }
}

function New-AVDSessionHostVM {
    param(
        [string]$ResourceGroupName,
        [string]$Location,
        [string]$VMName,
        [string]$ImageId,
        [string]$SubnetId,
        [string]$VMSize = "Standard_D2s_v3",
        [PSCredential]$AdminCredential
    )

    try {
        Write-Log "Erstelle neue VM: $VMName" -Level INFO

        if ($DryRun) {
            Write-Log "[DRY RUN] Würde VM $VMName erstellen mit Image: $ImageId" -Level INFO
            return $true
        }

        # NIC erstellen
        $nicName = "$VMName-nic"
        $nic = New-AzNetworkInterface -Name $nicName `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -SubnetId $SubnetId

        # VM Konfiguration mit Trusted Launch (erforderlich für SIG Images mit trusted_launch_enabled)
        $vmConfig = New-AzVMConfig -VMName $VMName -VMSize $VMSize -SecurityType "TrustedLaunch" `
            | Set-AzVMOperatingSystem -Windows -ComputerName $VMName -Credential $AdminCredential `
            | Set-AzVMSourceImage -Id $ImageId `
            | Add-AzVMNetworkInterface -Id $nic.Id
        Set-AzVMSecurityProfile -VM $vmConfig -SecurityType "TrustedLaunch"
        Set-AzVMUefi -VM $vmConfig -EnableSecureBoot $true -EnableVtpm $true

        # VM erstellen
        $vm = New-AzVM -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -VM $vmConfig `
            -DisableBginfoExtension

        if ($vm) {
            Write-Log "VM $VMName erfolgreich erstellt" -Level SUCCESS
            return $true
        }

        return $false
    }
    catch {
        Write-Log "Fehler beim Erstellen der VM ${VMName}: $_" -Level ERROR
        return $false
    }
}

function Register-AVDSessionHost {
    param(
        [string]$ResourceGroupName,
        [string]$HostPoolName,
        [string]$VMName,
        [string]$RegistrationToken
    )

    try {
        Write-Log "Registriere $VMName im Host Pool $HostPoolName" -Level INFO

        if ($DryRun) {
            Write-Log "[DRY RUN] Würde $VMName registrieren" -Level INFO
            return $true
        }

        # AVD Agent Installation via Custom Script Extension
        $scriptContent = @"
`$RegistrationToken = '$RegistrationToken'
`$BootstrapperUrl = 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv'
`$AgentUrl = 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH'

# Download und Installation
Invoke-WebRequest -Uri `$BootstrapperUrl -OutFile 'C:\Temp\AVDBootstrapper.exe'
Invoke-WebRequest -Uri `$AgentUrl -OutFile 'C:\Temp\AVDAgent.exe'

Start-Process -FilePath 'C:\Temp\AVDBootstrapper.exe' -ArgumentList "/quiet /norestart" -Wait
Start-Process -FilePath 'C:\Temp\AVDAgent.exe' -ArgumentList "/quiet /norestart RegistrationToken=`$RegistrationToken" -Wait
"@

        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName

        Set-AzVMCustomScriptExtension -ResourceGroupName $ResourceGroupName `
            -VMName $VMName `
            -Name "InstallAVDAgent" `
            -FileUri @() `
            -Run $scriptContent `
            -Location $vm.Location | Out-Null

        Write-Log "Session Host $VMName erfolgreich registriert" -Level SUCCESS
        return $true
    }
    catch {
        Write-Log "Fehler beim Registrieren von ${VMName}: $_" -Level ERROR
        return $false
    }
}

function Remove-AVDSessionHost {
    param(
        [string]$ResourceGroupName,
        [string]$HostPoolName,
        [string]$SessionHostName,
        [string]$VMName
    )

    try {
        Write-Log "Entferne Session Host $SessionHostName und VM $VMName" -Level INFO

        if ($DryRun) {
            Write-Log "[DRY RUN] Würde $SessionHostName entfernen" -Level INFO
            return $true
        }

        # Session Host aus Host Pool entfernen
        Remove-AzWvdSessionHost -ResourceGroupName $ResourceGroupName `
            -HostPoolName $HostPoolName `
            -Name $SessionHostName `
            -Force | Out-Null

        # VM entfernen
        Remove-AzVM -ResourceGroupName $ResourceGroupName `
            -Name $VMName `
            -Force | Out-Null

        # NIC entfernen
        $nic = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName | Where-Object { $_.Name -like "$VMName*" }
        if ($nic) {
            Remove-AzNetworkInterface -ResourceGroupName $ResourceGroupName `
                -Name $nic.Name `
                -Force | Out-Null
        }

        # OS Disk entfernen
        $disk = Get-AzDisk -ResourceGroupName $ResourceGroupName | Where-Object { $_.Name -like "$VMName*" }
        if ($disk) {
            Remove-AzDisk -ResourceGroupName $ResourceGroupName `
                -DiskName $disk.Name `
                -Force | Out-Null
        }

        Write-Log "Session Host $SessionHostName erfolgreich entfernt" -Level SUCCESS
        return $true
    }
    catch {
        Write-Log "Fehler beim Entfernen von ${SessionHostName}: $_" -Level ERROR
        return $false
    }
}

#endregion

#region Main Script

try {
    Write-Log "===== AVD Session Host Update startet =====" -Level INFO
    Write-Log "Resource Group: $ResourceGroupName" -Level INFO
    Write-Log "Host Pool: $HostPoolName" -Level INFO
    Write-Log "Image Version: $ImageVersion" -Level INFO
    Write-Log "Update Strategy: $UpdateStrategy" -Level INFO

    if ($DryRun) {
        Write-Log "DRY RUN MODE: Keine tatsächlichen Änderungen werden vorgenommen" -Level WARNING
    }

    # Azure Login prüfen
    $context = Get-AzContext
    if (-not $context) {
        Write-Log "Nicht bei Azure angemeldet. Führe az login aus..." -Level WARNING
        Connect-AzAccount
    }

    Write-Log "Angemeldet als: $($context.Account.Id)" -Level INFO

    # Host Pool abrufen
    Write-Log "Rufe Host Pool Informationen ab..." -Level INFO
    $hostPool = Get-AzWvdHostPool -ResourceGroupName $ResourceGroupName -Name $HostPoolName

    if (-not $hostPool) {
        throw "Host Pool $HostPoolName nicht gefunden in Resource Group $ResourceGroupName"
    }

    Write-Log "Host Pool gefunden: $($hostPool.Name)" -Level SUCCESS
    Write-Log "  - Type: $($hostPool.HostPoolType)" -Level INFO
    Write-Log "  - Load Balancer Type: $($hostPool.LoadBalancerType)" -Level INFO
    Write-Log "  - Max Session Limit: $($hostPool.MaxSessionLimit)" -Level INFO

    # Session Hosts abrufen
    Write-Log "Rufe Session Hosts ab..." -Level INFO
    $sessionHosts = Get-AzWvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName

    $isInitialDeployment = (-not $sessionHosts -or $sessionHosts.Count -eq 0)

    if ($isInitialDeployment) {
        Write-Log "Keine Session Hosts gefunden im Host Pool $HostPoolName" -Level WARNING
        Write-Log "Starte Initial Deployment: $InitialHostCount neue Session Host(s) werden erstellt" -Level INFO
    } else {
        Write-Log "Gefundene Session Hosts: $($sessionHosts.Count)" -Level INFO

        foreach ($sessionHost in $sessionHosts) {
            $hostName = $sessionHost.Name.Split('/')[-1]
            $sessions = Get-AVDSessionHostSessions -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -SessionHostName $hostName
            Write-Log "  - $hostName : Status=$($sessionHost.Status), Sessions=$($sessions.Count), AllowNewSession=$($sessionHost.AllowNewSession)" -Level INFO
        }
    }

    # Image-Version ermitteln
    if ($ImageVersion -eq "latest") {
        Write-Log "Ermittle neueste Image-Version aus Shared Image Gallery..." -Level INFO

        # Annahme: SIG Details aus Host Pool Tags oder Konfiguration
        $sigResourceGroup = $ResourceGroupName  # Kann angepasst werden
        $sigName = "avd_sig"  # Kann angepasst werden
        $imageDefinition = "avd-goldenimage"  # Kann angepasst werden

        $ImageVersion = Get-LatestImageVersion -ResourceGroupName $sigResourceGroup `
            -GalleryName $sigName `
            -ImageDefinitionName $imageDefinition

        if (-not $ImageVersion) {
            throw "Keine Image-Version gefunden in Shared Image Gallery"
        }

        Write-Log "Neueste Image-Version: $ImageVersion" -Level SUCCESS
    }

    # Image ID zusammenbauen
    $subscriptionId = $context.Subscription.Id
    $imageId = "/subscriptions/$subscriptionId/resourceGroups/$sigResourceGroup/providers/Microsoft.Compute/galleries/$sigName/images/$imageDefinition/versions/$ImageVersion"

    Write-Log "Image ID: $imageId" -Level INFO

    # ===== Initial Deployment (wenn keine Session Hosts vorhanden) =====
    if ($isInitialDeployment) {
        Write-Log "===== Initial Deployment startet =====" -Level INFO

        # Netzwerk-Konfiguration ermitteln
        if (-not $SubnetId) {
            if ($VNetName) {
                # VNet Resource Group bestimmen (falls angegeben, sonst gleiche wie Host Pool)
                $vnetRG = if ($VNetResourceGroupName) { $VNetResourceGroupName } else { $ResourceGroupName }
                Write-Log "Ermittle Subnet ID aus VNet '$VNetName' in RG '$vnetRG', Subnet '$SubnetName'..." -Level INFO
                $vnet = Get-AzVirtualNetwork -ResourceGroupName $vnetRG -Name $VNetName -ErrorAction SilentlyContinue
                if ($vnet) {
                    $subnet = $vnet.Subnets | Where-Object { $_.Name -eq $SubnetName }
                    if ($subnet) {
                        $SubnetId = $subnet.Id
                    }
                }
            }

            # Fallback 1: VNet in der Host Pool Resource Group suchen
            if (-not $SubnetId) {
                Write-Log "Suche VNet in Resource Group $ResourceGroupName..." -Level INFO
                $vnets = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
                if ($vnets) {
                    $vnet = $vnets | Select-Object -First 1
                    $subnet = $vnet.Subnets | Select-Object -First 1
                    $SubnetId = $subnet.Id
                    Write-Log "Verwende VNet '$($vnet.Name)', Subnet '$($subnet.Name)'" -Level INFO
                }
            }

            # Fallback 2: VNet in der gesamten Subscription suchen
            if (-not $SubnetId) {
                Write-Log "Suche VNet in gesamter Subscription..." -Level INFO
                $vnets = Get-AzVirtualNetwork -ErrorAction SilentlyContinue
                if ($vnets) {
                    $vnet = $vnets | Select-Object -First 1
                    $subnet = $vnet.Subnets | Select-Object -First 1
                    $SubnetId = $subnet.Id
                    Write-Log "Verwende VNet '$($vnet.Name)' aus RG '$($vnet.ResourceGroupName)', Subnet '$($subnet.Name)'" -Level INFO
                } else {
                    throw "Kein VNet gefunden in der Subscription. Bitte SubnetId angeben."
                }
            }
        }

        Write-Log "Subnet ID: $SubnetId" -Level INFO

        $location = $hostPool.Location
        Write-Log "Location: $location" -Level INFO

        # Admin Credentials
        Write-Log "Admin Credentials werden benötigt für neue VM(s)..." -Level WARNING
        Write-Log "In Produktion: Verwenden Sie Azure Key Vault!" -Level WARNING

        if (-not $DryRun) {
            $adminUser = "azureadmin"
            $adminPassword = Read-Host "Passwort für Admin-Account" -AsSecureString
            $adminCredential = New-Object System.Management.Automation.PSCredential ($adminUser, $adminPassword)
        }

        # Registration Token generieren
        if (-not $DryRun) {
            $tokenExpiration = (Get-Date).AddHours(4)
            $registrationInfo = New-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroupName `
                -HostPoolName $HostPoolName `
                -ExpirationTime $tokenExpiration
            $registrationToken = $registrationInfo.Token
            Write-Log "Registration Token generiert (gültig bis $tokenExpiration)" -Level SUCCESS
        }

        for ($i = 1; $i -le $InitialHostCount; $i++) {
            $newVMName = "$SessionHostPrefix-$('{0:D2}' -f $i)"
            Write-Log "===== Erstelle Session Host $i/$InitialHostCount : $newVMName =====" -Level INFO

            if ($DryRun) {
                Write-Log "[DRY RUN] Würde VM '$newVMName' erstellen (Size: $VMSize, Image: $imageId)" -Level INFO
                Write-Log "[DRY RUN] Würde VM '$newVMName' im Host Pool registrieren" -Level INFO
                continue
            }

            # VM erstellen
            $vmCreated = New-AVDSessionHostVM -ResourceGroupName $ResourceGroupName `
                -Location $location `
                -VMName $newVMName `
                -ImageId $imageId `
                -SubnetId $SubnetId `
                -VMSize $VMSize `
                -AdminCredential $adminCredential

            if (-not $vmCreated) {
                Write-Log "VM-Erstellung für $newVMName fehlgeschlagen!" -Level ERROR
                continue
            }

            # Session Host registrieren
            $registered = Register-AVDSessionHost -ResourceGroupName $ResourceGroupName `
                -HostPoolName $HostPoolName `
                -VMName $newVMName `
                -RegistrationToken $registrationToken

            if ($registered) {
                Write-Log "Session Host $newVMName erfolgreich erstellt und registriert" -Level SUCCESS
            } else {
                Write-Log "Registrierung von $newVMName fehlgeschlagen" -Level ERROR
            }

            # Kurze Pause zwischen Hosts
            if ($i -lt $InitialHostCount) {
                Write-Log "Warte 30 Sekunden vor nächstem Host..." -Level INFO
                Start-Sleep -Seconds 30
            }
        }

        Write-Log "===== Initial Deployment abgeschlossen =====" -Level SUCCESS

        # Finale Session Host Liste anzeigen
        Write-Log "Aktuelle Session Hosts nach Initial Deployment:" -Level INFO
        $updatedHosts = Get-AzWvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName

        if ($updatedHosts) {
            foreach ($sessionHost in $updatedHosts) {
                $hostName = $sessionHost.Name.Split('/')[-1]
                Write-Log "  - $hostName : Status=$($sessionHost.Status), AllowNewSession=$($sessionHost.AllowNewSession)" -Level INFO
            }
        } else {
            Write-Log "  (Hosts werden noch registriert, bitte warten und erneut prüfen)" -Level WARNING
        }

        # Script beenden - kein Rolling Update nötig
        return
    }

    # ===== Rolling Update (wenn Session Hosts vorhanden) =====
    Write-Log "Starte Rolling Update..." -Level INFO

    $totalHosts = $sessionHosts.Count
    $currentHost = 0

    foreach ($sessionHost in $sessionHosts) {
        $currentHost++
        $hostName = $sessionHost.Name.Split('/')[-1]
        $vmName = $hostName.Split('.')[0]  # Entferne Domain-Suffix

        Write-Log "===== Update Session Host $currentHost/$totalHosts : $hostName =====" -Level INFO

        # 1. Drain Mode aktivieren
        Write-Log "Schritt 1: Aktiviere Drain Mode" -Level INFO
        $drainSuccess = Set-AVDSessionHostDrainMode -ResourceGroupName $ResourceGroupName `
            -HostPoolName $HostPoolName `
            -SessionHostName $hostName `
            -AllowNewSession $false

        if (-not $drainSuccess) {
            Write-Log "Drain Mode konnte nicht aktiviert werden. Überspringe diesen Host." -Level WARNING
            continue
        }

        # 2. Warte auf Session-Beendigung
        Write-Log "Schritt 2: Warte auf Session-Beendigung" -Level INFO
        $sessionsEnded = Wait-ForSessionsToEnd -ResourceGroupName $ResourceGroupName `
            -HostPoolName $HostPoolName `
            -SessionHostName $hostName `
            -TimeoutMinutes $SessionWaitTimeout `
            -MaxSessions $MaxSessionsBeforeUpdate

        if (-not $sessionsEnded -and -not $Force) {
            Write-Log "Timeout beim Warten auf Sessions. Überspringe diesen Host." -Level WARNING

            # Drain Mode deaktivieren
            Set-AVDSessionHostDrainMode -ResourceGroupName $ResourceGroupName `
                -HostPoolName $HostPoolName `
                -SessionHostName $hostName `
                -AllowNewSession $true

            continue
        }

        # 3. Neuen Session Host erstellen
        Write-Log "Schritt 3: Erstelle neuen Session Host" -Level INFO

        # VM Details vom alten Host abrufen
        $oldVM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName -ErrorAction SilentlyContinue

        if ($oldVM) {
            $location = $oldVM.Location
            $vmSize = $oldVM.HardwareProfile.VmSize
            $oldNic = Get-AzNetworkInterface -ResourceId $oldVM.NetworkProfile.NetworkInterfaces[0].Id
            $subnetId = $oldNic.IpConfigurations[0].Subnet.Id
        } else {
            Write-Log "VM $vmName nicht gefunden. Verwende Standardwerte." -Level WARNING
            $location = $hostPool.Location
            $vmSize = "Standard_D2s_v3"
            $subnetId = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/virtualNetworks/avd-vnet/subnets/default"
        }

        # Neue VM Name (mit -new Suffix für Blue/Green, oder gleicher Name für Rolling)
        if ($UpdateStrategy -eq "BlueGreen") {
            $newVMName = "$vmName-new"
        } else {
            $newVMName = $vmName

            # Bei Rolling Update: Alten Host zuerst entfernen
            Write-Log "Entferne alten Session Host vor Erstellung des neuen..." -Level INFO
            Remove-AVDSessionHost -ResourceGroupName $ResourceGroupName `
                -HostPoolName $HostPoolName `
                -SessionHostName $hostName `
                -VMName $vmName
        }

        # Admin Credential (sollte aus Key Vault kommen in Produktion)
        Write-Log "Admin Credentials werden benötigt für neue VM..." -Level WARNING
        Write-Log "In Produktion: Verwenden Sie Azure Key Vault!" -Level WARNING

        if (-not $DryRun) {
            # Hier sollte Key Vault Integration sein
            # $adminCredential = Get-AzKeyVaultSecret -VaultName "your-keyvault" -Name "admin-credential"

            # Für Demo: Manuell eingeben (NICHT FÜR PRODUKTION!)
            $adminUser = "azureadmin"
            $adminPassword = Read-Host "Passwort für Admin-Account" -AsSecureString
            $adminCredential = New-Object System.Management.Automation.PSCredential ($adminUser, $adminPassword)
        }

        # Neue VM erstellen
        if (-not $DryRun) {
            $vmCreated = New-AVDSessionHostVM -ResourceGroupName $ResourceGroupName `
                -Location $location `
                -VMName $newVMName `
                -ImageId $imageId `
                -SubnetId $subnetId `
                -VMSize $vmSize `
                -AdminCredential $adminCredential

            if (-not $vmCreated) {
                Write-Log "VM-Erstellung fehlgeschlagen. Überspringe diesen Host." -Level ERROR
                continue
            }
        }

        # 4. Session Host registrieren
        Write-Log "Schritt 4: Registriere Session Host im Host Pool" -Level INFO

        # Registration Token generieren
        if (-not $DryRun) {
            $tokenExpiration = (Get-Date).AddHours(4)
            $registrationInfo = New-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroupName `
                -HostPoolName $HostPoolName `
                -ExpirationTime $tokenExpiration

            $registrationToken = $registrationInfo.Token

            $registered = Register-AVDSessionHost -ResourceGroupName $ResourceGroupName `
                -HostPoolName $HostPoolName `
                -VMName $newVMName `
                -RegistrationToken $registrationToken

            if (-not $registered) {
                Write-Log "Registrierung fehlgeschlagen" -Level ERROR
            }
        }

        # 5. Bei Blue/Green: Alten Host jetzt entfernen
        if ($UpdateStrategy -eq "BlueGreen" -and -not $DryRun) {
            Write-Log "Schritt 5 (Blue/Green): Entferne alten Session Host" -Level INFO

            Start-Sleep -Seconds 30  # Kurze Pause damit neuer Host verfügbar ist

            Remove-AVDSessionHost -ResourceGroupName $ResourceGroupName `
                -HostPoolName $HostPoolName `
                -SessionHostName $hostName `
                -VMName $vmName
        }

        Write-Log "Update für $hostName abgeschlossen" -Level SUCCESS
        Write-Log "" -Level INFO

        # Pause zwischen Hosts (nur bei mehreren Hosts)
        if ($currentHost -lt $totalHosts) {
            Write-Log "Warte 60 Sekunden vor nächstem Host..." -Level INFO
            Start-Sleep -Seconds 60
        }
    }

    Write-Log "===== Rolling Update erfolgreich abgeschlossen =====" -Level SUCCESS

    # Finale Session Host Liste
    Write-Log "Aktuelle Session Hosts nach Update:" -Level INFO
    $updatedHosts = Get-AzWvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName

    foreach ($sessionHost in $updatedHosts) {
        $hostName = $sessionHost.Name.Split('/')[-1]
        Write-Log "  - $hostName : Status=$($sessionHost.Status), AllowNewSession=$($sessionHost.AllowNewSession)" -Level INFO
    }
}
catch {
    Write-Log "FEHLER beim Rolling Update: $_" -Level ERROR
    Write-Log $_.ScriptStackTrace -Level ERROR
    exit 1
}
finally {
    Write-Log "Script beendet: $(Get-Date)" -Level INFO
}

#endregion
