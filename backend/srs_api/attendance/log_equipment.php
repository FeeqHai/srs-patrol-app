<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json; charset=UTF-8");

require_once '../config/db_connect.php';
require_once '../config/jwt_utils.php';

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($method !== 'POST') {
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
$decoded_token = verify_jwt($token);
if (!$decoded_token) {
    http_response_code(401);
    echo json_encode(["status" => "error", "message" => "Invalid or expired token"]);
    exit();
}

try {
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    if ($data) {
        $_POST = array_merge($_POST, $data);
    }

    $attendance_id = trim($_POST['attendance_id'] ?? '');
    $equipment = $_POST['equipment'] ?? [];

    // Dart sends json.encode(), so it might arrive as a JSON string
    if (is_string($equipment)) {
        $decoded = json_decode($equipment, true);
        if (is_array($decoded)) {
            $equipment = $decoded;
        } else {
            $equipment = [];
        }
    }

    if (empty($attendance_id)) {
        echo json_encode(["status" => "error", "message" => "Attendance ID is required."]);
        exit();
    }

    $attendance_query = "SELECT id
                         FROM attendance
                         WHERE id = ?
                           AND user_id = ?
                           AND clock_out_time IS NULL
                           AND clock_in_time IS NOT NULL
                           AND return_status = 'active'
                         LIMIT 1";
    $attendance_stmt = $conn->prepare($attendance_query);
    $attendance_stmt->bind_param("ss", $attendance_id, $decoded_token['user_id']);
    $attendance_stmt->execute();
    $attendance_result = $attendance_stmt->get_result();
    if ($attendance_result->num_rows === 0) {
        echo json_encode(["status" => "error", "message" => "Shif aktif tidak dijumpai untuk pengguna ini."]);
        exit();
    }
    $attendance_stmt->close();

    $existing_query = "SELECT COUNT(*) AS count FROM equipment_logs WHERE attendance_id = ?";
    $existing_stmt = $conn->prepare($existing_query);
    $existing_stmt->bind_param("s", $attendance_id);
    $existing_stmt->execute();
    $existing_count = (int)$existing_stmt->get_result()->fetch_assoc()['count'];
    $existing_stmt->close();
    if ($existing_count > 0) {
        echo json_encode(["status" => "error", "message" => "Peralatan untuk shif ini telah direkodkan."]);
        exit();
    }

    if (is_array($equipment) && count($equipment) > 0) {
        $equipment = array_values(array_unique(array_map('strval', $equipment)));
        $eq_query = "INSERT INTO equipment_logs (id, attendance_id, equipment_id) VALUES (?, ?, ?)";
        $eq_stmt = $conn->prepare($eq_query);
        foreach ($equipment as $eq_id) {
            $log_id = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
                mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff),
                mt_rand(0, 0x0fff) | 0x4000, mt_rand(0, 0x3fff) | 0x8000,
                mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
            );
            $eq_stmt->bind_param("sss", $log_id, $attendance_id, $eq_id);
            $eq_stmt->execute();
        }
        $eq_stmt->close();
    }

    echo json_encode(["status" => "success", "message" => "Equipment logged successfully."]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Database error: ' . $e->getMessage()]);
}
?>
