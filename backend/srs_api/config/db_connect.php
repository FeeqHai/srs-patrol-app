<?php
require_once __DIR__ . '/hosting.php';
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}
date_default_timezone_set(srs_config('SRS_TIMEZONE'));
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
try {
    $conn = new mysqli(srs_config('SRS_DB_HOST'), srs_config('SRS_DB_USER'),
                       srs_config('SRS_DB_PASSWORD'), srs_config('SRS_DB_NAME'));
    $conn->set_charset('utf8mb4');
    $conn->query("SET time_zone = '+08:00'");
} catch (mysqli_sql_exception $error) {
    error_log('iRonda database connection failed; code ' . $error->getCode());
    http_response_code(503);
    header('Content-Type: application/json');
    echo json_encode(['status' => 'error', 'message' => 'Database is temporarily unavailable.']);
    exit();
}
