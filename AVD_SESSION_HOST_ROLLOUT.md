# 🔄 AVD Session Host Rollout Guide

## Übersicht

Nach einem erfolgreichen Image-Build in der Shared Image Gallery müssen die AVD Session Hosts mit dem neuen Image aktualisiert werden. Dieser Guide beschreibt den Prozess.

---

## 📋 Rollout-Strategien

### 1. **Rolling Update** (EMPFOHLEN für Produktion)
Hosts werden nacheinander aktualisiert mit minimaler Downtime.

**Ablauf:**
1. Host in Drain Mode setzen (keine neuen Sessions)
2. Warten bis alle Sessions beendet sind
3. Alten Host entfernen
4. Neuen Host mit neuem Image erstellen
5. Neuen Host registrieren
6. Nächster Host

**Vorteile:**
- ✅ Minimale Downtime
- ✅ Benutzer können während Update weiterarbeiten
- ✅ Rollback möglich (bei Problemen Stop)
- ✅ Ressourcen-effizient

**Nachteile:**
- ⏰ Zeitaufwändig bei vielen Hosts

---

### 2. **Blue/Green Deployment**
Alle neuen Hosts werden parallel zu den alten erstellt.

**Ablauf:**
1. Alle neuen Hosts erstellen (mit "-new" Suffix)
2. Neue Hosts registrieren
3. Test-Session auf neuem Host durchführen
4. Bei Erfolg: Alte Hosts in Drain Mode
5. Warten auf Session-Ende
6. Alte Hosts entfernen
7. Neue Hosts umbenennen (entferne "-new")

**Vorteile:**
- ✅ Schneller Rollback möglich
- ✅ Ausführliches Testing vor Cut-Over
- ✅ Keine Wartezeit für Session-Ende

**Nachteile:**
- 💰 Doppelte Kosten während Migration
- 🔧 Komplexer

---

## 🚀 Verwendung des PowerShell Scripts

### Vorbereitung

```powershell
# Azure Modules installieren (einmalig)
Install-Module -Name Az.DesktopVirtualization -Force
Install-Module -Name Az.Compute -Force
Install-Module -Name Az.Resources -Force

# Azure Login
Connect-AzAccount
```

---

### Rolling Update (Standard)

```powershell
# Basis-Update mit neuester Image-Version
.\Update-AVDSessionHosts.ps1 `
    -ResourceGroupName "avd-prod-rg" `
    -HostPoolName "hp-prod"

# Spezifische Image-Version
.\Update-AVDSessionHosts.ps1 `
    -ResourceGroupName "avd-prod-rg" `
    -HostPoolName "hp-prod" `
    -ImageVersion "2025.02.15"

# Mit längerer Timeout-Zeit für Sessions
.\Update-AVDSessionHosts.ps1 `
    -ResourceGroupName "avd-prod-rg" `
    -HostPoolName "hp-prod" `
    -SessionWaitTimeout 120

# Dry Run (Simulation ohne Änderungen)
.\Update-AVDSessionHosts.ps1 `
    -ResourceGroupName "avd-prod-rg" `
    -HostPoolName "hp-prod" `
    -DryRun
```

---

### Blue/Green Deployment

```powershell
# Blue/Green mit DryRun zur Planung
.\Update-AVDSessionHosts.ps1 `
    -ResourceGroupName "avd-prod-rg" `
    -HostPoolName "hp-prod" `
    -UpdateStrategy "BlueGreen" `
    -DryRun

# Tatsächlicher Blue/Green Rollout
.\Update-AVDSessionHosts.ps1 `
    -ResourceGroupName "avd-prod-rg" `
    -HostPoolName "hp-prod" `
    -UpdateStrategy "BlueGreen"
```

---

### Erweiterte Optionen

```powershell
# Force-Modus: Update auch bei aktiven Sessions
.\Update-AVDSessionHosts.ps1 `
    -ResourceGroupName "avd-prod-rg" `
    -HostPoolName "hp-prod" `
    -Force

# Erlaube max. 2 aktive Sessions vor Update
.\Update-AVDSessionHosts.ps1 `
    -ResourceGroupName "avd-prod-rg" `
    -HostPoolName "hp-prod" `
    -MaxSessionsBeforeUpdate 2
```

---

## 🏗️ Manuelle Schritte (ohne Script)

Falls Sie den Prozess manuell durchführen möchten:

### 1. Drain Mode aktivieren

```powershell
# Azure Portal:
# AVD > Host Pools > [Ihr Host Pool] > Session Hosts
# > Host auswählen > "Allow new sessions" auf "No" setzen

# PowerShell:
Update-AzWvdSessionHost `
    -ResourceGroupName "avd-prod-rg" `
    -HostPoolName "hp-prod" `
    -Name "avd-host-01.domain.com" `
    -AllowNewSession:$false
```

