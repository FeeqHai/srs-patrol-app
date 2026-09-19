<?php
header('Content-Type: application/json');
require_once '../../config/db_connect.php';
require_once '../../config/registration_verification.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    verification_json_error('Sistem menolak request ini.', 405);
}

verification_enforce_rate_limit($conn, 'verification_start', 100, 60);
verification_cleanup($conn);

$ic_number = verification_normalize_ic($_POST['ic_number'] ?? '');
$device_id = trim($_POST['device_id'] ?? '');
$consent = filter_var($_POST['consent'] ?? false, FILTER_VALIDATE_BOOLEAN);

if (!$consent) {
    verification_json_error('Persetujuan privasi diperlukan sebelum pengesahan.');
}
if (($validation_error = account_ic_error($ic_number)) !== null) {
    verification_json_error($validation_error);
}
if ($device_id === '' || strlen($device_id) > 100) {
    verification_json_error('Pengecam peranti tidak sah.');
}

$ic_hash = verification_hash($ic_number);
$device_hash = verification_hash($device_id);
$ip_hash = verification_hash(verification_client_ip());

$duplicate_stmt = $conn->prepare('SELECT id FROM users WHERE ic_number = ? LIMIT 1');
if (!$duplicate_stmt) {
    verification_json_error('Unable to validate the MyKad number.', 500);
}
$duplicate_stmt->bind_param('s', $ic_number);
$duplicate_stmt->execute();
$already_registered = $duplicate_stmt->get_result()->fetch_assoc();
$duplicate_stmt->close();
if ($already_registered) {
    verification_json_error('Nombor MyKad ini telah didaftarkan.');
}

$session_id = verification_uuid_v4();
$plain_token = bin2hex(random_bytes(32));
$token_hash = hash('sha256', $plain_token);
$expires_at = date('Y-m-d H:i:s', time() + REGISTRATION_VERIFICATION_TTL_SECONDS);

$insert = $conn->prepare(
    "INSERT INTO registration_verifications
        (id, token_hash, ic_hash, device_hash, ip_hash, status, expires_at)
     VALUES (?, ?, ?, ?, ?, 'started', ?)"
);
if (!$insert) {
    verification_json_error('Unable to create a verification session.', 500);
}
$insert->bind_param('ssssss', $session_id, $token_hash, $ic_hash, $device_hash, $ip_hash, $expires_at);
if (!$insert->execute()) {
    $insert->close();
    verification_json_error('Unable to create a verification session.', 500);
}
$insert->close();

echo json_encode([
    'status' => 'success',
    'message' => 'Sesi pengesahan dimulakan.',
    'data' => [
        'session_id' => $session_id,
        'verification_token' => $plain_token,
        'expires_at' => date(DATE_ATOM, strtotime($expires_at)),
    ],
]);
$conn->close();
