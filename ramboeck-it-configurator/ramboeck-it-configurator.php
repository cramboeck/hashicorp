<?php
/**
 * Plugin Name: Ramboeck IT Service Configurator
 * Plugin URI: https://ramboeck-it.com
 * Description: Ein interaktiver Konfigurator für Cloud Services, virtuelle Arbeitsplätze, Monitoring und Backup als Lead-Magnet
 * Version: 1.0.0
 * Author: Ramboeck IT
 * Author URI: https://ramboeck-it.com
 * License: GPL v2 or later
 * License URI: https://www.gnu.org/licenses/gpl-2.0.html
 * Text Domain: ramboeck-it-configurator
 * Domain Path: /languages
 */

// Verhindere direkten Zugriff
if (!defined('ABSPATH')) {
    exit;
}

// Plugin-Konstanten definieren
define('RAMBOECK_CONFIGURATOR_VERSION', '1.0.0');
define('RAMBOECK_CONFIGURATOR_PLUGIN_DIR', plugin_dir_path(__FILE__));
define('RAMBOECK_CONFIGURATOR_PLUGIN_URL', plugin_dir_url(__FILE__));

/**
 * Hauptklasse für das Plugin
 */
class Ramboeck_IT_Configurator {

    private static $instance = null;

    /**
     * Singleton Pattern
     */
    public static function get_instance() {
        if (null === self::$instance) {
            self::$instance = new self();
        }
        return self::$instance;
    }

    /**
     * Konstruktor
     */
    private function __construct() {
        $this->init_hooks();
    }

    /**
     * Initialisiere WordPress-Hooks
     */
    private function init_hooks() {
        // Aktivierung und Deaktivierung
        register_activation_hook(__FILE__, array($this, 'activate'));
        register_deactivation_hook(__FILE__, array($this, 'deactivate'));

        // Plugin-Initialisierung
        add_action('plugins_loaded', array($this, 'init'));

        // Scripts und Styles
        add_action('wp_enqueue_scripts', array($this, 'enqueue_frontend_assets'));
        add_action('admin_enqueue_scripts', array($this, 'enqueue_admin_assets'));

        // Shortcode registrieren
        add_shortcode('ramboeck_configurator', array($this, 'render_configurator'));

        // AJAX-Hooks für Lead-Erfassung
        add_action('wp_ajax_ramboeck_save_lead', array($this, 'save_lead'));
        add_action('wp_ajax_nopriv_ramboeck_save_lead', array($this, 'save_lead'));

        // Admin-Menü
        add_action('admin_menu', array($this, 'add_admin_menu'));

        // REST API
        add_action('rest_api_init', array($this, 'register_rest_routes'));
    }

    /**
     * Plugin-Aktivierung
     */
    public function activate() {
        global $wpdb;

        $table_name = $wpdb->prefix . 'ramboeck_leads';
        $charset_collate = $wpdb->get_charset_collate();

        $sql = "CREATE TABLE IF NOT EXISTS $table_name (
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
        ) $charset_collate;";

        require_once(ABSPATH . 'wp-admin/includes/upgrade.php');
        dbDelta($sql);

