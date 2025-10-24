<?php
/**
 * Admin-Seite für Lead-Verwaltung
 */

if (!defined('ABSPATH')) {
    exit;
}

global $wpdb;
$table_name = $wpdb->prefix . 'ramboeck_leads';

// Handle actions
if (isset($_POST['action']) && isset($_POST['lead_id'])) {
    check_admin_referer('ramboeck_lead_action');

    $lead_id = intval($_POST['lead_id']);
    $action = sanitize_text_field($_POST['action']);

    if ($action === 'delete') {
        $wpdb->delete($table_name, array('id' => $lead_id), array('%d'));
        echo '<div class="notice notice-success"><p>Lead erfolgreich gelöscht.</p></div>';
    } elseif ($action === 'update_status') {
        $new_status = sanitize_text_field($_POST['status']);
        $wpdb->update(
            $table_name,
            array('status' => $new_status),
            array('id' => $lead_id),
            array('%s'),
            array('%d')
        );
        echo '<div class="notice notice-success"><p>Status aktualisiert.</p></div>';
    }
}

// Get leads
$leads = $wpdb->get_results("SELECT * FROM $table_name ORDER BY created_at DESC");

?>

<div class="wrap ramboeck-admin">
    <h1>Service Konfigurator - Lead Verwaltung</h1>

    <div class="ramboeck-admin-stats">
        <div class="stat-card">
            <h3><?php echo count($leads); ?></h3>
            <p>Gesamt Leads</p>
        </div>
        <div class="stat-card">
            <h3><?php echo count(array_filter($leads, function($l) { return $l->status === 'new'; })); ?></h3>
            <p>Neue Leads</p>
        </div>
        <div class="stat-card">
            <h3><?php echo count(array_filter($leads, function($l) { return $l->status === 'contacted'; })); ?></h3>
            <p>Kontaktiert</p>
        </div>
        <div class="stat-card">
            <h3><?php echo count(array_filter($leads, function($l) { return $l->status === 'converted'; })); ?></h3>
            <p>Konvertiert</p>
        </div>
    </div>

    <?php if (empty($leads)): ?>
        <div class="notice notice-info">
            <p>Noch keine Leads vorhanden. Fügen Sie den Shortcode <code>[ramboeck_configurator]</code> zu einer Seite hinzu, um den Konfigurator anzuzeigen.</p>
        </div>
    <?php else: ?>

        <table class="wp-list-table widefat fixed striped">
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Name</th>
                    <th>E-Mail</th>
                    <th>Firma</th>
                    <th>Services</th>
                    <th>Preis (€/Monat)</th>
                    <th>Status</th>
                    <th>Datum</th>
                    <th>Aktionen</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($leads as $lead): ?>
                    <?php
                    $services = json_decode($lead->services, true);
                    $selected_services = array();
                    foreach ($services as $service => $data) {
                        if ($data['selected']) {
                            $selected_services[] = ucfirst($service);
                        }
                    }
                    ?>
                    <tr>
                        <td><?php echo esc_html($lead->id); ?></td>
                        <td><strong><?php echo esc_html($lead->name); ?></strong></td>
                        <td><a href="mailto:<?php echo esc_attr($lead->email); ?>"><?php echo esc_html($lead->email); ?></a></td>
                        <td><?php echo esc_html($lead->company); ?></td>
                        <td><?php echo esc_html(implode(', ', $selected_services)); ?></td>
                        <td><strong>€<?php echo number_format($lead->estimated_price, 2); ?></strong></td>
                        <td>
                            <form method="post" style="display: inline;">
                                <?php wp_nonce_field('ramboeck_lead_action'); ?>
                                <input type="hidden" name="lead_id" value="<?php echo esc_attr($lead->id); ?>">
                                <input type="hidden" name="action" value="update_status">
                                <select name="status" onchange="this.form.submit()" class="status-select status-<?php echo esc_attr($lead->status); ?>">
                                    <option value="new" <?php selected($lead->status, 'new'); ?>>Neu</option>
                                    <option value="contacted" <?php selected($lead->status, 'contacted'); ?>>Kontaktiert</option>
                                    <option value="proposal_sent" <?php selected($lead->status, 'proposal_sent'); ?>>Angebot gesendet</option>
                                    <option value="converted" <?php selected($lead->status, 'converted'); ?>>Konvertiert</option>
                                    <option value="rejected" <?php selected($lead->status, 'rejected'); ?>>Abgelehnt</option>
                                </select>
                            </form>
                        </td>
                        <td><?php echo esc_html(date('d.m.Y H:i', strtotime($lead->created_at))); ?></td>
                        <td>
                            <button class="button button-small view-details" data-lead-id="<?php echo esc_attr($lead->id); ?>">Details</button>
                            <form method="post" style="display: inline;" onsubmit="return confirm('Wirklich löschen?');">
                                <?php wp_nonce_field('ramboeck_lead_action'); ?>
                                <input type="hidden" name="lead_id" value="<?php echo esc_attr($lead->id); ?>">
                                <input type="hidden" name="action" value="delete">
                                <button type="submit" class="button button-small button-link-delete">Löschen</button>
                            </form>
                        </td>
                    </tr>

                    <!-- Details Modal (versteckt) -->
                    <tr class="lead-details" id="details-<?php echo esc_attr($lead->id); ?>" style="display: none;">
                        <td colspan="9">
                            <div class="lead-details-content">
                                <h3>Lead Details - <?php echo esc_html($lead->name); ?></h3>

                                <div class="details-grid">
                                    <div class="detail-section">
                                        <h4>Kontaktinformationen</h4>
                                        <p><strong>Name:</strong> <?php echo esc_html($lead->name); ?></p>
                                        <p><strong>E-Mail:</strong> <a href="mailto:<?php echo esc_attr($lead->email); ?>"><?php echo esc_html($lead->email); ?></a></p>
                                        <p><strong>Firma:</strong> <?php echo esc_html($lead->company ?: '-'); ?></p>
                                        <p><strong>Telefon:</strong> <?php echo esc_html($lead->phone ?: '-'); ?></p>
                                        <p><strong>Datum:</strong> <?php echo esc_html(date('d.m.Y H:i', strtotime($lead->created_at))); ?></p>
                                    </div>

                                    <div class="detail-section">
                                        <h4>Service-Konfiguration</h4>
                                        <?php
                                        $configuration = json_decode($lead->configuration, true);
                                        foreach ($configuration as $service => $data) {
                                            if ($data['selected']) {
                                                echo '<div class="service-detail">';
                                                echo '<h5>' . esc_html(ucfirst($service)) . '</h5>';
                                                echo '<ul>';
                                                foreach ($data['config'] as $key => $value) {
                                                    if ($value) {
                                                        $display_value = is_bool($value) ? 'Ja' : $value;
                                                        echo '<li><strong>' . esc_html(str_replace('_', ' ', $key)) . ':</strong> ' . esc_html($display_value) . '</li>';
                                                    }
                                                }
                                                echo '</ul>';
                                                echo '</div>';
                                            }
                                        }
                                        ?>
                                    </div>

                                    <div class="detail-section">
                                        <h4>Preisschätzung</h4>
                                        <p class="price-large">€<?php echo number_format($lead->estimated_price, 2); ?> / Monat</p>
                                        <p class="price-note">* Unverbindliche Schätzung</p>
                                    </div>
                                </div>

                                <button class="button close-details" data-lead-id="<?php echo esc_attr($lead->id); ?>">Schließen</button>
                            </div>
                        </td>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>

    <?php endif; ?>

    <div class="ramboeck-admin-help">
        <h3>Shortcode</h3>
        <p>Verwenden Sie folgenden Shortcode, um den Konfigurator auf einer Seite anzuzeigen:</p>
        <code>[ramboeck_configurator]</code>
    </div>
