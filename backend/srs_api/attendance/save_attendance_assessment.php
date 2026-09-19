<?php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

require_once '../config/db_connect.php';
require_once '../config/jwt_utils.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
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

if (($decoded['role'] ?? '') !== 'ketua_peronda') {
    http_response_code(403);
    echo json_encode(["status" => "error", "message" => "Ketua Peronda access required."]);
    exit();
}

$json = file_get_contents('php://input');
$data = json_decode($json, true);
if ($data) {
    $_POST = array_merge($_POST, $data);
}

$schedule_id = trim($_POST['schedule_id'] ?? '');
$user_id = trim($_POST['user_id'] ?? '');
$status = trim($_POST['status'] ?? '');
$notes = trim($_POST['notes'] ?? '');
$actor_id = $decoded['user_id'];
$allowed_statuses = ['present', 'late', 'absent', 'excused'];

if ($schedule_id === '' || $user_id === '' || !in_array($status, $allowed_statuses, true)) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Invalid assessment data."]);
    exit();
}

if (strlen($notes) > 500) {
    $notes = substr($notes, 0, 500);
}

function uuid_v4() {
    return sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000,
        mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );
}

try {
    $scope_query = "SELECT sc.squad_id
                    FROM schedules sc
                    JOIN squad_members leader_sm
                      ON leader_sm.squad_id = sc.squad_id
                     AND leader_sm.user_id = ?
                     AND leader_sm.role = 'leader'
                    WHERE sc.id = ?
                    LIMIT 1";
    $scope_stmt = $conn->prepare($scope_query);
    if (!$scope_stmt) {
        throw new Exception($conn->error);
    }
    $scope_stmt->bind_param("ss", $actor_id, $schedule_id);
    $scope_stmt->execute();
    $scope = $scope_stmt->get_result()->fetch_assoc();
    $scope_stmt->close();

    if (!$scope) {
        http_response_code(403);
        echo json_encode(["status" => "error", "message" => "Anda hanya boleh menilai kehadiran skuad anda."]);
        exit();
    }

    $squad_id = $scope['squad_id'];
    $member_stmt = $conn->prepare("SELECT 1 FROM squad_members WHERE squad_id = ? AND user_id = ? LIMIT 1");
    if (!$member_stmt) {
        throw new Exception($conn->error);
    }
    $member_stmt->bind_param("ss", $squad_id, $user_id);
    $member_stmt->execute();
    $is_member = $member_stmt->get_result()->num_rows > 0;
    $member_stmt->close();

    if (!$is_member) {
        http_response_code(403);
        echo json_encode(["status" => "error", "message" => "Ahli ini bukan dalam skuad anda."]);
        exit();
    }

    $id = uuid_v4();
    $save_query = "INSERT INTO attendance_assessments
            (id, schedule_id, user_id, assessed_by, status, notes, acknowledged_at)
        VALUES (?, ?, ?, ?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE
            assessed_by = VALUES(assessed_by),
            status = VALUES(status),
            notes = VALUES(notes),
            acknowledged_at = NOW()";
    $save_stmt = $conn->prepare($save_query);
    if (!$save_stmt) {
        throw new Exception($conn->error);
    }
    $save_stmt->bind_param("ssssss", $id, $schedule_id, $user_id, $actor_id, $status, $notes);
    if (!$save_stmt->execute()) {
        throw new Exception('Gagal menyimpan penilaian kehadiran.');
    }
    $save_stmt->close();

    echo json_encode(["status" => "success", "message" => "Penilaian kehadiran telah disahkan."]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Database error: " . $e->getMessage()]);
}

$conn->close();
?>
