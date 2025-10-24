# Installationsanleitung - Ramboeck IT Service Configurator

## Voraussetzungen

- WordPress 5.0 oder höher
- PHP 7.4 oder höher
- MySQL 5.6 oder höher
- Aktives WordPress-Theme

## Schritt-für-Schritt-Installation

### 1. Plugin hochladen

#### Option A: FTP/SFTP Upload
1. Laden Sie den kompletten Ordner `ramboeck-it-configurator` auf Ihren Server
2. Platzieren Sie ihn im Verzeichnis: `/wp-content/plugins/`
3. Der Pfad sollte sein: `/wp-content/plugins/ramboeck-it-configurator/`

#### Option B: WordPress-Backend Upload
1. Komprimieren Sie den Ordner `ramboeck-it-configurator` als ZIP-Datei
2. Gehen Sie im WordPress-Admin zu **Plugins** → **Installieren**
3. Klicken Sie auf **Plugin hochladen**
4. Wählen Sie die ZIP-Datei aus und klicken Sie auf **Jetzt installieren**

#### Option C: Git-Clone (für Entwickler)
```bash
cd /pfad/zu/wordpress/wp-content/plugins/
git clone <repository-url> ramboeck-it-configurator
```

### 2. Plugin aktivieren

1. Gehen Sie zu **Plugins** im WordPress-Admin-Menü
2. Suchen Sie **Ramboeck IT Service Configurator** in der Liste
3. Klicken Sie auf **Aktivieren**

Bei der Aktivierung wird automatisch:
- Eine neue Datenbank-Tabelle `wp_ramboeck_leads` erstellt
- Die Plugin-Version in den WordPress-Optionen gespeichert

### 3. Konfigurator-Seite erstellen

1. Gehen Sie zu **Seiten** → **Erstellen**
2. Geben Sie einen Titel ein, z.B.:
   - "Service Konfigurator"
   - "IT-Services konfigurieren"
   - "Angebot erstellen"
3. Fügen Sie im Content-Bereich den Shortcode ein:
   ```
   [ramboeck_configurator]
   ```
4. Klicken Sie auf **Veröffentlichen**

### 4. Seite testen

1. Öffnen Sie die erstellte Seite im Frontend
2. Testen Sie den Konfigurator:
   - Wählen Sie mindestens einen Service
   - Konfigurieren Sie die Details
   - Geben Sie Kontaktdaten ein (verwenden Sie eine Test-E-Mail)
   - Schließen Sie die Anfrage ab

### 5. Lead-Verwaltung prüfen

1. Gehen Sie im WordPress-Admin zu **Konfigurator** (neuer Menüpunkt)
2. Sie sollten Ihren Test-Lead sehen
3. Prüfen Sie, ob die E-Mail-Benachrichtigung angekommen ist

## Konfiguration nach der Installation

### E-Mail-Einstellungen prüfen

Stellen Sie sicher, dass WordPress E-Mails versenden kann:

1. Testen Sie mit einem Plugin wie "WP Mail SMTP" oder "Check Email"
2. Falls nötig, konfigurieren Sie SMTP-Einstellungen

**Empfohlene SMTP-Plugins:**
- WP Mail SMTP
- Easy WP SMTP
- Post SMTP

### Preise anpassen

1. Öffnen Sie die Datei: `/wp-content/plugins/ramboeck-it-configurator/assets/js/configurator.js`
2. Suchen Sie nach `this.pricing = {`
3. Passen Sie die Preise an Ihre Anforderungen an:

```javascript
this.pricing = {
    cloud: { base: 150, perUser: 25 },      // Basis + pro Benutzer
    vdi: { base: 200, perUser: 35 },        // Basis + pro Arbeitsplatz
    monitoring: { base: 100, perDevice: 15 }, // Basis + pro Gerät
    backup: { base: 120, perGB: 2 }         // Basis + pro GB
};
```

4. Speichern Sie die Datei
5. Löschen Sie ggf. den Browser-Cache

### Styling anpassen

Die CSS-Dateien befinden sich unter:
- Frontend: `/assets/css/configurator.css`
- Admin: `/assets/css/admin.css`

**Tipp:** Verwenden Sie die Theme-Farben Ihrer Website für ein einheitliches Design.

### Integration in Ihr Theme

#### Navigation hinzufügen
1. Gehen Sie zu **Design** → **Menüs**
2. Fügen Sie die Konfigurator-Seite Ihrem Hauptmenü hinzu

#### Call-to-Action Button
Fügen Sie auf Ihrer Homepage einen CTA-Button ein:

```html
<a href="/service-konfigurator/" class="btn btn-primary">
    Jetzt IT-Services konfigurieren
</a>
```

#### Widget-Area (optional)
Fügen Sie ein Text-Widget mit dem Shortcode in einer Sidebar ein.

## Erweiterte Konfiguration

### REST API nutzen

Die REST API ist unter folgender URL verfügbar:
```
https://ihre-domain.de/wp-json/ramboeck/v1/leads
```

**Authentifizierung erforderlich:** WordPress-Admin-Berechtigung

### Hooks für Entwickler

Das Plugin bietet folgende WordPress-Hooks:

