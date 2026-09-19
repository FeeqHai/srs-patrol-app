<?php
require_once __DIR__ . '/hosting.php';
require_once __DIR__ . '/account_validation.php';

// Registration sessions remain usable for 15 minutes after MyKad extraction.
const REGISTRATION_VERIFICATION_TTL_SECONDS = 900;

function verification_json_error($message, $http_status = 200, $extra = []) {
    http_response_code($http_status);
    echo json_encode(array_merge([
        'status' => 'error',
        'message' => $message,
    ], $extra));
    exit();
}

function verification_uuid_v4() {
    $data = random_bytes(16);
    $data[6] = chr((ord($data[6]) & 0x0f) | 0x40);
    $data[8] = chr((ord($data[8]) & 0x3f) | 0x80);
    return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
}

function verification_pepper() {
    return srs_config('SRS_VERIFICATION_PEPPER');
}

function verification_hash($value) {
    return hash_hmac('sha256', strtolower(trim($value)), verification_pepper());
}

function verification_normalize_ic($value) {
    return account_normalize_ic($value);
}

function verification_is_valid_ic($value) {
    return account_ic_error($value) === null;
}

function verification_is_valid_session_id($value) {
    return preg_match(
        '/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i',
        (string) $value
    ) === 1;
}

function verification_is_valid_token($value) {
    return preg_match('/^[0-9a-f]{64}$/', (string) $value) === 1;
}

function verification_client_ip() {
    return trim($_SERVER['REMOTE_ADDR'] ?? 'unknown');
}

function verification_enforce_rate_limit($conn, $endpoint, $maximum, $window_minutes = 60) {
    $conn->query("DELETE FROM registration_request_limits
                  WHERE created_at < DATE_SUB(NOW(), INTERVAL 1 DAY)");
    $client_hash = verification_hash(verification_client_ip());
    $window_minutes = max(1, (int) $window_minutes);
    $query = "SELECT COUNT(*) AS request_count
              FROM registration_request_limits
              WHERE endpoint = ? AND client_hash = ?
                AND created_at >= DATE_SUB(NOW(), INTERVAL ? MINUTE)";
    $stmt = $conn->prepare($query);
    if (!$stmt) {
        verification_json_error('Unable to check the request limit.', 500);
    }
    $stmt->bind_param('ssi', $endpoint, $client_hash, $window_minutes);
    $stmt->execute();
    $count = (int) ($stmt->get_result()->fetch_assoc()['request_count'] ?? 0);
    $stmt->close();
    if ($count >= $maximum) {
        verification_json_error('Had permintaan dicapai. Cuba semula kemudian.');
    }
    $insert = $conn->prepare(
        'INSERT INTO registration_request_limits (endpoint, client_hash) VALUES (?, ?)'
    );
    if (!$insert) {
        verification_json_error('Unable to record the request limit.', 500);
    }
    $insert->bind_param('ss', $endpoint, $client_hash);
    $insert->execute();
    $insert->close();
}

function verification_cleanup($conn) {
    $conn->query("UPDATE registration_verifications
                  SET status = 'expired', full_name = NULL
                  WHERE status IN ('started', 'verified') AND expires_at <= NOW()");
    $conn->query("DELETE FROM registration_verifications
                  WHERE (status = 'expired' AND updated_at < DATE_SUB(NOW(), INTERVAL 1 DAY))
                     OR (status = 'failed' AND updated_at < DATE_SUB(NOW(), INTERVAL 1 DAY))
                     OR (status = 'consumed' AND consumed_at < DATE_SUB(NOW(), INTERVAL 1 DAY))");
}
