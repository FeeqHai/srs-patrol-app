<?php
header('Content-Type: application/json');
require_once '../config/db_connect.php';
require_once '../config/access_control.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_error(405, 'Invalid request method.');
}

$actor = get_current_actor($conn);
$raw = file_get_contents('php://input');
$json = json_decode($raw, true);
$notification_id = trim($_POST['notification_id'] ?? ($json['notification_id'] ?? ($_POST['id'] ?? ($json['id'] ?? ''))));

if ($notification_id === '') {
    api_error(400, 'Notification id is required.');
}

$stmt = $conn->prepare(
    'UPDATE notifications
     SET is_deleted = 1, deleted_at = NOW()
     WHERE id = ? AND user_id = ?'
);
if (!$stmt) {
    api_error(500, 'Unable to delete notification.');
}

$stmt->bind_param('ss', $notification_id, $actor['id']);
if (!$stmt->execute()) {
    $stmt->close();
    api_error(500, 'Unable to delete notification.');
}

$stmt->close();
$conn->close();

echo json_encode([
    'status' => 'success',
    'message' => 'Notification removed.'
]);
?>
