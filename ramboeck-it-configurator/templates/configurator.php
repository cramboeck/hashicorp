<?php
/**
 * Template für den Service Konfigurator
 */

if (!defined('ABSPATH')) {
    exit;
}
?>

<div class="ramboeck-configurator-wrapper" data-theme="<?php echo esc_attr($atts['theme']); ?>">
    <div class="ramboeck-configurator">

        <!-- Fortschrittsanzeige -->
        <div class="configurator-progress">
            <div class="progress-steps">
                <div class="progress-step active" data-step="1">
                    <span class="step-number">1</span>
                    <span class="step-label">Services</span>
                </div>
                <div class="progress-step" data-step="2">
                    <span class="step-number">2</span>
                    <span class="step-label">Konfiguration</span>
                </div>
                <div class="progress-step" data-step="3">
                    <span class="step-number">3</span>
                    <span class="step-label">Kontakt</span>
                </div>
                <div class="progress-step" data-step="4">
                    <span class="step-number">4</span>
                    <span class="step-label">Zusammenfassung</span>
                </div>
            </div>
            <div class="progress-bar">
                <div class="progress-bar-fill" style="width: 25%;"></div>
            </div>
        </div>

        <!-- Schritt 1: Service-Auswahl -->
        <div class="configurator-step active" data-step="1">
            <h2>Wählen Sie Ihre Services</h2>
            <p class="step-description">Welche IT-Services interessieren Sie?</p>

            <div class="service-grid">
                <div class="service-card" data-service="cloud">
                    <div class="service-icon">
                        <svg width="60" height="60" viewBox="0 0 60 60" fill="none">
                            <path d="M48 37.5C51.315 37.5 54 34.815 54 31.5C54 28.185 51.315 25.5 48 25.5C47.835 25.5 47.67 25.5075 47.5075 25.5225C47.0925 19.89 42.375 15.5 36.6 15.5C31.98 15.5 27.99 18.375 26.25 22.5C25.755 22.425 25.2525 22.5 24.75 22.5C20.61 22.5 17.25 25.86 17.25 30C17.25 34.14 20.61 37.5 24.75 37.5H48Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                    </div>
                    <h3>Cloud Services</h3>
                    <p>Flexible Cloud-Lösungen für Ihre Infrastruktur</p>
                    <div class="service-checkbox">
                        <input type="checkbox" id="service-cloud" name="services[]" value="cloud">
                        <label for="service-cloud">Auswählen</label>
                    </div>
                </div>

                <div class="service-card" data-service="vdi">
                    <div class="service-icon">
                        <svg width="60" height="60" viewBox="0 0 60 60" fill="none">
                            <rect x="10" y="12" width="40" height="28" rx="2" stroke="currentColor" stroke-width="2"/>
                            <path d="M16 45H44" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                            <path d="M30 40V45" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                        </svg>
                    </div>
                    <h3>Virtuelle Arbeitsplätze</h3>
                    <p>Sichere VDI-Lösungen für flexible Arbeit</p>
                    <div class="service-checkbox">
                        <input type="checkbox" id="service-vdi" name="services[]" value="vdi">
                        <label for="service-vdi">Auswählen</label>
                    </div>
                </div>

                <div class="service-card" data-service="monitoring">
                    <div class="service-icon">
                        <svg width="60" height="60" viewBox="0 0 60 60" fill="none">
                            <circle cx="30" cy="30" r="20" stroke="currentColor" stroke-width="2"/>
                            <path d="M15 30L22 23L28 28L35 20L45 30" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                    </div>
                    <h3>Monitoring</h3>
                    <p>24/7 Überwachung Ihrer IT-Infrastruktur</p>
                    <div class="service-checkbox">
                        <input type="checkbox" id="service-monitoring" name="services[]" value="monitoring">
                        <label for="service-monitoring">Auswählen</label>
                    </div>
                </div>

                <div class="service-card" data-service="backup">
                    <div class="service-icon">
                        <svg width="60" height="60" viewBox="0 0 60 60" fill="none">
                            <path d="M45 35V45C45 46.6569 43.6569 48 42 48H18C16.3431 48 15 46.6569 15 45V35" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                            <path d="M30 12V35M30 35L22 27M30 35L38 27" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                    </div>
                    <h3>Backup & Recovery</h3>
                    <p>Zuverlässige Datensicherung und Wiederherstellung</p>
                    <div class="service-checkbox">
                        <input type="checkbox" id="service-backup" name="services[]" value="backup">
                        <label for="service-backup">Auswählen</label>
                    </div>
                </div>
            </div>
        </div>

        <!-- Schritt 2: Konfiguration -->
        <div class="configurator-step" data-step="2">
            <h2>Konfigurieren Sie Ihre Services</h2>
            <p class="step-description">Passen Sie die Services an Ihre Anforderungen an</p>

            <div id="service-configurations">
                <!-- Dynamisch gefüllt durch JavaScript -->
            </div>
        </div>

        <!-- Schritt 3: Kontaktdaten -->
        <div class="configurator-step" data-step="3">
            <h2>Ihre Kontaktdaten</h2>
            <p class="step-description">Damit wir Ihnen ein individuelles Angebot erstellen können</p>

            <form id="contact-form" class="contact-form">
                <div class="form-row">
                    <div class="form-group">
                        <label for="contact-name">Name *</label>
                        <input type="text" id="contact-name" name="name" required>
                    </div>
                    <div class="form-group">
                        <label for="contact-email">E-Mail *</label>
                        <input type="email" id="contact-email" name="email" required>
                    </div>
                </div>

                <div class="form-row">
                    <div class="form-group">
                        <label for="contact-company">Firma</label>
                        <input type="text" id="contact-company" name="company">
                    </div>
                    <div class="form-group">
                        <label for="contact-phone">Telefon</label>
                        <input type="tel" id="contact-phone" name="phone">
                    </div>
                </div>

                <div class="form-group">
                    <label for="contact-message">Nachricht (optional)</label>
                    <textarea id="contact-message" name="message" rows="4"></textarea>
                </div>

                <div class="form-group checkbox-group">
                    <input type="checkbox" id="contact-privacy" name="privacy" required>
                    <label for="contact-privacy">Ich akzeptiere die Datenschutzerklärung *</label>
                </div>
            </form>
        </div>

        <!-- Schritt 4: Zusammenfassung -->
        <div class="configurator-step" data-step="4">
            <h2>Zusammenfassung Ihrer Konfiguration</h2>
            <p class="step-description">Bitte überprüfen Sie Ihre Auswahl</p>

            <div class="summary-container">
                <div class="summary-services">
                    <h3>Ausgewählte Services</h3>
                    <div id="summary-services-list"></div>
                </div>

                <div class="summary-price">
                    <h3>Geschätzter Preis</h3>
                    <div class="price-display">
                        <span class="price-label">Ab</span>
                        <span class="price-amount" id="total-price">0</span>
                        <span class="price-currency">€/Monat</span>
                    </div>
                    <p class="price-note">* Unverbindliche Preisschätzung. Finales Angebot nach persönlicher Beratung.</p>
                </div>
            </div>

            <div class="summary-actions">
                <button type="button" class="btn btn-secondary" id="btn-edit">Bearbeiten</button>
                <button type="button" class="btn btn-primary" id="btn-submit">Angebot anfordern</button>
            </div>
        </div>

        <!-- Navigation Buttons -->
        <div class="configurator-navigation">
            <button type="button" class="btn btn-secondary" id="btn-prev" style="display: none;">
                Zurück
            </button>
            <button type="button" class="btn btn-primary" id="btn-next">
                Weiter
            </button>
        </div>

        <!-- Success/Error Messages -->
        <div class="configurator-message" id="configurator-message" style="display: none;">
            <div class="message-content"></div>
        </div>

    </div>
</div>
