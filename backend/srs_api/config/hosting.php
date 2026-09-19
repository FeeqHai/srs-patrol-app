<?php
ini_set('display_errors', '0');
ini_set('log_errors', '1');

function srs_hosting_error() {
    http_response_code(503);
    header('Content-Type: application/json');
    echo json_encode(['status' => 'error', 'message' => 'Server configuration is incomplete.']);
    exit();
}

function srs_config($key) {
    static $settings = null;
    if ($settings === null) {
        $path = getenv('SRS_SETTINGS_PATH') ?: dirname(__DIR__, 2) . '/private/settings.php';
        if (!is_readable($path)) {
            srs_hosting_error();
        }
        $settings = require $path;
        if (!is_array($settings)) {
            srs_hosting_error();
        }
        foreach (['SRS_DB_HOST', 'SRS_DB_USER', 'SRS_DB_NAME', 'SRS_DB_PASSWORD',
                  'SRS_TIMEZONE', 'SRS_JWT_SECRET', 'SRS_VERIFICATION_PEPPER'] as $required) {
            if (!isset($settings[$required]) || !is_string($settings[$required]) || $settings[$required] === '') {
                srs_hosting_error();
            }
        }
        if ($settings['SRS_DB_PASSWORD'] === 'REPLACE_WITH_YOUR_CPANEL_DATABASE_USER_PASSWORD'
            || strlen($settings['SRS_JWT_SECRET']) < 32
            || strlen($settings['SRS_VERIFICATION_PEPPER']) < 32) {
            srs_hosting_error();
        }
    }
    return $settings[$key] ?? null;
}