### 2. Sessions überwachen

```powershell
# Aktive Sessions abrufen
Get-AzWvdUserSession `
    -ResourceGroupName "avd-prod-rg" `
    -HostPoolName "hp-prod" `
    -SessionHostName "avd-host-01.domain.com"
```

### 3. Benutzer benachrichtigen (optional)

```powershell
# Session Message an alle Benutzer
$sessions = Get-AzWvdUserSession -ResourceGroupName "avd-prod-rg" `
    -HostPoolName "hp-prod" `
    -SessionHostName "avd-host-01.domain.com"

foreach ($session in $sessions) {
    Send-AzWvdUserSessionMessage `
        -ResourceGroupName "avd-prod-rg" `
        -HostPoolName "hp-prod" `
        -SessionHostName "avd-host-01.domain.com" `
        -UserSessionId $session.Name `
        -MessageTitle "Wartungsfenster" `
        -MessageBody "Bitte speichern Sie Ihre Arbeit und melden Sie sich in 30 Minuten ab. System-Update wird durchgeführt."
}
```

### 4. Session Host entfernen

```powershell
# Host aus Pool entfernen
Remove-AzWvdSessionHost `
    -ResourceGroupName "avd-prod-rg" `
    -HostPoolName "hp-prod" `
    -Name "avd-host-01.domain.com"

# VM löschen
Remove-AzVM `
    -ResourceGroupName "avd-prod-rg" `
    -Name "avd-host-01" `
    -Force
```

### 5. Neuen Host mit neuem Image erstellen

```powershell
# Image ID aus Shared Image Gallery
$imageId = "/subscriptions/{sub-id}/resourceGroups/avd-prod-rg/providers/Microsoft.Compute/galleries/avd_sig/images/avd-goldenimage/versions/2025.02.15"

# VM erstellen
New-AzVM `
    -ResourceGroupName "avd-prod-rg" `
    -Name "avd-host-01" `
    -Location "westeurope" `
    -ImageId $imageId `
    -Size "Standard_D2s_v3" `
    -VirtualNetworkName "avd-vnet" `
    -SubnetName "avd-subnet" `
    -SecurityGroupName "avd-nsg"
```

### 6. AVD Agent installieren & registrieren

```powershell
# Registration Token generieren
$token = New-AzWvdRegistrationInfo `
    -ResourceGroupName "avd-prod-rg" `
    -HostPoolName "hp-prod" `
    -ExpirationTime (Get-Date).AddHours(4)

# Custom Script Extension auf VM ausführen
$scriptContent = @"
`$RegistrationToken = '$($token.Token)'
Invoke-WebRequest -Uri 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv' -OutFile 'C:\Temp\AVDBootstrapper.exe'
Invoke-WebRequest -Uri 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH' -OutFile 'C:\Temp\AVDAgent.exe'
Start-Process 'C:\Temp\AVDBootstrapper.exe' -ArgumentList '/quiet /norestart' -Wait
Start-Process 'C:\Temp\AVDAgent.exe' -ArgumentList "/quiet /norestart RegistrationToken=`$RegistrationToken" -Wait
"@

Set-AzVMCustomScriptExtension `
    -ResourceGroupName "avd-prod-rg" `
    -VMName "avd-host-01" `
    -Name "InstallAVDAgent" `
    -Run $scriptContent
```

---

## 🔄 Automatisierung mit Azure DevOps Pipeline

### pipeline.yml

```yaml
trigger:
  - main

pool:
  vmImage: 'windows-latest'

stages:
- stage: ImageBuild
  displayName: 'Build AVD Image'
  jobs:
  - job: Packer
    steps:
    - task: PowerShell@2
      displayName: 'Run Packer Build'
      inputs:
        targetType: 'inline'
        script: |
          cd 03-monthly-packer
          packer build avd-monthly-image.pkr.hcl

- stage: RolloutSessionHosts
  displayName: 'Rollout zu Session Hosts'
  dependsOn: ImageBuild
  condition: succeeded()
  jobs:
  - job: RollingUpdate
    steps:
    - task: AzurePowerShell@5
      displayName: 'Update Session Hosts'
      inputs:
        azureSubscription: 'Azure-Service-Connection'
        ScriptType: 'FilePath'
        ScriptPath: '$(System.DefaultWorkingDirectory)/Update-AVDSessionHosts.ps1'
        ScriptArguments: >
          -ResourceGroupName "avd-prod-rg"
          -HostPoolName "hp-prod"
          -ImageVersion "$(Build.BuildNumber)"
        azurePowerShellVersion: 'LatestVersion'
