<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json; charset=UTF-8");

require_once '../config/db_connect.php';
require_once '../config/jwt_utils.php';

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($method !== 'GET') {
    http_response_code(405);
    echo json_encode(["status" => "error", "message" => "Method not allowed"]);
    exit();
}

// Enforce JWT check
$token = get_bearer_token();
if (!$token) {
    http_response_code(401);
    echo json_encode(["status" => "error", "message" => "Missing authentication token"]);
    exit();
}
$decoded = verify_jwt($token);
if (!$decoded) {
    http_response_code(401);
    echo json_encode(["status" => "error", "message" => "Invalid or expired token"]);
    exit();
}

$role = $decoded['role'] ?? '';

if (!in_array($role, ['ketua_peronda', 'ketua_krt', 'super_admin'], true)) {
    http_response_code(403);
    echo json_encode([
        "status" => "error",
        "message" => "Access denied. Equipment logs are for squad leaders and KRT/admin only."
    ]);
    exit;
}
try {
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
                el.attendance_id,
                MIN(el.borrowed_at) AS borrowed_at,
                CASE
                    WHEN a.return_status = 'completed' THEN MAX(el.returned_at)
                    ELSE NULL
                END AS returned_at,
                a.return_status,
                CASE
                    WHEN SUM(el.returned_at IS NULL) > 0 THEN 'Sedang Digunakan'
                    ELSE 'Telah Dipulangkan'
                END AS display_status,
                u.full_name as patroller_name,
                u.phone_number,
                sc.squad_id,
                sq.name AS squad_name,
                GROUP_CONCAT(ei.item_name ORDER BY ei.item_name SEPARATOR ', ') as items
              FROM equipment_logs el
              JOIN equipment_inventory ei ON el.equipment_id = ei.id
              JOIN attendance a ON el.attendance_id = a.id
              JOIN users u ON a.user_id = u.id
              LEFT JOIN schedules sc ON sc.id = a.schedule_id
              LEFT JOIN squads sq ON sq.id = sc.squad_id
              $where_sql
              GROUP BY el.attendance_id, a.return_status, u.full_name, u.phone_number, sc.squad_id, sq.name
              ORDER BY borrowed_at DESC
              LIMIT 150";

    $stmt = $conn->prepare($query);
    if (!$stmt) {
        throw new Exception($conn->error);
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
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Database error: " . $e->getMessage()]);
}

$conn->close();
?>
