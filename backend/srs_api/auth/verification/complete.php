<?php
header('Content-Type: application/json');
require_once '../../config/db_connect.php';
require_once '../../config/registration_verification.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    verification_json_error('Sistem menolak request ini.', 405);
}

verification_enforce_rate_limit($conn, 'verification_complete', 100, 60);
verification_cleanup($conn);

$session_id = trim($_POST['session_id'] ?? '');
$plain_token = trim($_POST['verification_token'] ?? '');
$full_name = trim(preg_replace('/\s+/', ' ', $_POST['full_name'] ?? ''));
$model_version = substr(trim($_POST['model_version'] ?? ''), 0, 50);
$method = 'on_device_mykad_ocr_prototype';
$quality_passed = filter_var($_POST['quality_passed'] ?? false, FILTER_VALIDATE_BOOLEAN);

if ($session_id === '' || $plain_token === '' || $full_name === '') {
    verification_json_error('Maklumat pengesahan tidak lengkap.');
}
if (!verification_is_valid_session_id($session_id) || !verification_is_valid_token($plain_token)) {
    verification_json_error('Sesi pengesahan telah tamat atau tidak sah. Sila mula semula.');
}
if (strlen($full_name) > 100 || $model_version === '') {
    verification_json_error('Keputusan pengesahan tidak sah.');
}

$token_hash = hash('sha256', $plain_token);
$session_stmt = $conn->prepare(
    "SELECT id, status, expires_at
     FROM registration_verifications
     WHERE id = ? AND token_hash = ? LIMIT 1"
);
if (!$session_stmt) {
    verification_json_error('Unable to validate the verification session.', 500);
}
$session_stmt->bind_param('ss', $session_id, $token_hash);
$session_stmt->execute();
$session = $session_stmt->get_result()->fetch_assoc();
$session_stmt->close();

if (!$session || $session['status'] !== 'started' || strtotime($session['expires_at']) <= time()) {
    verification_json_error('Sesi pengesahan telah tamat atau tidak sah. Sila mula semula.');
}

if (!$quality_passed) {
    $reason = 'document_quality';
    $failed_stmt = $conn->prepare(
        "UPDATE registration_verifications
         SET status = 'failed', failure_reason = ?, full_name = NULL,
             verification_method = ?, model_version = ?,
             similarity_score = NULL, liveness_passed = 0, quality_passed = 0
         WHERE id = ? AND status = 'started'"
    );
    if (!$failed_stmt) {
        verification_json_error('Unable to record the verification result.', 500);
    }
    $failed_stmt->bind_param('ssss', $reason, $method, $model_version, $session_id);
    $failed_stmt->execute();
    $failed_stmt->close();

    verification_json_error('Kualiti imej MyKad tidak memenuhi syarat. Sila cuba semula.');
}

$verified_stmt = $conn->prepare(
    "UPDATE registration_verifications
     SET status = 'verified', full_name = ?,
         verification_method = ?, model_version = ?, similarity_score = NULL,
         liveness_passed = 0, quality_passed = 1, verified_at = NOW()
     WHERE id = ? AND status = 'started'"
);
if (!$verified_stmt) {
    verification_json_error('Unable to record the verification result.', 500);
}
$verified_stmt->bind_param('ssss', $full_name, $method, $model_version, $session_id);
if (!$verified_stmt->execute() || $verified_stmt->affected_rows !== 1) {
    $verified_stmt->close();
    verification_json_error('Sesi pengesahan tidak boleh digunakan semula.');
}
$verified_stmt->close();

echo json_encode([
    'status' => 'success',
    'message' => 'Nama dan nombor MyKad berjaya diekstrak.',
    'data' => [
        'verification_token' => $plain_token,
        'expires_at' => date(DATE_ATOM, strtotime($session['expires_at'])),
    ],
]);
$conn->close();