```

---

## 📊 Best Practices

### 1. **Wartungsfenster planen**
- 🕐 Wählen Sie eine Zeit mit wenig Benutzeraktivität
- 📢 Benachrichtigen Sie Benutzer im Voraus
- ⏰ Planen Sie genug Zeit ein (ca. 1-2h für 10 Hosts)

### 2. **Testing vor Rollout**
- ✅ Neues Image in Test-Host Pool testen
- ✅ Anwendungen verifizieren
- ✅ Funktions-Tests durchführen

### 3. **Monitoring während Rollout**
- 📊 Azure Monitor Logs überwachen
- 👀 Session Host Status prüfen
- 🔔 Alerts für Fehler einrichten

### 4. **Rollback-Plan**
- 💾 Vorherige Image-Version notieren
- 📝 Rollback-Procedure dokumentieren
- ⚡ Schnelles Rollback bei kritischen Problemen

### 5. **Dokumentation**
- 📋 Rollout-Ergebnisse dokumentieren
- 🐛 Probleme und Lösungen festhalten
- ✅ Lessons Learned für nächstes Mal

---

## 🔍 Troubleshooting

### Problem: Session Host Status "Unavailable"

**Ursache:** AVD Agent nicht korrekt installiert/registriert

**Lösung:**
```powershell
# Agent Logs prüfen
$vm = Get-AzVM -ResourceGroupName "avd-prod-rg" -Name "avd-host-01"
Invoke-AzVMRunCommand -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name `
    -CommandId 'RunPowerShellScript' `
    -ScriptPath 'Get-Content C:\Windows\Temp\ScriptLog.log'

# Agent neu installieren
# (Script aus Schritt 6 erneut ausführen)
```

---

### Problem: Sessions wollen nicht enden

**Ursache:** Benutzer haben ungespeicherte Arbeit oder sind inaktiv

**Lösung:**
```powershell
# Session Messages senden
Send-AzWvdUserSessionMessage (...)

# Oder: Force-Modus verwenden (VORSICHT!)
.\Update-AVDSessionHosts.ps1 -Force
```

---

### Problem: Neue VM bootet nicht

**Ursache:** Image ist fehlerhaft oder falsche VM-Größe

**Lösung:**
```powershell
# Boot Diagnostics prüfen
$vm = Get-AzVM -ResourceGroupName "avd-prod-rg" -Name "avd-host-01"
Get-AzVMBootDiagnosticsData -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name

# Screenshot ansehen
Get-AzVMBootDiagnosticsData -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name -Windows -LocalPath "C:\Temp"
```

---

### Problem: Registration Token expired

**Ursache:** Token ist nur 4 Stunden gültig

**Lösung:**
```powershell
# Neuen Token generieren
$token = New-AzWvdRegistrationInfo `
    -ResourceGroupName "avd-prod-rg" `
    -HostPoolName "hp-prod" `
    -ExpirationTime (Get-Date).AddHours(4)

# Token in Script verwenden
```

---

## 📅 Rollout-Checkliste

### Vor dem Rollout
- [ ] Neues Image in SIG vorhanden und getestet
- [ ] Wartungsfenster geplant und kommuniziert
- [ ] Backup/Snapshot der aktuellen Hosts (optional)
- [ ] Rollback-Plan dokumentiert
- [ ] Admin-Credentials bereit (Key Vault)
- [ ] Azure PowerShell Module installiert

### Während des Rollouts
- [ ] Script mit -DryRun testen
- [ ] Session Host Monitoring aktiv
- [ ] Erste Host erfolgreich aktualisiert
- [ ] Test-Login auf neuem Host durchgeführt
- [ ] Alle Hosts aktualisiert
- [ ] Keine Fehler in Logs

### Nach dem Rollout
- [ ] Alle Session Hosts Status = "Available"
- [ ] AllowNewSession = $true für alle Hosts
- [ ] Benutzer-Logins funktionieren
- [ ] Anwendungen funktionieren
- [ ] Performance normal
- [ ] Rollout dokumentiert

---

## 🎯 Erfolgsmetriken

| Metrik | Ziel | Messung |
|--------|------|---------|
| Rollout-Zeit | < 2h für 10 Hosts | Azure DevOps Pipeline Duration |
| Downtime pro Host | < 5 Min | Session Monitoring |
| Fehlerrate | 0% | Failed Hosts / Total Hosts |
| Rollback-Rate | < 10% | Rollbacks / Total Rollouts |

---

## 📚 Weitere Ressourcen

- [Azure Virtual Desktop Documentation](https://docs.microsoft.com/azure/virtual-desktop/)
- [AVD Image Management Best Practices](https://docs.microsoft.com/azure/virtual-desktop/set-up-customize-master-image)
- [PowerShell Az.DesktopVirtualization Module](https://docs.microsoft.com/powershell/module/az.desktopvirtualization/)

---

**Erstellt:** 2025-02-07
**Version:** 1.0
**Autor:** Christoph Ramböck
