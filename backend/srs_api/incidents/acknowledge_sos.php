<?php
header('Content-Type: application/json');
require_once '../config/db_connect.php';
require_once '../config/access_control.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_error(405, 'Method not allowed.');
}

$actor = get_current_actor($conn);
if (!in_array($actor['role'], ['ketua_peronda', 'ketua_krt', 'super_admin'], true)) {
    api_error(403, 'You are not an SOS recipient.');
}

$data = json_decode(file_get_contents('php://input'), true);
$incident_id = trim(($data['incident_id'] ?? $_POST['incident_id'] ?? ''));
if ($incident_id === '') {
    api_error(400, 'SOS incident ID is required.');
}

$where = ["i.id = ?", "i.category = 'Kecemasan'", "i.user_id != ?"];
$params = [$incident_id, $actor['id']];
$types = 'ss';

if ($actor['role'] === 'ketua_peronda') {
    $where[] = "EXISTS (
        SELECT 1
        FROM squad_members sender_member
        JOIN squad_members leader_member ON leader_member.squad_id = sender_member.squad_id
        WHERE sender_member.user_id = i.user_id AND leader_member.user_id = ?
    )";
    $params[] = $actor['id'];
    $types .= 's';
} elseif ($actor['role'] === 'ketua_krt') {
    $where[] = 'i.district_id = ?';
    $params[] = $actor['district_id'];
    $types .= 's';
}

$incident_query = 'SELECT i.id FROM incidents i WHERE ' . implode(' AND ', $where);
$incident_stmt = $conn->prepare($incident_query);
if (!$incident_stmt) {
    api_error(500, 'Unable to verify SOS alert.');
}
$incident_stmt->bind_param($types, ...$params);
$incident_stmt->execute();
if ($incident_stmt->get_result()->num_rows !== 1) {
    $incident_stmt->close();
    api_error(403, 'SOS alert is not available to this user.');
}
$incident_stmt->close();

$ack_stmt = $conn->prepare(
    'INSERT INTO sos_acknowledgements (id, incident_id, receiver_user_id) VALUES (UUID(), ?, ?)
     ON DUPLICATE KEY UPDATE acknowledged_at = CURRENT_TIMESTAMP'
);
if (!$ack_stmt) {
    api_error(500, 'Unable to acknowledge SOS alert.');
}
$ack_stmt->bind_param('ss', $incident_id, $actor['id']);
if (!$ack_stmt->execute()) {
    $ack_stmt->close();
    api_error(500, 'Unable to acknowledge SOS alert.');
}

$ack_stmt->close();
$conn->close();
echo json_encode(["status" => "success"]);
?>
