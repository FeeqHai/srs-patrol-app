<?php
header('Content-Type: application/json');
require_once '../config/db_connect.php';
require_once '../config/access_control.php';

$actor = get_current_actor($conn);

if ($actor['role'] === 'peronda') {
    echo json_encode(["status" => "success", "data" => []]);
    $conn->close();
    exit();
}

$where = [
    "i.category = 'Kecemasan'",
    "i.created_at >= NOW() - INTERVAL 30 MINUTE",
    "i.user_id != ?",
    "NOT EXISTS (SELECT 1 FROM sos_acknowledgements sa WHERE sa.incident_id = i.id AND sa.receiver_user_id = ?)",
];
$params = [$actor['id'], $actor['id']];
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
} elseif ($actor['role'] !== 'super_admin') {
    echo json_encode(["status" => "success", "data" => []]);
    $conn->close();
    exit();
}

$query = "SELECT i.*, u.full_name
          FROM incidents i
          JOIN users u ON u.id = i.user_id
          WHERE " . implode(' AND ', $where) . "
          ORDER BY i.created_at DESC";
$stmt = $conn->prepare($query);
if (!$stmt) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Database error."]);
    exit();
}
$stmt->bind_param($types, ...$params);

if (!$stmt) {
    echo json_encode(["status" => "error", "message" => "Database error: " . $conn->error]);
    exit();
}

$stmt->execute();
$result = $stmt->get_result();

$sos_list = [];
while ($row = $result->fetch_assoc()) {
    $sos_list[] = $row;
}

echo json_encode([
    "status" => "success",
    "data" => $sos_list
]);

$stmt->close();
$conn->close();
?>
