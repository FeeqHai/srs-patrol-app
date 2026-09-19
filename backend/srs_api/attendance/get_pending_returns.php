<?php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

require_once '../config/db_connect.php';
require_once '../config/jwt_utils.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit();
}

$token = get_bearer_token();
$decoded = $token ? verify_jwt($token) : false;
if (!$decoded) {
    http_response_code(401);
    echo json_encode(["status" => "error", "message" => "Invalid or expired token"]);
    exit();
}
$role = $decoded['role'] ?? '';
if (!in_array($role, ['ketua_peronda', 'ketua_krt', 'super_admin'], true)) {
    http_response_code(403);
    echo json_encode(["status" => "error", "message" => "Return acknowledgement access required."]);
    exit();
}

$where = [];
$types = '';
$params = [];

if ($role === 'ketua_peronda') {
    $where[] = "EXISTS (
        SELECT 1
        FROM squad_members own_sm
        WHERE own_sm.squad_id = sc.squad_id
          AND own_sm.user_id = ?
          AND own_sm.role = 'leader'
    )";
    $types .= 's';
    $params[] = $decoded['user_id'];
} elseif ($role === 'ketua_krt') {
    $where[] = "a.district_id = ?";
    $types .= 's';
    $params[] = $decoded['district_id'] ?? '';
}

$where_sql = count($where) > 0 ? ' AND ' . implode(' AND ', $where) : '';

$query = "SELECT a.id, a.return_requested_at, a.clock_in_time, u.full_name,
                 sc.squad_id, sq.name AS squad_name
    FROM attendance a
    JOIN users u ON u.id = a.user_id
    LEFT JOIN schedules sc ON sc.id = a.schedule_id
    LEFT JOIN squads sq ON sq.id = sc.squad_id
    WHERE a.clock_out_time IS NULL
      AND a.clock_in_time IS NOT NULL
      AND a.return_status = 'pending_acknowledgement'
      $where_sql
    ORDER BY a.return_requested_at ASC";
$stmt = $conn->prepare($query);
if (!$stmt) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Database error: " . $conn->error]);
    exit();
}
if ($types !== '') {
    $param0 = $params[0];
    $stmt->bind_param($types, $param0);
}
$stmt->execute();
$result = $stmt->get_result();
$returns = [];
while ($return = $result->fetch_assoc()) {
    $equipment_query = "SELECT ei.item_name FROM equipment_logs el
        JOIN equipment_inventory ei ON ei.id = el.equipment_id
        WHERE el.attendance_id = ? AND el.returned_at IS NULL
        ORDER BY ei.item_name";
    $equipment_stmt = $conn->prepare($equipment_query);
    $return_id = $return['id'];
    $equipment_stmt->bind_param("s", $return_id);
    $equipment_stmt->execute();
    $equipment_result = $equipment_stmt->get_result();
    $equipment = [];
    while ($item = $equipment_result->fetch_assoc()) {
        $equipment[] = $item['item_name'];
    }
    $equipment_stmt->close();
    $return['equipment'] = $equipment;
    $returns[] = $return;
}
$stmt->close();

echo json_encode(["status" => "success", "data" => $returns]);
$conn->close();
?>