```php
// Nach dem Speichern eines Leads
do_action('ramboeck_after_lead_saved', $lead_id, $lead_data);

// Vor dem Versenden der E-Mail
apply_filters('ramboeck_email_content', $message, $lead_data);

// Lead-Status geändert
do_action('ramboeck_lead_status_changed', $lead_id, $old_status, $new_status);
```

## DSGVO-Compliance

### Datenschutzerklärung aktualisieren

Fügen Sie folgenden Text zu Ihrer Datenschutzerklärung hinzu:

```
Service Konfigurator

Wenn Sie unseren Service-Konfigurator nutzen, werden folgende Daten erfasst:
- Name
- E-Mail-Adresse
- Firma (optional)
- Telefonnummer (optional)
- Ihre Service-Auswahl und Konfiguration

Diese Daten werden verwendet, um Ihnen ein individuelles Angebot zu erstellen.
Ihre Daten werden nicht an Dritte weitergegeben und können jederzeit gelöscht werden.
```

### Cookie-Banner
Das Plugin setzt keine Cookies. Die Checkbox "Datenschutzerklärung akzeptiert" ist bereits integriert.

## Troubleshooting

### Plugin lässt sich nicht aktivieren

**Problem:** Fehler bei der Aktivierung

**Lösung:**
1. Prüfen Sie die PHP-Version (min. 7.4)
2. Prüfen Sie die WordPress-Version (min. 5.0)
3. Prüfen Sie die Dateiberechtigungen (755 für Ordner, 644 für Dateien)

### Konfigurator wird nicht angezeigt

**Problem:** Shortcode wird als Text angezeigt

**Lösung:**
1. Prüfen Sie, ob das Plugin aktiviert ist
2. Verwenden Sie den Text-Editor, nicht den visuellen Editor
3. Stellen Sie sicher, dass der Shortcode korrekt geschrieben ist: `[ramboeck_configurator]`

### E-Mails kommen nicht an

**Problem:** Keine E-Mail-Benachrichtigungen

**Lösung:**
1. Installieren Sie "WP Mail SMTP" Plugin
2. Konfigurieren Sie SMTP-Einstellungen
3. Testen Sie mit "Check Email" Plugin
4. Prüfen Sie Spam-Ordner

### Styling-Probleme

**Problem:** Layout sieht nicht korrekt aus

**Lösung:**
1. Löschen Sie Browser-Cache
2. Löschen Sie WordPress-Cache (falls Caching-Plugin aktiv)
3. Prüfen Sie auf CSS-Konflikte mit Ihrem Theme
4. Öffnen Sie Browser-Konsole (F12) auf Fehler

### JavaScript-Fehler

**Problem:** Konfigurator funktioniert nicht

**Lösung:**
1. Öffnen Sie Browser-Konsole (F12)
2. Prüfen Sie auf JavaScript-Fehler
3. Stellen Sie sicher, dass jQuery geladen wird
4. Deaktivieren Sie andere Plugins temporär zum Testen

### Datenbank-Fehler

**Problem:** Tabelle nicht gefunden

**Lösung:**
```sql
-- Manuelle Tabellenerstellung
CREATE TABLE IF NOT EXISTS wp_ramboeck_leads (
    id mediumint(9) NOT NULL AUTO_INCREMENT,
    name varchar(255) NOT NULL,
    email varchar(255) NOT NULL,
    company varchar(255) DEFAULT '',
    phone varchar(50) DEFAULT '',
    services longtext NOT NULL,
    configuration longtext NOT NULL,
    estimated_price decimal(10,2) DEFAULT 0,
    status varchar(50) DEFAULT 'new',
    created_at datetime DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY  (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

## Performance-Optimierung

### Caching

Falls Sie ein Caching-Plugin verwenden:

1. **WP Super Cache / W3 Total Cache:**
   - Schließen Sie die Konfigurator-Seite vom Caching aus
   - Oder verwenden Sie Fragment-Caching

2. **Cloudflare:**
   - Erstellen Sie eine Page Rule für die Konfigurator-Seite
   - Setzen Sie Cache Level auf "Bypass"

### CDN-Integration

Falls Sie ein CDN verwenden, stellen Sie sicher, dass die Plugin-Assets korrekt geladen werden.

## Backup

Erstellen Sie regelmäßig Backups:
1. Plugin-Ordner: `/wp-content/plugins/ramboeck-it-configurator/`
2. Datenbank-Tabelle: `wp_ramboeck_leads`

## Updates

### Plugin aktualisieren

1. Erstellen Sie ein Backup
2. Laden Sie die neue Version hoch
3. Die Datenbank wird automatisch aktualisiert (falls nötig)
4. Testen Sie alle Funktionen

## Support-Kontakt

Bei Problemen oder Fragen:
- E-Mail: support@ramboeck-it.com
- Website: https://ramboeck-it.com

## Checkliste nach Installation

- [ ] Plugin aktiviert
- [ ] Konfigurator-Seite erstellt
- [ ] Test-Lead erstellt
- [ ] E-Mail-Benachrichtigung erhalten
- [ ] Lead im Admin-Backend sichtbar
- [ ] Styling passt zum Theme
- [ ] Responsive auf Mobile getestet
- [ ] Datenschutzerklärung aktualisiert
- [ ] Navigation/CTA eingefügt
- [ ] Performance geprüft

---

**Herzlichen Glückwunsch!** Ihr Service Konfigurator ist einsatzbereit.
