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

$user_id = $decoded['user_id'];

try {
    $query = "SELECT id, clock_in_time, checkpoint_id, return_status, schedule_id
              FROM attendance
              WHERE user_id = ?
                AND clock_out_time IS NULL
                AND clock_in_time IS NOT NULL
                AND return_status IN ('active', 'pending_acknowledgement')
              ORDER BY clock_in_time DESC
              LIMIT 1";
    $stmt = $conn->prepare($query);
    if (!$stmt) {
        throw new Exception($conn->error);
    }
    $stmt->bind_param("s", $user_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 1) {
        $row = $result->fetch_assoc();
        $attendance_id = $row['id'];

        // Fetch borrowed equipment that has not been acknowledged as returned.
        $eq_query = "SELECT el.equipment_id AS id, ei.item_name
                     FROM equipment_logs el
                     JOIN equipment_inventory ei ON el.equipment_id = ei.id
                     WHERE el.attendance_id = ? AND el.returned_at IS NULL
                     ORDER BY ei.item_name";
        $eq_stmt = $conn->prepare($eq_query);
        $eq_stmt->bind_param("s", $attendance_id);
        $eq_stmt->execute();
        $eq_res = $eq_stmt->get_result();
        $equipment = [];
        while ($eq_row = $eq_res->fetch_assoc()) {
            $equipment[] = [
                "id" => $eq_row['id'],
                "item_name" => $eq_row['item_name']
            ];
        }
        $eq_stmt->close();

        echo json_encode([
            "status" => "success",
            "has_active_shift" => true,
            "attendance_id" => $attendance_id,
            "checkpoint_id" => $row['checkpoint_id'],
            "schedule_id" => $row['schedule_id'],
            "clock_in_time" => $row['clock_in_time'],
            "return_status" => $row['return_status'],
            "borrowed_equipment" => $equipment,
            "pending_acknowledgement" => $row['return_status'] === 'pending_acknowledgement'
                ? "Pemulangan anda sedang menunggu pengesahan Ketua Peronda atau Ketua KRT."
                : null,
            "data" => [
                "attendance_id" => $attendance_id,
                "clock_in_time" => $row['clock_in_time'],
                "checkpoint_id" => $row['checkpoint_id'],
                "schedule_id" => $row['schedule_id'],
                "return_status" => $row['return_status'],
                "borrowed_equipment" => $equipment,
                "pending_acknowledgement" => $row['return_status'] === 'pending_acknowledgement'
                    ? "Pemulangan anda sedang menunggu pengesahan Ketua Peronda atau Ketua KRT."
                    : null
            ]
        ]);
    } else {
        echo json_encode([
            "status" => "success",
            "has_active_shift" => false
        ]);
    }
    $stmt->close();
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Database error: " . $e->getMessage()]);
}

$conn->close();
?>
