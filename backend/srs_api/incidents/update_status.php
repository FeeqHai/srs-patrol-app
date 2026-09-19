<?php
header('Content-Type: application/json');
require_once '../config/db_connect.php';
require_once '../config/access_control.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_error(405, 'Method Not Allowed.');
}

$actor = get_current_actor($conn);
$id = trim($_POST['id'] ?? '');
$status = trim($_POST['status'] ?? 'Submitted');

if ($id === '') {
    api_error(400, 'Incident ID required.');
}

function srs_notification_id() {
    $hex = bin2hex(random_bytes(16));
    return substr($hex, 0, 8) . '-' . substr($hex, 8, 4) . '-' . substr($hex, 12, 4) . '-' . substr($hex, 16, 4) . '-' . substr($hex, 20);
}

function create_daily_note_notification($conn, $recipient_user_id, $actor_user_id, $incident_id, $body) {
    $id = srs_notification_id();
    $payload_json = json_encode(['related_id' => $incident_id]);
    $stmt = $conn->prepare(
        "INSERT INTO notifications (id, user_id, actor_user_id, type, title, body, payload_json)
         VALUES (?, ?, ?, 'daily_note', 'Nota Harian Baharu', ?, ?)"
    );
    if (!$stmt) {
        return;
    }
    $stmt->bind_param('sssss', $id, $recipient_user_id, $actor_user_id, $body, $payload_json);
    $stmt->execute();
    $stmt->close();
}

function notify_daily_note_recipients($conn, $incident) {
    $district_id = $incident['district_id'];
    $location_name = $incident['location_name'] ?? '';
    $patroller_name = $incident['full_name'] ?? 'Peronda';

    $stmt = $conn->prepare(
        "SELECT DISTINCT id
         FROM users
         WHERE account_status = 'active'
           AND role = 'ketua_krt'
           AND id != ?
           AND district_id = ?"
    );
    if (!$stmt) {
        return;
    }

    $stmt->bind_param('ss', $incident['user_id'], $district_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $body = $patroller_name . ' menghantar nota harian' . ($location_name ? ' di ' . $location_name : '') . '.';
    while ($row = $result->fetch_assoc()) {
        create_daily_note_notification($conn, $row['id'], $incident['user_id'], $incident['id'], $body);
    }
    $stmt->close();
}

$select = $conn->prepare(
    "SELECT i.id, i.user_id, i.status, i.location_name, i.district_id, i.zone_id, u.full_name
     FROM incidents i
     JOIN users u ON u.id = i.user_id
     WHERE i.id = ?
     LIMIT 1"
);
if (!$select) {
    api_error(500, 'Database preparation failed.');
}
$select->bind_param('s', $id);
$select->execute();
$incident = $select->get_result()->fetch_assoc();
$select->close();

if (!$incident) {
    api_error(404, 'Incident not found.');
}

if ($actor['role'] !== 'super_admin' && $actor['id'] !== $incident['user_id']) {
    api_error(403, 'You cannot update this incident.');
}

$new_status = strtolower($status);
$old_status = strtolower(trim($incident['status'] ?? 'Pending'));

if ($old_status === $new_status) {
    echo json_encode([
        "status" => "success",
        "message" => "Incident status already set.",
        "data" => ["notification_created" => false]
    ]);
    $conn->close();
    exit();
}

$should_notify = false;

if ($new_status === 'submitted') {
    $stmt = $conn->prepare("UPDATE incidents SET status = ? WHERE id = ? AND LOWER(status) IN ('pending', 'draft')");
} else {
    $stmt = $conn->prepare("UPDATE incidents SET status = ? WHERE id = ?");
}
if (!$stmt) {
    api_error(500, 'Database preparation failed.');
}
$stmt->bind_param("ss", $status, $id);

if (!$stmt->execute()) {
    $stmt->close();
    api_error(500, 'Database execution failed.');
}
$should_notify = $new_status === 'submitted' && $stmt->affected_rows > 0;
$stmt->close();

if ($should_notify) {
    notify_daily_note_recipients($conn, $incident);
}

echo json_encode([
    "status" => "success",
    "message" => "Incident status updated to $status.",
    "data" => ["notification_created" => $should_notify]
]);

$conn->close();
?>
