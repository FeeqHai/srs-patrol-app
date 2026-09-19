<?php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

require_once '../config/db_connect.php';
require_once '../config/jwt_utils.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(["status" => "error", "message" => "Invalid request method."]);
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
    echo json_encode(["status" => "error", "message" => "Attendance log access denied."]);
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

$where_sql = count($where) > 0 ? 'WHERE ' . implode(' AND ', $where) : '';

$query = "SELECT
            a.id,
            a.id AS attendance_id,
            a.user_id,
            a.state_id,
            a.district_id,
            a.zone_id,
            a.schedule_id,
            a.checkpoint_id,
            a.clock_in_time,
            a.clock_out_time,
            a.return_status,
            a.return_requested_at,
            a.return_acknowledged_at,
            u.full_name AS patroller_name,
            u.ic_number,
            u.phone_number,
            sc.squad_id,
            sq.name AS squad_name,
            st.name AS state_name,
            d.name AS district_name,
            z.name AS zone_name
          FROM attendance a
          JOIN users u ON u.id = a.user_id
          LEFT JOIN schedules sc ON sc.id = a.schedule_id
          LEFT JOIN squads sq ON sq.id = sc.squad_id
          LEFT JOIN states st ON st.id = a.state_id
          LEFT JOIN districts d ON d.id = a.district_id
          LEFT JOIN zones z ON z.id = a.zone_id
          $where_sql
          ORDER BY a.clock_in_time DESC, a.created_at DESC
          LIMIT 300";

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
$logs = [];
while ($row = $result->fetch_assoc()) {
    $logs[] = $row;
}
$stmt->close();

echo json_encode(["status" => "success", "data" => $logs]);
$conn->close();
?>
