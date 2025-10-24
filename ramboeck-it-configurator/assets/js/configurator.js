(function($) {
    'use strict';

    class RamboeckSmartConfigurator {
        constructor() {
            this.currentStep = 0;
            this.totalSteps = 6;

            // User Profil Daten
            this.userProfile = {
                companySize: null,
                employeeCount: 0,
                infrastructure: [],
                challenges: [],
                industry: null
            };

            // Service-Auswahl und Konfiguration
            this.selectedServices = {
                cloud: { selected: false, recommended: false, config: {}, priority: 0 },
                vdi: { selected: false, recommended: false, config: {}, priority: 0 },
                monitoring: { selected: false, recommended: false, config: {}, priority: 0 },
                backup: { selected: false, recommended: false, config: {}, priority: 0 }
            };

            this.contactData = {};

            // Preismodell
            this.pricing = {
                cloud: { base: 150, perUser: 25, smallDiscount: 0.9, largeMultiplier: 1.2 },
                vdi: { base: 200, perUser: 35, performance: { basic: 1, standard: 1.5, premium: 2.5 } },
                monitoring: { base: 100, perDevice: 15, scope: { basic: 1, standard: 1.5, advanced: 2 } },
                backup: { base: 120, perGB: 2, frequency: { daily: 1, hourly: 1.3, realtime: 1.8 } }
            };

            this.init();
        }

        init() {
            this.bindEvents();
            this.updateProgress();
        }

        bindEvents() {
            const self = this;

            // Start Button
            $('#btn-start').on('click', () => this.nextStep());

            // Navigation
            $('#btn-continue').on('click', () => this.nextStep());
            $('#btn-back').on('click', () => this.prevStep());

            // Schritt 1: Company Size Selection
            $('.size-card').on('click', function() {
                $('.size-card').removeClass('selected');
                $(this).addClass('selected');

                const size = $(this).data('size');
                const range = $(this).data('range');

                self.userProfile.companySize = size;

                // Setze automatische Mitarbeiterzahl basierend auf Kategorie
                const ranges = {
                    'small': 5,
                    'medium': 25,
                    'large': 100,
                    'enterprise': 300
                };
                self.userProfile.employeeCount = ranges[size] || 25;
            });

            // Schritt 2: Infrastructure Selection
            $('.checkbox-card input[type="checkbox"]').on('change', function() {
                $(this).closest('.checkbox-card').toggleClass('selected', $(this).is(':checked'));

                const value = $(this).val();
                if ($(this).is(':checked')) {
                    if (!self.userProfile.infrastructure.includes(value)) {
                        self.userProfile.infrastructure.push(value);
                    }
                } else {
                    self.userProfile.infrastructure = self.userProfile.infrastructure.filter(v => v !== value);
                }
            });

            // Schritt 3: Challenges Selection
            $('.challenge-card input[type="checkbox"]').on('change', function() {
                $(this).closest('.challenge-card').toggleClass('selected', $(this).is(':checked'));

                const challenge = $(this).val();
                if ($(this).is(':checked')) {
                    if (!self.userProfile.challenges.includes(challenge)) {
                        self.userProfile.challenges.push(challenge);
                    }
                } else {
                    self.userProfile.challenges = self.userProfile.challenges.filter(c => c !== challenge);
                }
            });

            // Show all services toggle
            $('#show-all-services').on('click', function() {
                $('.all-services-grid').slideToggle();
                $(this).find('svg').toggleClass('rotated');
            });
        }

        nextStep() {
            if (this.validateStep(this.currentStep)) {
                // Spezielle Logik für Schritt 3 -> 4: Generiere Empfehlungen
                if (this.currentStep === 3) {
                    this.generateRecommendations();
                }

                // Spezielle Logik für Schritt 4 -> 5: Bereite Konfiguration vor
                if (this.currentStep === 4) {
                    this.prepareServiceConfiguration();
                }

                // Spezielle Logik für Schritt 5 -> 6: Bereite Summary vor
                if (this.currentStep === 5) {
                    this.prepareFinalSummary();
                }

                if (this.currentStep < this.totalSteps) {
                    this.currentStep++;
                    this.showStep(this.currentStep);
                } else {
                    this.submitConfiguration();
                }
            }
        }

        prevStep() {
            if (this.currentStep > 0) {
                this.currentStep--;
                this.showStep(this.currentStep);
            }
        }

        showStep(step) {
            // Schritte ausblenden/einblenden
            $('.configurator-step').removeClass('active');
            $(`.configurator-step[data-step="${step}"]`).addClass('active');

            // Navigation aktualisieren
            if (step === 0) {
                $('#btn-back').hide();
                $('#btn-continue').hide();
            } else {
                $('#btn-back').show();
                $('#btn-continue').show();
            }

            // Button-Text anpassen
            if (step === this.totalSteps) {
                $('#btn-continue').html(`
                    Angebot anfordern
                    <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
                        <path d="M16 2L8 10L4 6" stroke="currentColor" stroke-width="2" fill="none"/>
                    </svg>
                `);
            } else {
                $('#btn-continue').html(`
                    Weiter
                    <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
                        <path d="M5 10H15M15 10L10 5M15 10L10 15"/>
                    </svg>
                `);
            }

            this.updateProgress();
            this.scrollToTop();
        }

        validateStep(step) {
            switch(step) {
                case 0:
                    return true; // Welcome screen, immer valid

                case 1:
                    if (!this.userProfile.companySize) {
                        this.showMessage('Bitte wählen Sie Ihre Unternehmensgröße aus.', 'error');
                        return false;
                    }
                    break;

                case 2:
                    if (this.userProfile.infrastructure.length === 0) {
                        this.showMessage('Bitte wählen Sie mindestens eine Option aus.', 'error');
                        return false;
                    }
                    break;

                case 3:
                    if (this.userProfile.challenges.length === 0) {
                        this.showMessage('Bitte wählen Sie mindestens eine Herausforderung aus.', 'error');
                        return false;
                    }
                    break;

                case 4:
                    // Prüfe ob mindestens ein Service ausgewählt ist
                    const hasService = Object.values(this.selectedServices).some(s => s.selected);
                    if (!hasService) {
                        this.showMessage('Bitte wählen Sie mindestens einen Service aus.', 'error');
                        return false;
                    }
                    break;

                case 5:
                    // Validiere Service-Konfigurationen
                    let configValid = true;
                    for (const [service, data] of Object.entries(this.selectedServices)) {
                        if (data.selected) {
                            const inputs = $(`#config-${service} input[required], #config-${service} select[required]`);
                            inputs.each(function() {
                                if (!$(this).val()) {
                                    configValid = false;
                                    $(this).addClass('error');
                                } else {
                                    $(this).removeClass('error');
                                }
                            });
                        }
                    }
                    if (!configValid) {
                        this.showMessage('Bitte füllen Sie alle erforderlichen Felder aus.', 'error');
                        return false;
                    }
                    break;

                case 6:
                    // Validiere Kontaktformular
                    const form = $('#contact-form')[0];
                    if (!form.checkValidity()) {
                        form.reportValidity();
                        return false;
                    }
                    this.saveContactData();
                    break;
            }
            return true;
        }

        updateProgress() {
            const progress = ((this.currentStep) / this.totalSteps) * 100;
            $('.progress-bar-fill').css('width', `${progress}%`);
            $('#current-step').text(this.currentStep);
            $('#total-steps').text(this.totalSteps);
            $('.progress-percentage').text(Math.round(progress) + '%');
        }

        generateRecommendations() {
            // Smart Recommendation Engine
            const recommendations = {};

            // Analysiere Herausforderungen und empfehle Services
            $('.challenge-card input:checked').each(function() {
                const card = $(this).closest('.challenge-card');
                const recommends = card.data('recommends');
                if (recommends) {
                    recommends.split(',').forEach(service => {
                        recommendations[service] = (recommendations[service] || 0) + 1;
                    });
                }
            });

            // Setze Prioritäten basierend auf Recommendations
            for (const [service, score] of Object.entries(recommendations)) {
                if (this.selectedServices[service]) {
                    this.selectedServices[service].priority = score;
                    this.selectedServices[service].recommended = true;
                }
            }

            // Zusätzliche Logik basierend auf Unternehmensgröße
            if (this.userProfile.companySize === 'small') {
                this.selectedServices.cloud.priority += 1;
            } else if (this.userProfile.companySize === 'enterprise') {
                this.selectedServices.monitoring.priority += 2;
                this.selectedServices.backup.priority += 2;
            }

            // Infrastruktur-basierte Empfehlungen
            if (this.userProfile.infrastructure.includes('none')) {
                this.selectedServices.cloud.priority += 3;
                this.selectedServices.vdi.priority += 2;
            }
            if (this.userProfile.infrastructure.includes('on-premise')) {
                this.selectedServices.backup.priority += 2;
                this.selectedServices.monitoring.priority += 2;
            }

            // Rendere Empfehlungen
            this.renderRecommendations();
        }

        renderRecommendations() {
            const container = $('.service-recommendations');
            container.empty();

            // Sortiere Services nach Priorität
            const sortedServices = Object.entries(this.selectedServices)
                .sort((a, b) => b[1].priority - a[1].priority);

            const serviceInfo = {
                cloud: {
                    title: 'Cloud Services',
                    icon: `<svg width="60" height="60" viewBox="0 0 60 60" fill="none">
                        <path d="M48 37.5C51.315 37.5 54 34.815 54 31.5C54 28.185 51.315 25.5 48 25.5C47.835 25.5 47.67 25.5075 47.5075 25.5225C47.0925 19.89 42.375 15.5 36.6 15.5C31.98 15.5 27.99 18.375 26.25 22.5C25.755 22.425 25.2525 22.5 24.75 22.5C20.61 22.5 17.25 25.86 17.25 30C17.25 34.14 20.61 37.5 24.75 37.5H48Z" stroke="currentColor" stroke-width="2"/>
                    </svg>`,
                    description: 'Flexible Cloud-Infrastruktur für Skalierbarkeit und Kosteneffizienz',
                    benefits: ['Skalierbar', 'Kosteneffizient', 'Hochverfügbar']
                },
                vdi: {
                    title: 'Virtuelle Arbeitsplätze (VDI)',
                    icon: `<svg width="60" height="60" viewBox="0 0 60 60" fill="none">
                        <rect x="10" y="12" width="40" height="28" rx="2" stroke="currentColor" stroke-width="2"/>
                        <path d="M16 45H44" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                        <path d="M30 40V45" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                    </svg>`,
                    description: 'Sichere Remote-Desktop-Lösungen für flexibles Arbeiten von überall',
                    benefits: ['Remote-Ready', 'Sicher', 'Zentral verwaltet']
                },
                monitoring: {
                    title: '24/7 IT-Monitoring',
                    icon: `<svg width="60" height="60" viewBox="0 0 60 60" fill="none">
                        <circle cx="30" cy="30" r="20" stroke="currentColor" stroke-width="2"/>
                        <path d="M15 30L22 23L28 28L35 20L45 30" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                    </svg>`,
                    description: 'Proaktive Überwachung zur Vermeidung von Ausfällen und Problemen',
                    benefits: ['24/7 Überwachung', 'Früherkennung', 'Schnelle Reaktion']
                },
                backup: {
                    title: 'Backup & Disaster Recovery',
                    icon: `<svg width="60" height="60" viewBox="0 0 60 60" fill="none">
                        <path d="M45 35V45C45 46.6569 43.6569 48 42 48H18C16.3431 48 15 46.6569 15 45V35" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                        <path d="M30 12V35M30 35L22 27M30 35L38 27" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                    </svg>`,
                    description: 'Automatische Datensicherung für maximale Sicherheit und schnelle Wiederherstellung',
                    benefits: ['Automatisch', 'Sicher', 'Schnelle Wiederherstellung']
                }
            };

            sortedServices.forEach(([serviceKey, serviceData]) => {
                const info = serviceInfo[serviceKey];
                const isRecommended = serviceData.priority > 0;
                const isSelected = serviceData.selected;

                const card = $(`
                    <div class="recommendation-card ${isRecommended ? 'recommended' : ''} ${isSelected ? 'selected' : ''}" data-service="${serviceKey}">
                        <div class="recommendation-header">
                            ${isRecommended ? '<span class="recommended-badge">Empfohlen für Sie</span>' : ''}
                            <div class="service-icon">${info.icon}</div>
                        </div>
                        <h3>${info.title}</h3>
                        <p class="service-description">${info.description}</p>
                        <div class="service-benefits">
                            ${info.benefits.map(b => `<span class="benefit-tag">✓ ${b}</span>`).join('')}
                        </div>
                        <button type="button" class="btn ${isSelected ? 'btn-selected' : 'btn-outline'} select-service-btn" data-service="${serviceKey}">
                            ${isSelected ? '✓ Ausgewählt' : 'Auswählen'}
                        </button>
                    </div>
                `);

                container.append(card);
            });

            // Event-Handler für Service-Auswahl
            $('.select-service-btn').on('click', (e) => {
                const btn = $(e.currentTarget);
                const service = btn.data('service');
                const card = btn.closest('.recommendation-card');

                this.selectedServices[service].selected = !this.selectedServices[service].selected;

                if (this.selectedServices[service].selected) {
                    btn.text('✓ Ausgewählt').removeClass('btn-outline').addClass('btn-selected');
                    card.addClass('selected');
                } else {
                    btn.text('Auswählen').removeClass('btn-selected').addClass('btn-outline');
                    card.removeClass('selected');
                }
            });
        }

        prepareServiceConfiguration() {
            const container = $('#interactive-configurations');
            container.empty();

            for (const [service, data] of Object.entries(this.selectedServices)) {
                if (data.selected) {
                    const config = this.generateInteractiveConfig(service);
                    container.append(config);
                }
            }

            // Event-Listener für Live-Preisberechnung
            container.find('input, select').on('change input', () => {
                this.saveServiceConfigurations();
                this.calculateAndUpdatePrice();
            });

            this.calculateAndUpdatePrice();
        }

        generateInteractiveConfig(service) {
            const baseEmployees = this.userProfile.employeeCount;

            const configs = {
                cloud: `
                    <div class="interactive-config-card" id="config-cloud">
                        <div class="config-header">
                            <h3>☁️ Cloud Services Konfiguration</h3>
                            <p class="config-subtitle">Passen Sie die Cloud-Ressourcen an Ihre Bedürfnisse an</p>
                        </div>

                        <div class="config-body">
                            <div class="slider-group">
                                <label>Anzahl der Benutzer: <span class="slider-value" id="cloud-users-value">${baseEmployees}</span></label>
                                <input type="range" name="cloud_users" min="1" max="500" value="${baseEmployees}" class="interactive-slider">
                            </div>

                            <div class="slider-group">
                                <label>Speicher (GB): <span class="slider-value" id="cloud-storage-value">500</span></label>
                                <input type="range" name="cloud_storage" min="100" max="10000" value="500" step="100" class="interactive-slider">
                            </div>

                            <div class="select-group">
                                <label>Cloud-Plattform</label>
                                <div class="radio-cards">
                                    <div class="radio-card">
                                        <input type="radio" id="cloud-azure" name="cloud_type" value="azure" checked>
                                        <label for="cloud-azure">
                                            <strong>Microsoft Azure</strong>
                                            <span>Enterprise-Ready</span>
                                        </label>
                                    </div>
                                    <div class="radio-card">
                                        <input type="radio" id="cloud-aws" name="cloud_type" value="aws">
                                        <label for="cloud-aws">
                                            <strong>Amazon AWS</strong>
                                            <span>Maximale Flexibilität</span>
                                        </label>
                                    </div>
                                    <div class="radio-card">
                                        <input type="radio" id="cloud-hybrid" name="cloud_type" value="hybrid">
                                        <label for="cloud-hybrid">
                                            <strong>Hybrid Cloud</strong>
                                            <span>Best of Both Worlds</span>
                                        </label>
                                    </div>
                                </div>
                            </div>

                            <div class="toggle-group">
                                <label class="toggle-label">
                                    <input type="checkbox" name="cloud_ha" class="toggle-input">
                                    <span class="toggle-switch"></span>
                                    <span class="toggle-text">
                                        <strong>High Availability</strong>
                                        <small>99.99% Verfügbarkeit (+€100/Monat)</small>
                                    </span>
                                </label>
                            </div>
                        </div>
                    </div>
                `,
                vdi: `
                    <div class="interactive-config-card" id="config-vdi">
                        <div class="config-header">
                            <h3>💻 Virtuelle Arbeitsplätze Konfiguration</h3>
                            <p class="config-subtitle">Definieren Sie Ihre VDI-Infrastruktur</p>
                        </div>

                        <div class="config-body">
                            <div class="slider-group">
                                <label>Anzahl der Arbeitsplätze: <span class="slider-value" id="vdi-users-value">${baseEmployees}</span></label>
                                <input type="range" name="vdi_users" min="1" max="500" value="${baseEmployees}" class="interactive-slider">
                            </div>

                            <div class="select-group">
                                <label>Leistungsklasse</label>
                                <div class="radio-cards">
                                    <div class="radio-card">
                                        <input type="radio" id="vdi-basic" name="vdi_performance" value="basic">
                                        <label for="vdi-basic">
                                            <strong>Basic</strong>
                                            <span>2 vCPU, 4GB RAM</span>
                                            <small>Office-Anwendungen</small>
                                        </label>
                                    </div>
                                    <div class="radio-card">
                                        <input type="radio" id="vdi-standard" name="vdi_performance" value="standard" checked>
                                        <label for="vdi-standard">
                                            <strong>Standard</strong>
                                            <span>4 vCPU, 8GB RAM</span>
                                            <small>Business-Anwendungen</small>
                                        </label>
                                    </div>
                                    <div class="radio-card">
                                        <input type="radio" id="vdi-premium" name="vdi_performance" value="premium">
                                        <label for="vdi-premium">
                                            <strong>Premium</strong>
                                            <span>8 vCPU, 16GB RAM</span>
                                            <small>CAD, Video-Bearbeitung</small>
                                        </label>
                                    </div>
                                </div>
                            </div>

                            <div class="toggle-group">
                                <label class="toggle-label">
                                    <input type="checkbox" name="vdi_office" class="toggle-input">
                                    <span class="toggle-switch"></span>
                                    <span class="toggle-text">
                                        <strong>Microsoft Office 365</strong>
                                        <small>Pro Arbeitsplatz (+€12/Monat)</small>
                                    </span>
                                </label>
                            </div>
                        </div>
                    </div>
                `,
                monitoring: `
                    <div class="interactive-config-card" id="config-monitoring">
                        <div class="config-header">
                            <h3>📊 Monitoring Konfiguration</h3>
                            <p class="config-subtitle">Überwachen Sie Ihre IT-Infrastruktur</p>
                        </div>

                        <div class="config-body">
                            <div class="slider-group">
                                <label>Anzahl der Geräte/Server: <span class="slider-value" id="monitoring-devices-value">10</span></label>
                                <input type="range" name="monitoring_devices" min="1" max="500" value="10" class="interactive-slider">
                            </div>

                            <div class="select-group">
                                <label>Monitoring-Umfang</label>
                                <select name="monitoring_scope" class="styled-select">
                                    <option value="basic">Basic - Verfügbarkeit & Uptime</option>
                                    <option value="standard" selected>Standard - Performance & Logs</option>
                                    <option value="advanced">Advanced - Application Performance Monitoring</option>
                                </select>
                            </div>

                            <div class="toggle-group">
                                <label class="toggle-label">
                                    <input type="checkbox" name="monitoring_247" class="toggle-input">
                                    <span class="toggle-switch"></span>
                                    <span class="toggle-text">
                                        <strong>24/7 Bereitschaftsdienst</strong>
                                        <small>Reaktion innerhalb 15 Minuten (+€300/Monat)</small>
                                    </span>
                                </label>
                            </div>

                            <div class="toggle-group">
                                <label class="toggle-label">
                                    <input type="checkbox" name="monitoring_alerts" class="toggle-input" checked>
                                    <span class="toggle-switch"></span>
                                    <span class="toggle-text">
                                        <strong>SMS & E-Mail Alarme</strong>
                                        <small>Sofortige Benachrichtigung bei Problemen</small>
                                    </span>
                                </label>
                            </div>
                        </div>
                    </div>
                `,
                backup: `
                    <div class="interactive-config-card" id="config-backup">
                        <div class="config-header">
                            <h3>💾 Backup & Recovery Konfiguration</h3>
                            <p class="config-subtitle">Sichern Sie Ihre wertvollen Daten</p>
                        </div>

                        <div class="config-body">
                            <div class="slider-group">
                                <label>Backup-Volumen (GB): <span class="slider-value" id="backup-volume-value">1000</span></label>
                                <input type="range" name="backup_volume" min="100" max="50000" value="1000" step="100" class="interactive-slider">
                            </div>

                            <div class="select-group">
                                <label>Backup-Häufigkeit</label>
                                <select name="backup_frequency" class="styled-select">
                                    <option value="daily" selected>Täglich</option>
                                    <option value="hourly">Stündlich</option>
                                    <option value="realtime">Echtzeit (Continuous Data Protection)</option>
                                </select>
                            </div>

                            <div class="select-group">
                                <label>Aufbewahrungsdauer</label>
                                <select name="backup_retention" class="styled-select">
                                    <option value="30" selected>30 Tage</option>
                                    <option value="90">90 Tage</option>
                                    <option value="365">1 Jahr</option>
                                    <option value="2555">7 Jahre (GoBD-konform)</option>
                                </select>
                            </div>

                            <div class="toggle-group">
                                <label class="toggle-label">
                                    <input type="checkbox" name="backup_offsite" class="toggle-input" checked>
                                    <span class="toggle-switch"></span>
                                    <span class="toggle-text">
                                        <strong>Offsite Backup</strong>
                                        <small>Georedundante Speicherung (+€150/Monat)</small>
                                    </span>
                                </label>
                            </div>
                        </div>
                    </div>
                `
            };

            const html = $(configs[service] || '');

            // Slider-Updates
            html.find('.interactive-slider').on('input', function() {
                const value = $(this).val();
                const name = $(this).attr('name');
                $(`#${name.replace('_', '-')}-value`).text(value);
            });

            return html;
        }

        saveServiceConfigurations() {
            for (const [service, data] of Object.entries(this.selectedServices)) {
                if (data.selected) {
                    const config = {};
                    $(`#config-${service} input, #config-${service} select`).each(function() {
                        const name = $(this).attr('name');
                        const value = $(this).is(':checkbox') ? $(this).is(':checked') : $(this).val();
                        config[name] = value;
                    });
                    this.selectedServices[service].config = config;
                }
            }
        }

        calculateAndUpdatePrice() {
            let totalPrice = 0;

            for (const [service, data] of Object.entries(this.selectedServices)) {
                if (data.selected) {
                    const config = data.config;

                    switch(service) {
                        case 'cloud':
                            const cloudUsers = parseInt(config.cloud_users) || 0;
                            let cloudPrice = this.pricing.cloud.base + (cloudUsers * this.pricing.cloud.perUser);
                            if (config.cloud_ha) cloudPrice += 100;
                            if (this.userProfile.companySize === 'small') cloudPrice *= this.pricing.cloud.smallDiscount;
                            totalPrice += cloudPrice;
                            break;

                        case 'vdi':
                            const vdiUsers = parseInt(config.vdi_users) || 0;
                            const perfMultiplier = this.pricing.vdi.performance[config.vdi_performance] || 1;
                            let vdiPrice = this.pricing.vdi.base + (vdiUsers * this.pricing.vdi.perUser * perfMultiplier);
                            if (config.vdi_office) vdiPrice += vdiUsers * 12;
                            totalPrice += vdiPrice;
                            break;

                        case 'monitoring':
                            const devices = parseInt(config.monitoring_devices) || 0;
                            const scopeMultiplier = this.pricing.monitoring.scope[config.monitoring_scope] || 1;
                            let monPrice = this.pricing.monitoring.base + (devices * this.pricing.monitoring.perDevice * scopeMultiplier);
                            if (config.monitoring_247) monPrice += 300;
                            totalPrice += monPrice;
                            break;

                        case 'backup':
                            const volume = parseInt(config.backup_volume) || 0;
                            const freqMultiplier = this.pricing.backup.frequency[config.backup_frequency] || 1;
                            let backupPrice = this.pricing.backup.base + (volume * this.pricing.backup.perGB * freqMultiplier);
                            if (config.backup_offsite) backupPrice += 150;
                            totalPrice += backupPrice;
                            break;
                    }
                }
            }

            $('#live-price').text(Math.round(totalPrice));
            return totalPrice;
        }

        prepareFinalSummary() {
            const summaryContainer = $('#quick-summary');
            summaryContainer.empty();

            let summary = '<ul class="summary-list">';
            for (const [service, data] of Object.entries(this.selectedServices)) {
                if (data.selected) {
                    const serviceName = this.getServiceName(service);
                    summary += `<li><strong>${serviceName}</strong></li>`;
                }
            }
            summary += '</ul>';

            summaryContainer.html(summary);

            const finalPrice = this.calculateAndUpdatePrice();
            $('#final-price').text(Math.round(finalPrice));
        }

        getServiceName(service) {
            const names = {
                cloud: 'Cloud Services',
                vdi: 'Virtuelle Arbeitsplätze',
                monitoring: '24/7 IT-Monitoring',
                backup: 'Backup & Disaster Recovery'
            };
            return names[service] || service;
        }

        saveContactData() {
            this.contactData = {
                name: $('#contact-name').val(),
                email: $('#contact-email').val(),
                company: $('#contact-company').val(),
                phone: $('#contact-phone').val(),
                message: $('#contact-message').val()
            };
        }

        submitConfiguration() {
            const submitData = {
                action: 'ramboeck_save_lead',
                nonce: ramboeckConfig.nonce,
                name: this.contactData.name,
                email: this.contactData.email,
                company: this.contactData.company,
                phone: this.contactData.phone,
                services: this.selectedServices,
                configuration: this.selectedServices,
                user_profile: this.userProfile,
                estimated_price: this.calculateAndUpdatePrice()
            };

            $('#btn-continue').prop('disabled', true).text('Wird gesendet...');

            $.ajax({
                url: ramboeckConfig.ajaxUrl,
                type: 'POST',
                data: submitData,
                success: (response) => {
                    if (response.success) {
                        this.showSuccessScreen(response.data.message);
                    } else {
                        this.showMessage(response.data.message, 'error');
                        $('#btn-continue').prop('disabled', false).html(`
                            Angebot anfordern
                            <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
                                <path d="M16 2L8 10L4 6" stroke="currentColor" stroke-width="2" fill="none"/>
                            </svg>
                        `);
                    }
                },
                error: () => {
                    this.showMessage('Ein Fehler ist aufgetreten. Bitte versuchen Sie es später erneut.', 'error');
                    $('#btn-continue').prop('disabled', false).html(`
                        Angebot anfordern
                        <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
                            <path d="M16 2L8 10L4 6" stroke="currentColor" stroke-width="2" fill="none"/>
                        </svg>
                    `);
                }
            });
        }

        showSuccessScreen(message) {
            $('.configurator-step').removeClass('active');
            $('.configurator-navigation').hide();
            $('.configurator-progress').hide();

            const successHTML = `
                <div class="success-screen active">
                    <div class="success-icon">
                        <svg width="100" height="100" viewBox="0 0 100 100" fill="none">
                            <circle cx="50" cy="50" r="48" stroke="#28a745" stroke-width="3"/>
                            <path d="M30 50L45 65L70 35" stroke="#28a745" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                    </div>
                    <h2>Vielen Dank für Ihre Anfrage!</h2>
                    <p>${message}</p>
                    <p>Wir haben Ihnen eine Bestätigung per E-Mail gesendet und werden uns in Kürze bei Ihnen melden.</p>
                    <div class="success-details">
                        <h3>Was passiert als Nächstes?</h3>
                        <ul>
                            <li>✓ Sie erhalten eine Bestätigungs-E-Mail</li>
                            <li>✓ Unser Team prüft Ihre Anforderungen</li>
                            <li>✓ Wir erstellen ein individuelles Angebot</li>
                            <li>✓ Sie erhalten Ihr Angebot innerhalb von 24 Stunden</li>
                        </ul>
                    </div>
                </div>
            `;

            $('.ramboeck-configurator').append(successHTML);
        }

        showMessage(message, type) {
            const messageEl = $('#configurator-message');
            messageEl.removeClass('success error').addClass(type);
            messageEl.find('.message-content').text(message);
            messageEl.slideDown();

            setTimeout(() => {
                messageEl.slideUp();
            }, 5000);
        }

        scrollToTop() {
            $('html, body').animate({
                scrollTop: $('.ramboeck-configurator').offset().top - 100
            }, 500);
        }
    }

    // Initialisiere Konfigurator
    $(document).ready(function() {
        if ($('.ramboeck-configurator').length) {
            new RamboeckSmartConfigurator();
        }
    });

})(jQuery);
