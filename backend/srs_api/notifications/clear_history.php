<?php
header('Content-Type: application/json');
require_once '../config/db_connect.php';
require_once '../config/access_control.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_error(405, 'Invalid request method.');
}

$actor = get_current_actor($conn);

$stmt = $conn->prepare(
    'UPDATE notifications
     SET is_deleted = 1, deleted_at = NOW()
     WHERE user_id = ? AND is_read = 1 AND COALESCE(is_deleted, 0) = 0'
);
if (!$stmt) {
    api_error(500, 'Unable to clear notification history.');
}

$stmt->bind_param('s', $actor['id']);
if (!$stmt->execute()) {
    $stmt->close();
    api_error(500, 'Unable to clear notification history.');
}

$cleared = $stmt->affected_rows;
$stmt->close();
$conn->close();

echo json_encode([
    'status' => 'success',
    'message' => 'Notification history cleared.',
    'data' => ['cleared' => $cleared]
]);
?>
