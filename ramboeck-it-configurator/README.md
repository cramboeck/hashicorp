# Ramboeck IT Service Configurator

Ein professionelles WordPress-Plugin für ramboeck-it.com, das als interaktiver Lead-Magnet für IT-Services dient.

## Beschreibung

Der Ramboeck IT Service Configurator ist ein modernes, benutzerfreundliches WordPress-Plugin, das potenziellen Kunden ermöglicht, ihre IT-Service-Anforderungen interaktiv zu konfigurieren. Das Plugin dient als effektiver Lead-Magnet für folgende Services:

- **Cloud Services** - Flexible Cloud-Lösungen (Azure, AWS, Hybrid)
- **Virtuelle Arbeitsplätze (VDI)** - Sichere Remote-Desktop-Lösungen
- **Monitoring** - 24/7 IT-Infrastruktur-Überwachung
- **Backup & Recovery** - Zuverlässige Datensicherung

## Features

### Für Besucher
- ✅ Interaktiver 4-Schritt-Konfigurator
- ✅ Intuitive Service-Auswahl mit visuellen Karten
- ✅ Detaillierte Konfigurationsmöglichkeiten für jeden Service
- ✅ Echtzeit-Preisberechnung
- ✅ Responsive Design für alle Geräte
- ✅ DSGVO-konforme Lead-Erfassung
- ✅ Automatische E-Mail-Benachrichtigungen

### Für Administratoren
- ✅ Übersichtliche Lead-Verwaltung im WordPress-Backend
- ✅ Status-Tracking (Neu, Kontaktiert, Angebot gesendet, etc.)
- ✅ Detaillierte Lead-Ansicht mit allen Konfigurationen
- ✅ Preisschätzungen für jede Anfrage
- ✅ Statistik-Dashboard
- ✅ REST API für externe Integrationen

## Installation

### Manuell
1. Laden Sie den Plugin-Ordner in das Verzeichnis `/wp-content/plugins/` hoch
2. Aktivieren Sie das Plugin über das WordPress-Plugin-Menü
3. Das Plugin erstellt automatisch die benötigte Datenbank-Tabelle

### Via Git
```bash
cd wp-content/plugins/
git clone <repository-url> ramboeck-it-configurator
```

## Verwendung

### Shortcode einbinden
Fügen Sie den Shortcode auf einer beliebigen Seite oder in einem Beitrag ein:

```
[ramboeck_configurator]
```

Optional mit Theme-Parameter:
```
[ramboeck_configurator theme="dark"]
```

### Beispiel-Seite erstellen
1. Gehen Sie zu **Seiten** → **Erstellen**
2. Titel: "Service Konfigurator" oder "Angebot erstellen"
3. Fügen Sie den Shortcode `[ramboeck_configurator]` ein
4. Veröffentlichen Sie die Seite

## Konfiguration

### Preisgestaltung anpassen
Die Preisberechnung kann in der Datei `assets/js/configurator.js` angepasst werden:

```javascript
this.pricing = {
    cloud: { base: 150, perUser: 25 },
    vdi: { base: 200, perUser: 35 },
    monitoring: { base: 100, perDevice: 15 },
    backup: { base: 120, perGB: 2 }
};
```

### E-Mail-Benachrichtigungen
E-Mails werden automatisch gesendet an:
- **Administrator**: Neue Lead-Benachrichtigung mit allen Details
- **Kunde**: Bestätigungs-E-Mail der Anfrage

Die E-Mail-Templates können in der Datei `ramboeck-it-configurator.php` in der Methode `send_notification_email()` angepasst werden.

## Lead-Verwaltung

### Admin-Interface
Nach der Plugin-Aktivierung finden Sie im WordPress-Admin-Menü den neuen Menüpunkt **"Konfigurator"**.

Hier können Sie:
- Alle eingegangenen Leads einsehen
- Lead-Status aktualisieren
- Detailansicht mit vollständiger Konfiguration
- Leads löschen
- Statistiken einsehen

### Lead-Status
- **Neu** (new) - Frisch eingegangene Anfrage
- **Kontaktiert** (contacted) - Kunde wurde kontaktiert
- **Angebot gesendet** (proposal_sent) - Angebot wurde erstellt und versendet
- **Konvertiert** (converted) - Kunde hat zugesagt
- **Abgelehnt** (rejected) - Kunde hat abgelehnt