        // Optionen setzen
        add_option('ramboeck_configurator_version', RAMBOECK_CONFIGURATOR_VERSION);
    }

    /**
     * Plugin-Deaktivierung
     */
    public function deactivate() {
        // Cleanup bei Bedarf
    }

    /**
     * Initialisiere Plugin
     */
    public function init() {
        // Lade Übersetzungen
        load_plugin_textdomain('ramboeck-it-configurator', false, dirname(plugin_basename(__FILE__)) . '/languages');
    }

    /**
     * Frontend-Assets laden
     */
    public function enqueue_frontend_assets() {
        wp_enqueue_style(
            'ramboeck-configurator-style',
            RAMBOECK_CONFIGURATOR_PLUGIN_URL . 'assets/css/configurator.css',
            array(),
            RAMBOECK_CONFIGURATOR_VERSION
        );

        wp_enqueue_script(
            'ramboeck-configurator-script',
            RAMBOECK_CONFIGURATOR_PLUGIN_URL . 'assets/js/configurator.js',
            array('jquery'),
            RAMBOECK_CONFIGURATOR_VERSION,
            true
        );

        // Lokalisiere Script für AJAX
        wp_localize_script('ramboeck-configurator-script', 'ramboeckConfig', array(
            'ajaxUrl' => admin_url('admin-ajax.php'),
            'nonce' => wp_create_nonce('ramboeck_configurator_nonce'),
            'strings' => array(
                'success' => __('Vielen Dank! Wir melden uns in Kürze bei Ihnen.', 'ramboeck-it-configurator'),
                'error' => __('Ein Fehler ist aufgetreten. Bitte versuchen Sie es später erneut.', 'ramboeck-it-configurator'),
            )
        ));
    }

    /**
     * Admin-Assets laden
     */
    public function enqueue_admin_assets($hook) {
        if ('toplevel_page_ramboeck-configurator' !== $hook) {
            return;
        }

        wp_enqueue_style(
            'ramboeck-admin-style',
            RAMBOECK_CONFIGURATOR_PLUGIN_URL . 'assets/css/admin.css',
            array(),
            RAMBOECK_CONFIGURATOR_VERSION
        );

        wp_enqueue_script(
            'ramboeck-admin-script',
            RAMBOECK_CONFIGURATOR_PLUGIN_URL . 'assets/js/admin.js',
            array('jquery'),
            RAMBOECK_CONFIGURATOR_VERSION,
            true
        );
    }

    /**
     * Konfigurator-Shortcode rendern
     */
    public function render_configurator($atts) {
        $atts = shortcode_atts(array(
            'theme' => 'default',
        ), $atts);

        ob_start();
        include RAMBOECK_CONFIGURATOR_PLUGIN_DIR . 'templates/configurator.php';
        return ob_get_clean();
    }

    /**
     * Lead speichern
     */
    public function save_lead() {
        check_ajax_referer('ramboeck_configurator_nonce', 'nonce');

        global $wpdb;
        $table_name = $wpdb->prefix . 'ramboeck_leads';

        // Daten validieren und sanitizen
        $name = sanitize_text_field($_POST['name']);
        $email = sanitize_email($_POST['email']);
        $company = sanitize_text_field($_POST['company']);
        $phone = sanitize_text_field($_POST['phone']);
        $services = json_encode($_POST['services']);
        $configuration = json_encode($_POST['configuration']);
        $estimated_price = floatval($_POST['estimated_price']);

        // Email-Validierung
        if (!is_email($email)) {
            wp_send_json_error(array('message' => 'Ungültige E-Mail-Adresse'));
            return;
        }

        // Lead in Datenbank speichern
        $result = $wpdb->insert(
            $table_name,
            array(
                'name' => $name,
                'email' => $email,
                'company' => $company,
                'phone' => $phone,
                'services' => $services,
                'configuration' => $configuration,
                'estimated_price' => $estimated_price,
                'status' => 'new',
            ),
            array('%s', '%s', '%s', '%s', '%s', '%s', '%f', '%s')
        );

        if ($result) {
            // E-Mail-Benachrichtigung senden
            $this->send_notification_email($name, $email, $company, $phone, $_POST['services'], $estimated_price);

            wp_send_json_success(array(
                'message' => __('Ihre Anfrage wurde erfolgreich übermittelt!', 'ramboeck-it-configurator')
            ));
        } else {
            wp_send_json_error(array(
                'message' => __('Fehler beim Speichern. Bitte versuchen Sie es erneut.', 'ramboeck-it-configurator')
            ));
        }
    }

    /**
     * Benachrichtigungs-E-Mail senden
     */
    private function send_notification_email($name, $email, $company, $phone, $services, $price) {
        $admin_email = get_option('admin_email');
        $subject = 'Neue Anfrage über Service Konfigurator - ' . $name;

        $message = "Neue Lead-Anfrage:\n\n";
        $message .= "Name: $name\n";
        $message .= "E-Mail: $email\n";
        $message .= "Firma: $company\n";
        $message .= "Telefon: $phone\n";
        $message .= "Geschätzter Preis: €" . number_format($price, 2) . "\n\n";
        $message .= "Ausgewählte Services:\n";

        foreach ($services as $service => $details) {
            if ($details['selected']) {
                $message .= "- " . ucfirst($service) . "\n";
            }
        }

        $headers = array('Content-Type: text/plain; charset=UTF-8');

        wp_mail($admin_email, $subject, $message, $headers);

        // Bestätigungs-E-Mail an Kunden
        $customer_subject = 'Ihre Anfrage bei Ramboeck IT';
        $customer_message = "Hallo $name,\n\n";
        $customer_message .= "vielen Dank für Ihre Anfrage über unseren Service Konfigurator.\n";
        $customer_message .= "Wir haben Ihre Anfrage erhalten und werden uns in Kürze bei Ihnen melden.\n\n";
        $customer_message .= "Ihre Konfiguration:\n";
        $customer_message .= "Geschätzter Preis: €" . number_format($price, 2) . "\n\n";
        $customer_message .= "Mit freundlichen Grüßen\n";
        $customer_message .= "Ihr Ramboeck IT Team";

        wp_mail($email, $customer_subject, $customer_message, $headers);
    }

    /**
     * Admin-Menü hinzufügen
     */
    public function add_admin_menu() {
        add_menu_page(
            __('Service Konfigurator', 'ramboeck-it-configurator'),
            __('Konfigurator', 'ramboeck-it-configurator'),
            'manage_options',
            'ramboeck-configurator',
            array($this, 'render_admin_page'),
            'dashicons-admin-generic',
            30
        );
    }

    /**
     * Admin-Seite rendern
     */
    public function render_admin_page() {
        include RAMBOECK_CONFIGURATOR_PLUGIN_DIR . 'admin/admin-page.php';
    }

    /**
     * REST API Routen registrieren
     */
    public function register_rest_routes() {
        register_rest_route('ramboeck/v1', '/leads', array(
            'methods' => 'GET',
            'callback' => array($this, 'get_leads'),
            'permission_callback' => function() {
                return current_user_can('manage_options');
            }
        ));
    }

    /**
     * Leads über REST API abrufen
     */
    public function get_leads() {
        global $wpdb;
        $table_name = $wpdb->prefix . 'ramboeck_leads';

        $leads = $wpdb->get_results("SELECT * FROM $table_name ORDER BY created_at DESC");

        return rest_ensure_response($leads);
    }
}

// Plugin initialisieren
function ramboeck_configurator_init() {
    return Ramboeck_IT_Configurator::get_instance();
}

// Plugin starten
ramboeck_configurator_init();
