Write-Host "[INFO] Aktiviere WinRM..."

Enable-PSRemoting -Force -SkipNetworkProfileCheck

# WinRM-Dienst konfigurieren
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/client/auth '@{Basic="true"}'

# Listener hinzufügen (nur wenn nicht vorhanden)
try {
    winrm set winrm/config/listener?Address=*+Transport=HTTP '@{Port="5985"}'
} catch {
    Write-Host "[INFO] Listener existiert bereits oder konnte nicht gesetzt werden."
}

# Firewall-Regeln aktivieren
netsh advfirewall firewall set rule group="Windows Remote Administration" new enable=yes
netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-In)" new enable=yes action=allow remoteip=any

# Dienststart sicherstellen
Set-Service WinRM -StartupType Automatic
Start-Service WinRM

Write-Host "[INFO] WinRM-Konfiguration abgeschlossen."