## REST API

Das Plugin bietet eine REST API für externe Integrationen:

### Endpoints

**GET Leads**
```
GET /wp-json/ramboeck/v1/leads
```
Authentifizierung: WordPress-Admin-Berechtigung erforderlich

## Datenbank-Struktur

Das Plugin erstellt folgende Tabelle:

```sql
wp_ramboeck_leads
- id (INT)
- name (VARCHAR 255)
- email (VARCHAR 255)
- company (VARCHAR 255)
- phone (VARCHAR 50)
- services (LONGTEXT JSON)
- configuration (LONGTEXT JSON)
- estimated_price (DECIMAL)
- status (VARCHAR 50)
- created_at (DATETIME)
```

## Anpassungen

### Styling
Das Plugin verwendet moderne CSS mit CSS Grid und Flexbox. Alle Styles befinden sich in:
- `assets/css/configurator.css` - Frontend-Styles
- `assets/css/admin.css` - Admin-Backend-Styles

### JavaScript
Die gesamte Konfigurator-Logik ist objektorientiert in `assets/js/configurator.js` implementiert.

### Neue Services hinzufügen
1. Service in `templates/configurator.php` hinzufügen
2. Konfigurations-Template in `assets/js/configurator.js` → `generateServiceConfig()` hinzufügen
3. Preislogik in `calculatePrice()` ergänzen

## Browser-Kompatibilität

- ✅ Chrome (letzte 2 Versionen)
- ✅ Firefox (letzte 2 Versionen)
- ✅ Safari (letzte 2 Versionen)
- ✅ Edge (letzte 2 Versionen)
- ✅ Mobile Browser (iOS Safari, Chrome Mobile)

## Sicherheit

- ✅ Nonce-Validierung für alle AJAX-Requests
- ✅ Input-Sanitization und Validierung
- ✅ SQL-Injection-Schutz durch WordPress $wpdb
- ✅ XSS-Schutz durch esc_html/esc_attr
- ✅ CSRF-Schutz
- ✅ Capability-Checks für Admin-Funktionen

## Performance

- Optimierte Datenbankabfragen
- Minimales JavaScript (keine externe Bibliotheken außer jQuery)
- CSS-only Animationen
- Lazy-Loading für Admin-Details
- Gecachte Assets

## Support & Updates

### Changelog

#### Version 1.0.0 (2024-10-24)
- Initiales Release
- 4-Schritt-Konfigurator
- Lead-Management-System
- E-Mail-Benachrichtigungen
- REST API
- Responsive Design

### Geplante Features
- [ ] Export von Leads als CSV/Excel
- [ ] PDF-Generierung der Konfiguration
- [ ] Integration mit CRM-Systemen (HubSpot, Salesforce)
- [ ] Mehrsprachigkeit (WPML-kompatibel)
- [ ] Analytics-Dashboard mit Konversions-Tracking
- [ ] A/B-Testing-Funktionalität

## Entwicklung

### Verzeichnisstruktur
```
ramboeck-it-configurator/
├── admin/
│   └── admin-page.php
├── assets/
│   ├── css/
│   │   ├── admin.css
│   │   └── configurator.css
│   └── js/
│       ├── admin.js
│       └── configurator.js
├── includes/
├── templates/
│   └── configurator.php
├── ramboeck-it-configurator.php
└── README.md
```

### Beitragen
Dieses Plugin wurde speziell für ramboeck-it.com entwickelt. Für Änderungswünsche oder Bug-Reports kontaktieren Sie bitte das Entwicklungsteam.

## Lizenz

GPL v2 or later

## Autor

**Ramboeck IT**
- Website: https://ramboeck-it.com
- Entwickelt mit Claude Code

## Credits

- Icons: Custom SVG Icons
- Framework: WordPress Plugin API
- JavaScript: Vanilla JS mit jQuery
- Styling: Modern CSS mit CSS Grid & Flexbox

---

**Hinweis**: Dieses Plugin sammelt und speichert Benutzerdaten. Stellen Sie sicher, dass Ihre Datenschutzerklärung entsprechend aktualisiert wird und den DSGVO-Anforderungen entspricht.
