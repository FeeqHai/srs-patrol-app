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

$attendance_query = "SELECT id FROM attendance WHERE user_id = ? AND clock_out_time IS NULL AND clock_in_time IS NOT NULL AND return_status = 'active' ORDER BY clock_in_time DESC LIMIT 1";
$attendance_stmt = $conn->prepare($attendance_query);
$attendance_stmt->bind_param("s", $decoded['user_id']);
$attendance_stmt->execute();
$attendance_result = $attendance_stmt->get_result();
if ($attendance_result->num_rows === 0) {
    echo json_encode(["status" => "error", "message" => "Tiada shif aktif yang boleh dipulangkan."]);
    exit();
}
$attendance_id = $attendance_result->fetch_assoc()['id'];
$attendance_stmt->close();

$equipment_query = "SELECT el.equipment_id AS id, ei.item_name
    FROM equipment_logs el
    JOIN equipment_inventory ei ON ei.id = el.equipment_id
    WHERE el.attendance_id = ? AND el.returned_at IS NULL
    ORDER BY ei.item_name";
$equipment_stmt = $conn->prepare($equipment_query);
$equipment_stmt->bind_param("s", $attendance_id);
$equipment_stmt->execute();
$equipment_result = $equipment_stmt->get_result();
$equipment = [];
while ($row = $equipment_result->fetch_assoc()) {
    $equipment[] = $row;
}

echo json_encode(["status" => "success", "attendance_id" => $attendance_id, "equipment" => $equipment]);
$equipment_stmt->close();
$conn->close();
?>
