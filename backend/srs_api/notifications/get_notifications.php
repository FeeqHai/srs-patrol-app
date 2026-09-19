<?php
header('Content-Type: application/json');
require_once '../config/db_connect.php';
require_once '../config/access_control.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    api_error(405, 'Invalid request method.');
}

$actor = get_current_actor($conn);

$count_stmt = $conn->prepare(
    'SELECT COUNT(*) AS unread_count
     FROM notifications
     WHERE user_id = ? AND is_read = 0 AND COALESCE(is_deleted, 0) = 0'
);
if (!$count_stmt) {
    api_error(500, 'Unable to load notifications.');
}
$count_stmt->bind_param('s', $actor['id']);
$count_stmt->execute();
$count_row = $count_stmt->get_result()->fetch_assoc();
$unread_count = (int)($count_row['unread_count'] ?? 0);
$count_stmt->close();

$stmt = $conn->prepare(
    'SELECT id, type, title, body, payload_json, is_read, created_at
     FROM notifications
     WHERE user_id = ? AND COALESCE(is_deleted, 0) = 0
     ORDER BY created_at DESC
     LIMIT 100'
);
if (!$stmt) {
    api_error(500, 'Unable to load notifications.');
}

$stmt->bind_param('s', $actor['id']);
$stmt->execute();
$result = $stmt->get_result();

$notifications = [];
while ($row = $result->fetch_assoc()) {
    $row['is_read'] = (int)$row['is_read'];
    $payload = json_decode($row['payload_json'] ?? '', true);
    $row['related_id'] = is_array($payload) ? ($payload['related_id'] ?? null) : null;
    unset($row['payload_json']);
    $notifications[] = $row;
}

$stmt->close();
$conn->close();

echo json_encode([
    'status' => 'success',
    'message' => 'Notifications loaded.',
    'data' => [
        'notifications' => $notifications,
        'unread_count' => $unread_count
    ]
]);
?>