</div>

<style>
.ramboeck-admin-stats {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 20px;
    margin: 20px 0;
}

.stat-card {
    background: #fff;
    border: 1px solid #c3c4c7;
    border-radius: 4px;
    padding: 20px;
    text-align: center;
}

.stat-card h3 {
    font-size: 36px;
    margin: 0 0 10px 0;
    color: #2271b1;
}

.stat-card p {
    margin: 0;
    color: #646970;
}

.lead-details-content {
    padding: 20px;
    background: #f6f7f7;
    border-radius: 4px;
}

.details-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 20px;
    margin: 20px 0;
}

.detail-section {
    background: #fff;
    padding: 15px;
    border-radius: 4px;
}

.detail-section h4 {
    margin-top: 0;
    border-bottom: 2px solid #2271b1;
    padding-bottom: 10px;
}

.service-detail {
    margin-bottom: 15px;
}

.service-detail h5 {
    color: #2271b1;
    margin-bottom: 5px;
}

.service-detail ul {
    margin: 5px 0;
    padding-left: 20px;
}

.price-large {
    font-size: 32px;
    font-weight: bold;
    color: #2271b1;
    margin: 10px 0;
}

.price-note {
    font-size: 12px;
    color: #646970;
}

.status-select {
    border-radius: 3px;
    padding: 2px 5px;
}

.status-new { background: #fff3cd; }
.status-contacted { background: #cfe2ff; }
.status-proposal_sent { background: #e7f3ff; }
.status-converted { background: #d1e7dd; }
.status-rejected { background: #f8d7da; }

.ramboeck-admin-help {
    margin-top: 30px;
    padding: 20px;
    background: #fff;
    border: 1px solid #c3c4c7;
    border-radius: 4px;
}

.ramboeck-admin-help code {
    background: #f0f0f1;
    padding: 5px 10px;
    border-radius: 3px;
    font-size: 14px;
}
</style>

<script>
jQuery(document).ready(function($) {
    $('.view-details').on('click', function() {
        var leadId = $(this).data('lead-id');
        $('#details-' + leadId).toggle();
    });

    $('.close-details').on('click', function() {
        var leadId = $(this).data('lead-id');
        $('#details-' + leadId).hide();
    });
});
</script>
