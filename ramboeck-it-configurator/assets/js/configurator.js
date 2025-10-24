(function($) {
    'use strict';

    class RamboeckConfigurator {
        constructor() {
            this.currentStep = 1;
            this.totalSteps = 4;
            this.selectedServices = {
                cloud: { selected: false, config: {} },
                vdi: { selected: false, config: {} },
                monitoring: { selected: false, config: {} },
                backup: { selected: false, config: {} }
            };
            this.contactData = {};
            this.pricing = {
                cloud: { base: 150, perUser: 25 },
                vdi: { base: 200, perUser: 35 },
                monitoring: { base: 100, perDevice: 15 },
                backup: { base: 120, perGB: 2 }
            };

            this.init();
        }

        init() {
            this.bindEvents();
            this.updateProgress();
        }

        bindEvents() {
            const self = this;

            // Service-Karten auswählen
            $('.service-card').on('click', function(e) {
                if (!$(e.target).is('input')) {
                    const checkbox = $(this).find('input[type="checkbox"]');
                    checkbox.prop('checked', !checkbox.prop('checked')).trigger('change');
                }
            });

            // Service-Checkbox
            $('input[name="services[]"]').on('change', function() {
                const service = $(this).val();
                const isChecked = $(this).is(':checked');

                self.selectedServices[service].selected = isChecked;
                $(this).closest('.service-card').toggleClass('selected', isChecked);

                self.updateServiceConfigurations();
            });

            // Navigation
            $('#btn-next').on('click', () => this.nextStep());
            $('#btn-prev').on('click', () => this.prevStep());
            $('#btn-submit').on('click', () => this.submitConfiguration());
            $('#btn-edit').on('click', () => this.goToStep(1));

            // Fortschrittsschritte klickbar machen
            $('.progress-step').on('click', function() {
                const step = parseInt($(this).data('step'));
                if (step < self.currentStep) {
                    self.goToStep(step);
                }
            });
        }

        nextStep() {
            if (this.validateStep(this.currentStep)) {
                if (this.currentStep < this.totalSteps) {
                    this.currentStep++;
                    this.showStep(this.currentStep);
                }
            }
        }

        prevStep() {
            if (this.currentStep > 1) {
                this.currentStep--;
                this.showStep(this.currentStep);
            }
        }

        goToStep(step) {
            if (step >= 1 && step <= this.totalSteps) {
                this.currentStep = step;
                this.showStep(this.currentStep);
            }
        }

        showStep(step) {
            // Schritte ausblenden/einblenden
            $('.configurator-step').removeClass('active');
            $(`.configurator-step[data-step="${step}"]`).addClass('active');

            // Navigation aktualisieren
            if (step === 1) {
                $('#btn-prev').hide();
            } else {
                $('#btn-prev').show();
            }

            if (step === this.totalSteps) {
                $('#btn-next').hide();
                this.updateSummary();
            } else {
                $('#btn-next').show();
            }

            // Spezielle Aktionen für bestimmte Schritte
            if (step === 2) {
                this.updateServiceConfigurations();
            }

            this.updateProgress();
            this.scrollToTop();
        }

        validateStep(step) {
            switch(step) {
                case 1:
                    const hasService = Object.values(this.selectedServices).some(s => s.selected);
                    if (!hasService) {
                        this.showMessage('Bitte wählen Sie mindestens einen Service aus.', 'error');
                        return false;
                    }
                    break;

                case 2:
                    // Validierung der Service-Konfigurationen
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

                case 3:
                    // Kontaktformular validieren
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
            const progress = (this.currentStep / this.totalSteps) * 100;
            $('.progress-bar-fill').css('width', `${progress}%`);

            $('.progress-step').each((index, el) => {
                const stepNum = index + 1;
                if (stepNum < this.currentStep) {
                    $(el).addClass('completed').removeClass('active');
                } else if (stepNum === this.currentStep) {
                    $(el).addClass('active').removeClass('completed');
                } else {
                    $(el).removeClass('active completed');
                }
            });
        }

        updateServiceConfigurations() {
            const container = $('#service-configurations');
            container.empty();

            for (const [service, data] of Object.entries(this.selectedServices)) {
                if (data.selected) {
                    container.append(this.generateServiceConfig(service));
                }
            }

            // Event-Listener für Konfigurationsänderungen
            container.find('input, select').on('change', () => {
                this.saveServiceConfigurations();
                this.calculatePrice();
            });

            this.calculatePrice();
        }

        generateServiceConfig(service) {
            const configs = {
                cloud: `
                    <div class="service-config-card" id="config-cloud">
                        <h3>Cloud Services Konfiguration</h3>
                        <div class="form-group">
                            <label>Cloud-Typ</label>
                            <select name="cloud_type" required>
                                <option value="">Bitte wählen</option>
                                <option value="azure">Microsoft Azure</option>
                                <option value="aws">Amazon AWS</option>
                                <option value="hybrid">Hybrid Cloud</option>
                            </select>
                        </div>
                        <div class="form-group">
                            <label>Anzahl der Benutzer</label>
                            <input type="number" name="cloud_users" min="1" max="1000" value="10" required>
                        </div>
                        <div class="form-group">
                            <label>Speicher (GB)</label>
                            <input type="number" name="cloud_storage" min="100" max="10000" value="500" step="100" required>
                        </div>
                        <div class="form-group checkbox-group">
                            <input type="checkbox" id="cloud_ha" name="cloud_ha">
                            <label for="cloud_ha">High Availability</label>
                        </div>
                    </div>
                `,
                vdi: `
                    <div class="service-config-card" id="config-vdi">
                        <h3>Virtuelle Arbeitsplätze Konfiguration</h3>
                        <div class="form-group">
                            <label>Anzahl der Arbeitsplätze</label>
                            <input type="number" name="vdi_users" min="1" max="500" value="10" required>
                        </div>
                        <div class="form-group">
                            <label>Leistungsklasse</label>
                            <select name="vdi_performance" required>
                                <option value="">Bitte wählen</option>
                                <option value="basic">Basic (2 vCPU, 4GB RAM)</option>
                                <option value="standard">Standard (4 vCPU, 8GB RAM)</option>
                                <option value="premium">Premium (8 vCPU, 16GB RAM)</option>
                            </select>
                        </div>
                        <div class="form-group">
                            <label>Betriebssystem</label>
                            <select name="vdi_os" required>
                                <option value="">Bitte wählen</option>
                                <option value="windows10">Windows 10</option>
                                <option value="windows11">Windows 11</option>
                                <option value="linux">Linux</option>
                            </select>
                        </div>
                        <div class="form-group checkbox-group">
                            <input type="checkbox" id="vdi_office" name="vdi_office">
                            <label for="vdi_office">Microsoft Office 365</label>
                        </div>
                    </div>
                `,
                monitoring: `
                    <div class="service-config-card" id="config-monitoring">
                        <h3>Monitoring Konfiguration</h3>
                        <div class="form-group">
                            <label>Anzahl der Geräte/Server</label>
                            <input type="number" name="monitoring_devices" min="1" max="500" value="10" required>
                        </div>
                        <div class="form-group">
                            <label>Monitoring-Umfang</label>
                            <select name="monitoring_scope" required>
                                <option value="">Bitte wählen</option>
                                <option value="basic">Basic (Verfügbarkeit)</option>
                                <option value="standard">Standard (Performance + Logs)</option>
                                <option value="advanced">Advanced (Application Performance)</option>
                            </select>
                        </div>
                        <div class="form-group checkbox-group">
                            <input type="checkbox" id="monitoring_247" name="monitoring_247">
                            <label for="monitoring_247">24/7 Bereitschaftsdienst</label>
                        </div>
                        <div class="form-group checkbox-group">
                            <input type="checkbox" id="monitoring_alerts" name="monitoring_alerts">
                            <label for="monitoring_alerts">SMS/E-Mail Alarme</label>
                        </div>
                    </div>
                `,
                backup: `
                    <div class="service-config-card" id="config-backup">
                        <h3>Backup & Recovery Konfiguration</h3>
                        <div class="form-group">
                            <label>Backup-Volumen (GB)</label>
                            <input type="number" name="backup_volume" min="100" max="50000" value="1000" step="100" required>
                        </div>
                        <div class="form-group">
                            <label>Backup-Häufigkeit</label>
                            <select name="backup_frequency" required>
                                <option value="">Bitte wählen</option>
                                <option value="daily">Täglich</option>
                                <option value="hourly">Stündlich</option>
                                <option value="realtime">Echtzeit</option>
                            </select>
                        </div>
                        <div class="form-group">
                            <label>Aufbewahrung</label>
                            <select name="backup_retention" required>
                                <option value="">Bitte wählen</option>
                                <option value="30">30 Tage</option>
                                <option value="90">90 Tage</option>
                                <option value="365">1 Jahr</option>
                            </select>
                        </div>
                        <div class="form-group checkbox-group">
                            <input type="checkbox" id="backup_offsite" name="backup_offsite">
                            <label for="backup_offsite">Offsite Backup</label>
                        </div>
                    </div>
                `
            };

            return configs[service] || '';
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

        calculatePrice() {
            let totalPrice = 0;

            for (const [service, data] of Object.entries(this.selectedServices)) {
                if (data.selected) {
                    switch(service) {
                        case 'cloud':
                            const cloudUsers = parseInt(data.config.cloud_users) || 0;
                            totalPrice += this.pricing.cloud.base + (cloudUsers * this.pricing.cloud.perUser);
                            if (data.config.cloud_ha) totalPrice += 100;
                            break;

                        case 'vdi':
                            const vdiUsers = parseInt(data.config.vdi_users) || 0;
                            let vdiMultiplier = 1;
                            if (data.config.vdi_performance === 'standard') vdiMultiplier = 1.5;
                            if (data.config.vdi_performance === 'premium') vdiMultiplier = 2.5;
                            totalPrice += this.pricing.vdi.base + (vdiUsers * this.pricing.vdi.perUser * vdiMultiplier);
                            if (data.config.vdi_office) totalPrice += vdiUsers * 12;
                            break;

                        case 'monitoring':
                            const devices = parseInt(data.config.monitoring_devices) || 0;
                            let monitoringMultiplier = 1;
                            if (data.config.monitoring_scope === 'standard') monitoringMultiplier = 1.5;
                            if (data.config.monitoring_scope === 'advanced') monitoringMultiplier = 2;
                            totalPrice += this.pricing.monitoring.base + (devices * this.pricing.monitoring.perDevice * monitoringMultiplier);
                            if (data.config.monitoring_247) totalPrice += 300;
                            break;

                        case 'backup':
                            const volume = parseInt(data.config.backup_volume) || 0;
                            let backupMultiplier = 1;
                            if (data.config.backup_frequency === 'hourly') backupMultiplier = 1.3;
                            if (data.config.backup_frequency === 'realtime') backupMultiplier = 1.8;
                            totalPrice += this.pricing.backup.base + (volume * this.pricing.backup.perGB * backupMultiplier);
                            if (data.config.backup_offsite) totalPrice += 150;
                            break;
                    }
                }
            }

            $('#total-price').text(Math.round(totalPrice));
            return totalPrice;
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

        updateSummary() {
            const servicesList = $('#summary-services-list');
            servicesList.empty();

            for (const [service, data] of Object.entries(this.selectedServices)) {
                if (data.selected) {
                    const serviceName = this.getServiceName(service);
                    const summary = this.generateServiceSummary(service, data.config);

                    servicesList.append(`
                        <div class="summary-service">
                            <h4>${serviceName}</h4>
                            <ul>${summary}</ul>
                        </div>
                    `);
                }
            }

            this.calculatePrice();
        }

        getServiceName(service) {
            const names = {
                cloud: 'Cloud Services',
                vdi: 'Virtuelle Arbeitsplätze',
                monitoring: 'Monitoring',
                backup: 'Backup & Recovery'
            };
            return names[service] || service;
        }

        generateServiceSummary(service, config) {
            let summary = '';

            for (const [key, value] of Object.entries(config)) {
                if (value) {
                    const label = this.formatConfigLabel(key);
                    const displayValue = typeof value === 'boolean' ? 'Ja' : value;
                    summary += `<li><strong>${label}:</strong> ${displayValue}</li>`;
                }
            }

            return summary;
        }

        formatConfigLabel(key) {
            const labels = {
                cloud_type: 'Cloud-Typ',
                cloud_users: 'Benutzer',
                cloud_storage: 'Speicher (GB)',
                cloud_ha: 'High Availability',
                vdi_users: 'Arbeitsplätze',
                vdi_performance: 'Leistungsklasse',
                vdi_os: 'Betriebssystem',
                vdi_office: 'Office 365',
                monitoring_devices: 'Geräte',
                monitoring_scope: 'Umfang',
                monitoring_247: '24/7 Bereitschaft',
                monitoring_alerts: 'Alarme',
                backup_volume: 'Volumen (GB)',
                backup_frequency: 'Häufigkeit',
                backup_retention: 'Aufbewahrung',
                backup_offsite: 'Offsite Backup'
            };
            return labels[key] || key;
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
                estimated_price: this.calculatePrice()
            };

            $('#btn-submit').prop('disabled', true).text('Wird gesendet...');

            $.ajax({
                url: ramboeckConfig.ajaxUrl,
                type: 'POST',
                data: submitData,
                success: (response) => {
                    if (response.success) {
                        this.showMessage(response.data.message, 'success');
                        setTimeout(() => {
                            this.resetConfigurator();
                        }, 3000);
                    } else {
                        this.showMessage(response.data.message, 'error');
                        $('#btn-submit').prop('disabled', false).text('Angebot anfordern');
                    }
                },
                error: () => {
                    this.showMessage('Ein Fehler ist aufgetreten. Bitte versuchen Sie es später erneut.', 'error');
                    $('#btn-submit').prop('disabled', false).text('Angebot anfordern');
                }
            });
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

        resetConfigurator() {
            this.currentStep = 1;
            this.selectedServices = {
                cloud: { selected: false, config: {} },
                vdi: { selected: false, config: {} },
                monitoring: { selected: false, config: {} },
                backup: { selected: false, config: {} }
            };
            this.contactData = {};

            $('input[name="services[]"]').prop('checked', false);
            $('.service-card').removeClass('selected');
            $('#contact-form')[0].reset();

            this.showStep(1);
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
            new RamboeckConfigurator();
        }
    });

})(jQuery);
