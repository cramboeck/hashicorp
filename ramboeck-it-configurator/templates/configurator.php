<?php
/**
 * Template für den interaktiven Service Konfigurator
 * Conversation-Style mit intelligenter Service-Empfehlung
 */

if (!defined('ABSPATH')) {
    exit;
}
?>

<div class="ramboeck-configurator-wrapper" data-theme="<?php echo esc_attr($atts['theme']); ?>">
    <div class="ramboeck-configurator">

        <!-- Dynamische Fortschrittsanzeige -->
        <div class="configurator-progress">
            <div class="progress-bar">
                <div class="progress-bar-fill" style="width: 0%;"></div>
            </div>
            <div class="progress-info">
                <span class="progress-text">Schritt <span id="current-step">0</span> von <span id="total-steps">6</span></span>
                <span class="progress-percentage">0%</span>
            </div>
        </div>

        <!-- SCHRITT 0: Willkommen -->
        <div class="configurator-step active conversation-step" data-step="0">
            <div class="welcome-container">
                <div class="welcome-icon">
                    <svg width="80" height="80" viewBox="0 0 80 80" fill="none">
                        <circle cx="40" cy="40" r="38" stroke="currentColor" stroke-width="2"/>
                        <path d="M40 25V40L50 50" stroke="currentColor" stroke-width="3" stroke-linecap="round"/>
                    </svg>
                </div>
                <h1 class="welcome-title">Willkommen beim IT-Service Konfigurator</h1>
                <p class="welcome-subtitle">In wenigen Minuten zur perfekten IT-Lösung für Ihr Unternehmen</p>

                <div class="welcome-features">
                    <div class="feature-item">
                        <span class="feature-icon">✓</span>
                        <span>Personalisierte Empfehlungen</span>
                    </div>
                    <div class="feature-item">
                        <span class="feature-icon">✓</span>
                        <span>Transparente Preisschätzung</span>
                    </div>
                    <div class="feature-item">
                        <span class="feature-icon">✓</span>
                        <span>Unverbindliches Angebot</span>
                    </div>
                </div>

                <button type="button" class="btn btn-primary btn-large" id="btn-start">
                    Jetzt starten
                    <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor" style="margin-left: 10px;">
                        <path d="M10 5L15 10L10 15M15 10H5"/>
                    </svg>
                </button>
            </div>
        </div>

        <!-- SCHRITT 1: Unternehmensgröße -->
        <div class="configurator-step conversation-step" data-step="1">
            <div class="conversation-container">
                <div class="question-header">
                    <h2 class="conversation-question">Wie groß ist Ihr Unternehmen?</h2>
                    <p class="conversation-subtitle">Damit können wir die Services optimal auf Ihre Bedürfnisse abstimmen</p>
                </div>

                <div class="company-size-selector">
                    <div class="size-cards">
                        <div class="size-card" data-size="small" data-range="1-10">
                            <div class="size-icon">
                                <svg width="50" height="50" viewBox="0 0 50 50" fill="none">
                                    <circle cx="25" cy="15" r="8" stroke="currentColor" stroke-width="2"/>
                                    <path d="M15 35C15 28 18 25 25 25C32 25 35 28 35 35" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                                </svg>
                            </div>
                            <h3>Klein</h3>
                            <p>1-10 Mitarbeiter</p>
                        </div>

                        <div class="size-card" data-size="medium" data-range="11-50">
                            <div class="size-icon">
                                <svg width="50" height="50" viewBox="0 0 50 50" fill="none">
                                    <circle cx="20" cy="15" r="6" stroke="currentColor" stroke-width="2"/>
                                    <circle cx="35" cy="15" r="6" stroke="currentColor" stroke-width="2"/>
                                    <path d="M12 35C12 30 15 28 20 28C25 28 28 30 28 35M28 35C28 30 31 28 35 28C40 28 43 30 43 35" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                                </svg>
                            </div>
                            <h3>Mittel</h3>
                            <p>11-50 Mitarbeiter</p>
                        </div>

                        <div class="size-card" data-size="large" data-range="51-200">
                            <div class="size-icon">
                                <svg width="50" height="50" viewBox="0 0 50 50" fill="none">
                                    <circle cx="15" cy="12" r="5" stroke="currentColor" stroke-width="2"/>
                                    <circle cx="25" cy="12" r="5" stroke="currentColor" stroke-width="2"/>
                                    <circle cx="35" cy="12" r="5" stroke="currentColor" stroke-width="2"/>
                                    <path d="M8 32C8 28 10 26 15 26C20 26 22 28 22 32M18 32C18 28 20 26 25 26C30 26 32 28 32 32M28 32C28 28 30 26 35 26C40 26 42 28 42 32" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                                </svg>
                            </div>
                            <h3>Groß</h3>
                            <p>51-200 Mitarbeiter</p>
                        </div>

                        <div class="size-card" data-size="enterprise" data-range="200+">
                            <div class="size-icon">
                                <svg width="50" height="50" viewBox="0 0 50 50" fill="none">
                                    <rect x="10" y="10" width="30" height="30" rx="2" stroke="currentColor" stroke-width="2"/>
                                    <path d="M15 15H35M15 20H35M15 25H35M15 30H35M15 35H35" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                                </svg>
                            </div>
                            <h3>Enterprise</h3>
                            <p>200+ Mitarbeiter</p>
                        </div>
                    </div>

                    <div class="custom-size-input" style="display: none; margin-top: 30px;">
                        <label for="employee-count">Oder geben Sie die genaue Anzahl ein:</label>
                        <input type="number" id="employee-count" min="1" max="10000" placeholder="z.B. 25">
                    </div>
                </div>
            </div>
        </div>

        <!-- SCHRITT 2: Aktuelle IT-Situation -->
        <div class="configurator-step conversation-step" data-step="2">
            <div class="conversation-container">
                <div class="question-header">
                    <h2 class="conversation-question">Wie ist Ihre aktuelle IT-Infrastruktur aufgebaut?</h2>
                    <p class="conversation-subtitle">Mehrfachauswahl möglich</p>
                </div>

                <div class="checkbox-cards-grid">
                    <div class="checkbox-card" data-value="on-premise">
                        <input type="checkbox" id="infra-onpremise" name="infrastructure[]" value="on-premise">
                        <label for="infra-onpremise">
                            <div class="card-icon">
                                <svg width="40" height="40" viewBox="0 0 40 40" fill="none">
                                    <rect x="8" y="10" width="24" height="20" rx="2" stroke="currentColor" stroke-width="2"/>
                                    <path d="M12 15H28M12 20H28M12 25H28" stroke="currentColor" stroke-width="2"/>
                                </svg>
                            </div>
                            <h4>On-Premise Server</h4>
                            <p>Eigene Hardware vor Ort</p>
                        </label>
                    </div>

                    <div class="checkbox-card" data-value="cloud">
                        <input type="checkbox" id="infra-cloud" name="infrastructure[]" value="cloud">
                        <label for="infra-cloud">
                            <div class="card-icon">
                                <svg width="40" height="40" viewBox="0 0 40 40" fill="none">
                                    <path d="M32 25C34.5 25 36 23 36 21C36 19 34.5 17 32 17C31.9 17 31.8 17 31.7 17.05C31.4 13.2 28.5 10 24 10C20.5 10 17.5 12.5 16.5 16C16.2 15.95 15.8 16 15.5 16C12.5 16 10 18.5 10 21.5C10 24.5 12.5 27 15.5 27H32Z" stroke="currentColor" stroke-width="2"/>
                                </svg>
                            </div>
                            <h4>Cloud (teilweise)</h4>
                            <p>Einige Services in der Cloud</p>
                        </label>
                    </div>

                    <div class="checkbox-card" data-value="hybrid">
                        <input type="checkbox" id="infra-hybrid" name="infrastructure[]" value="hybrid">
                        <label for="infra-hybrid">
                            <div class="card-icon">
                                <svg width="40" height="40" viewBox="0 0 40 40" fill="none">
                                    <rect x="5" y="15" width="13" height="10" rx="1" stroke="currentColor" stroke-width="2"/>
                                    <path d="M30 18C31.5 18 32.5 17 32.5 16C32.5 15 31.5 14 30 14H29.5C29.3 12 27.5 10 25 10C23 10 21.5 11.5 21 13C20.8 13 20.5 13 20.3 13C19 13 18 14 18 15C18 16 19 17 20.3 17H30Z" stroke="currentColor" stroke-width="2"/>
                                    <path d="M18 20H25" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                                </svg>
                            </div>
                            <h4>Hybrid</h4>
                            <p>Mix aus On-Premise und Cloud</p>
                        </label>
                    </div>

                    <div class="checkbox-card" data-value="none">
                        <input type="checkbox" id="infra-none" name="infrastructure[]" value="none">
                        <label for="infra-none">
                            <div class="card-icon">
                                <svg width="40" height="40" viewBox="0 0 40 40" fill="none">
                                    <circle cx="20" cy="20" r="15" stroke="currentColor" stroke-width="2"/>
                                    <path d="M20 12V20M20 28H20.01" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                                </svg>
                            </div>
                            <h4>Keine/Minimal</h4>
                            <p>Aufbau von Grund auf</p>
                        </label>
                    </div>
                </div>
            </div>
        </div>

        <!-- SCHRITT 3: Herausforderungen & Bedürfnisse -->
        <div class="configurator-step conversation-step" data-step="3">
            <div class="conversation-container">
                <div class="question-header">
                    <h2 class="conversation-question">Was sind Ihre größten IT-Herausforderungen?</h2>
                    <p class="conversation-subtitle">Wählen Sie alle zutreffenden Punkte aus</p>
                </div>

                <div class="challenges-grid">
                    <div class="challenge-card" data-challenge="remote-work" data-recommends="vdi,cloud">
                        <input type="checkbox" id="challenge-remote" name="challenges[]" value="remote-work">
                        <label for="challenge-remote">
                            <span class="challenge-emoji">🏠</span>
                            <h4>Remote-Arbeit</h4>
                            <p>Mitarbeiter arbeiten von verschiedenen Standorten</p>
                        </label>
                    </div>

                    <div class="challenge-card" data-challenge="data-security" data-recommends="backup,monitoring">
                        <input type="checkbox" id="challenge-security" name="challenges[]" value="data-security">
                        <label for="challenge-security">
                            <span class="challenge-emoji">🔒</span>
                            <h4>Datensicherheit</h4>
                            <p>Schutz vor Datenverlust und Cyber-Angriffen</p>
                        </label>
                    </div>

                    <div class="challenge-card" data-challenge="scaling" data-recommends="cloud,vdi">
                        <input type="checkbox" id="challenge-scaling" name="challenges[]" value="scaling">
                        <label for="challenge-scaling">
                            <span class="challenge-emoji">📈</span>
                            <h4>Skalierbarkeit</h4>
                            <p>Flexibles Wachstum ohne große Investitionen</p>
                        </label>
                    </div>

                    <div class="challenge-card" data-challenge="downtime" data-recommends="monitoring,cloud">
                        <input type="checkbox" id="challenge-downtime" name="challenges[]" value="downtime">
                        <label for="challenge-downtime">
                            <span class="challenge-emoji">⚡</span>
                            <h4>Ausfallzeiten</h4>
                            <p>Minimierung von System-Downtime</p>
                        </label>
                    </div>

                    <div class="challenge-card" data-challenge="costs" data-recommends="cloud,monitoring">
                        <input type="checkbox" id="challenge-costs" name="challenges[]" value="costs">
                        <label for="challenge-costs">
                            <span class="challenge-emoji">💰</span>
                            <h4>IT-Kosten</h4>
                            <p>Reduzierung und bessere Planbarkeit</p>
                        </label>
                    </div>

                    <div class="challenge-card" data-challenge="complexity" data-recommends="monitoring,cloud">
                        <input type="checkbox" id="challenge-complexity" name="challenges[]" value="complexity">
                        <label for="challenge-complexity">
                            <span class="challenge-emoji">🔧</span>
                            <h4>Komplexität</h4>
                            <p>Vereinfachung der IT-Verwaltung</p>
                        </label>
                    </div>
                </div>
            </div>
        </div>

        <!-- SCHRITT 4: Empfohlene Services mit Smart Recommendations -->
        <div class="configurator-step conversation-step" data-step="4">
            <div class="conversation-container">
                <div class="question-header">
                    <h2 class="conversation-question">Ihre persönlichen Empfehlungen</h2>
                    <p class="conversation-subtitle">Basierend auf Ihren Angaben empfehlen wir folgende Services</p>
                </div>

                <div class="recommendations-notice">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                        <path d="M12 2L15.09 8.26L22 9.27L17 14.14L18.18 21.02L12 17.77L5.82 21.02L7 14.14L2 9.27L8.91 8.26L12 2Z" fill="currentColor"/>
                    </svg>
                    <span>Diese Services passen perfekt zu Ihren Anforderungen</span>
                </div>

                <div class="service-recommendations">
                    <!-- Wird dynamisch von JavaScript gefüllt -->
                </div>

                <div class="additional-services-section">
                    <button type="button" class="btn btn-text" id="show-all-services">
                        <span>Alle Services anzeigen</span>
                        <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
                            <path d="M10 12L6 8H14L10 12Z"/>
                        </svg>
                    </button>
                    <div class="all-services-grid" style="display: none;">
                        <!-- Alle Services -->
                    </div>
                </div>
            </div>
        </div>

        <!-- SCHRITT 5: Interaktive Service-Konfiguration -->
        <div class="configurator-step conversation-step" data-step="5">
            <div class="conversation-container">
                <div class="question-header">
                    <h2 class="conversation-question">Konfigurieren Sie Ihre Services</h2>
                    <p class="conversation-subtitle">Passen Sie die Details an Ihre Bedürfnisse an</p>
                </div>

                <div class="live-price-indicator">
                    <div class="price-label">Geschätzter monatlicher Preis:</div>
                    <div class="price-value">
                        <span class="currency">€</span>
                        <span class="amount" id="live-price">0</span>
                        <span class="period">/Monat</span>
                    </div>
                </div>

                <div id="interactive-configurations">
                    <!-- Wird dynamisch gefüllt -->
                </div>
            </div>
        </div>

        <!-- SCHRITT 6: Kontaktdaten & Lead-Erfassung -->
        <div class="configurator-step conversation-step" data-step="6">
            <div class="conversation-container">
                <div class="question-header">
                    <h2 class="conversation-question">Fast geschafft!</h2>
                    <p class="conversation-subtitle">Wie können wir Sie für Ihr persönliches Angebot erreichen?</p>
                </div>

                <div class="summary-preview">
                    <h3>Ihre Auswahl im Überblick:</h3>
                    <div id="quick-summary"></div>
                </div>

                <form id="contact-form" class="modern-contact-form">
                    <div class="form-grid">
                        <div class="form-group">
                            <label for="contact-name">
                                <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
                                    <path d="M10 2C7.8 2 6 3.8 6 6C6 8.2 7.8 10 10 10C12.2 10 14 8.2 14 6C14 3.8 12.2 2 10 2ZM10 12C6.7 12 2 13.7 2 17V18H18V17C18 13.7 13.3 12 10 12Z"/>
                                </svg>
                                Ihr Name *
                            </label>
                            <input type="text" id="contact-name" name="name" placeholder="Max Mustermann" required>
                        </div>

                        <div class="form-group">
                            <label for="contact-email">
                                <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
                                    <path d="M2 4L10 9L18 4M2 4V16H18V4"/>
                                </svg>
                                E-Mail-Adresse *
                            </label>
                            <input type="email" id="contact-email" name="email" placeholder="max@firma.de" required>
                        </div>

                        <div class="form-group">
                            <label for="contact-company">
                                <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
                                    <path d="M3 18V8H7V18M8 4V18H12V4M13 10V18H17V10"/>
                                </svg>
                                Firmenname
                            </label>
                            <input type="text" id="contact-company" name="company" placeholder="Ihre Firma GmbH">
                        </div>

                        <div class="form-group">
                            <label for="contact-phone">
                                <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
                                    <path d="M3 2C2.5 2 2 2.5 2 3V5C2 12.18 7.82 18 15 18H17C17.5 18 18 17.5 18 17C18 16.5 17.5 16 17 16H15C8.92 16 4 11.08 4 5V3C4 2.5 3.5 2 3 2Z"/>
                                </svg>
                                Telefon
                            </label>
                            <input type="tel" id="contact-phone" name="phone" placeholder="+49 123 456789">
                        </div>
                    </div>

                    <div class="form-group full-width">
                        <label for="contact-message">Gibt es noch etwas, das wir wissen sollten?</label>
                        <textarea id="contact-message" name="message" rows="4" placeholder="z.B. bevorzugter Kontaktzeitpunkt, spezielle Anforderungen..."></textarea>
                    </div>

                    <div class="form-group checkbox-group">
                        <input type="checkbox" id="contact-privacy" name="privacy" required>
                        <label for="contact-privacy">
                            Ich akzeptiere die <a href="/datenschutz" target="_blank">Datenschutzerklärung</a> und stimme der Kontaktaufnahme zu *
                        </label>
                    </div>

                    <div class="final-price-display">
                        <div class="price-summary">
                            <span class="price-label">Ihre geschätzte Investition:</span>
                            <span class="price-amount">€ <span id="final-price">0</span>/Monat</span>
                        </div>
                        <p class="price-disclaimer">* Unverbindliche Schätzung. Individuelles Angebot nach Beratungsgespräch.</p>
                    </div>
                </form>
            </div>
        </div>

        <!-- Navigation -->
        <div class="configurator-navigation">
            <button type="button" class="btn btn-secondary" id="btn-back" style="display: none;">
                <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
                    <path d="M15 10H5M5 10L10 5M5 10L10 15"/>
                </svg>
                Zurück
            </button>
            <button type="button" class="btn btn-primary" id="btn-continue">
                Weiter
                <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
                    <path d="M5 10H15M15 10L10 5M15 10L10 15"/>
                </svg>
            </button>
        </div>

        <!-- Success/Error Messages -->
        <div class="configurator-message" id="configurator-message" style="display: none;">
            <div class="message-content"></div>
        </div>

    </div>
</div>
