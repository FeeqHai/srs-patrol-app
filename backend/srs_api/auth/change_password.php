<?php
header('Content-Type: application/json');
require_once '../config/db_connect.php';
require_once '../config/access_control.php';
require_once '../config/account_validation.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["status" => "error", "message" => "Invalid request method."]);
    exit();
}

$actor = get_current_actor($conn);
$current_password = account_string($_POST['current_password'] ?? '');
$new_password = account_string($_POST['new_password'] ?? '');

if ($current_password === '' || $new_password === '') {
    api_error(400, 'Current password and new password are required.');
}
if (($validation_error = account_password_error($new_password)) !== null) {
    api_error(422, $validation_error);
}

$stmt = $conn->prepare("SELECT password_hash FROM users WHERE id = ?");
if (!$stmt) {
    api_error(500, 'Unable to verify current password.');
}
$stmt->bind_param('s', $actor['id']);
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$user || !password_verify($current_password, $user['password_hash'])) {
    api_error(400, 'Current password is incorrect.');
}

$hash = password_hash($new_password, PASSWORD_BCRYPT);
$stmt = $conn->prepare("UPDATE users SET password_hash = ?, must_change_password = 0 WHERE id = ?");
if (!$stmt) {
    api_error(500, 'Unable to update password.');
}
$stmt->bind_param('ss', $hash, $actor['id']);
$ok = $stmt->execute();
$stmt->close();

echo json_encode($ok
    ? ["status" => "success", "message" => "Password changed successfully."]
    : ["status" => "error", "message" => "Failed to change password."]);

$conn->close();
?>
