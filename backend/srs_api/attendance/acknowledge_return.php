<?php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
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

$json = file_get_contents('php://input');
$data = json_decode($json, true);
if ($data) {
    $_POST = array_merge($_POST, $data);
}
$attendance_id = trim($_POST['attendance_id'] ?? '');
if ($attendance_id === '') {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Attendance ID is required."]);
    exit();
}

$conn->begin_transaction();
try {
    $attendance_query = "SELECT a.return_requested_at, a.return_latitude, a.return_longitude,
                a.district_id, sc.squad_id
        FROM attendance a
        LEFT JOIN schedules sc ON sc.id = a.schedule_id
        WHERE a.id = ?
          AND a.clock_out_time IS NULL
          AND a.clock_in_time IS NOT NULL
          AND a.return_status = 'pending_acknowledgement'
        FOR UPDATE";
    $attendance_stmt = $conn->prepare($attendance_query);
    $attendance_stmt->bind_param("s", $attendance_id);
    $attendance_stmt->execute();
    $attendance_result = $attendance_stmt->get_result();
    if ($attendance_result->num_rows === 0) {
        throw new Exception('Pemulangan tidak lagi menunggu pengesahan.');
    }
    $attendance = $attendance_result->fetch_assoc();
    $attendance_stmt->close();

    if ($role === 'ketua_peronda') {
        if (empty($attendance['squad_id'])) {
            throw new Exception('Pemulangan ini tiada skop skuad.');
        }
        $scope_stmt = $conn->prepare("SELECT 1 FROM squad_members WHERE squad_id = ? AND user_id = ? AND role = 'leader' LIMIT 1");
        if (!$scope_stmt) {
            throw new Exception('Gagal menyemak skop skuad.');
        }
        $attendance_squad_id = $attendance['squad_id'];
        $actor_user_id = $decoded['user_id'];
        $scope_stmt->bind_param("ss", $attendance_squad_id, $actor_user_id);
        $scope_stmt->execute();
        $allowed = $scope_stmt->get_result()->num_rows > 0;
        $scope_stmt->close();
        if (!$allowed) {
            http_response_code(403);
            throw new Exception('Anda hanya boleh mengesahkan pemulangan skuad anda.');
        }
    } elseif ($role === 'ketua_krt' && !empty($decoded['district_id']) && $attendance['district_id'] !== $decoded['district_id']) {
        http_response_code(403);
        throw new Exception('Anda hanya boleh mengesahkan pemulangan daerah anda.');
    }

    $complete_query = "UPDATE attendance SET
        clock_out_time = COALESCE(clock_out_time, NOW()),
        clock_out_latitude = return_latitude,
        clock_out_longitude = return_longitude,
        return_status = 'completed',
        return_acknowledged_at = NOW(),
        return_acknowledged_by = ?
        WHERE id = ?";
    $complete_stmt = $conn->prepare($complete_query);
    $actor_user_id = $decoded['user_id'];
    $complete_stmt->bind_param("ss", $actor_user_id, $attendance_id);
    if (!$complete_stmt->execute()) {
        throw new Exception('Gagal melengkapkan shif.');
    }
    $complete_stmt->close();

    $equipment_query = "UPDATE equipment_logs SET returned_at = NOW() WHERE attendance_id = ? AND returned_at IS NULL";
    $equipment_stmt = $conn->prepare($equipment_query);
    $equipment_stmt->bind_param("s", $attendance_id);
    if (!$equipment_stmt->execute()) {
        throw new Exception('Gagal merekod pemulangan peralatan.');
    }
    $equipment_stmt->close();

    $conn->commit();
    echo json_encode(["status" => "success", "message" => "Pemulangan peronda telah disahkan."]);
} catch (Exception $e) {
    $conn->rollback();
    if (http_response_code() < 400) {
        http_response_code(400);
    }
    echo json_encode(["status" => "error", "message" => $e->getMessage()]);
}

$conn->close();
?>
