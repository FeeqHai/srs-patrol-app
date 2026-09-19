<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json; charset=UTF-8");

require_once '../config/db_connect.php';
require_once '../config/jwt_utils.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
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

try {
    // Query active patrollers with their squad name (if any) and clock in time.
    $query = "SELECT a.id as attendance_id, a.clock_in_time, a.latitude, a.longitude,
                     a.return_status, a.return_requested_at,
                     u.full_name, u.phone_number, s.name as squad_name
              FROM attendance a
              JOIN users u ON a.user_id = u.id
              LEFT JOIN squad_members sm ON u.id = sm.user_id
              LEFT JOIN squads s ON sm.squad_id = s.id
              WHERE a.clock_out_time IS NULL
                AND a.clock_in_time IS NOT NULL
                AND a.return_status = 'active'
              ORDER BY a.clock_in_time DESC";

    $result = $conn->query($query);
    $active = [];
    $seen_patrollers = [];
    while ($row = $result->fetch_assoc()) {
        $patroller_name = $row['full_name'];
        if (in_array($patroller_name, $seen_patrollers)) {
            continue;
        }
        $seen_patrollers[] = $patroller_name;

        $att_id = $row['attendance_id'];

        // Fetch checked-out equipment for this active shift.
        $eq_query = "SELECT ei.item_name FROM equipment_logs el JOIN equipment_inventory ei ON el.equipment_id = ei.id WHERE el.attendance_id = ? AND el.returned_at IS NULL";
        $eq_stmt = $conn->prepare($eq_query);
        $eq_stmt->bind_param("s", $att_id);
        $eq_stmt->execute();
        $eq_res = $eq_stmt->get_result();
        $equipment = [];
        while ($eq_row = $eq_res->fetch_assoc()) {
            $equipment[] = $eq_row['item_name'];
        }
        $eq_stmt->close();

        $row['equipment'] = $equipment;
        $active[] = $row;
    }

    echo json_encode([
        "status" => "success",
        "data" => $active
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => $e->getMessage()]);
}
?>
