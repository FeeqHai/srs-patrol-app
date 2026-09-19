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

$user_id = $decoded['user_id'];
$lat = (float)($_POST['latitude'] ?? 0);
$lon = (float)($_POST['longitude'] ?? 0);

if ($lat == 0 || $lon == 0) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "GPS location is required to end shift."]);
    exit();
}

function shift_qr_payload($mode, $schedule_id, $squad_id, $lat, $lon) {
    return 'SRS_SHIFT|' . strtoupper($mode) . '|' . $schedule_id . '|' . $squad_id . '|' . $lat . '|' . $lon . '|' . gmdate('c');
}

$conn->begin_transaction();

try {
    $leader_query = "SELECT sm.squad_id, sq.name AS squad_name
                     FROM squad_members sm
                     JOIN squads sq ON sq.id = sm.squad_id
                     WHERE sm.user_id = ? AND sm.role = 'leader'
                     LIMIT 1";
    $leader_stmt = $conn->prepare($leader_query);
    if (!$leader_stmt) {
        throw new Exception($conn->error);
    }
    $leader_stmt->bind_param("s", $user_id);
    $leader_stmt->execute();
    $leader = $leader_stmt->get_result()->fetch_assoc();
    $leader_stmt->close();

    if (!$leader) {
        http_response_code(403);
        echo json_encode(["status" => "error", "message" => "Anda bukan ketua bagi mana-mana skuad."]);
        $conn->rollback();
        exit();
    }

    $active_query = "SELECT a.id, a.schedule_id, sc.squad_id
                     FROM attendance a
                     JOIN schedules sc ON sc.id = a.schedule_id
                     WHERE a.user_id = ?
                       AND sc.squad_id = ?
                       AND a.clock_out_time IS NULL
                       AND a.clock_in_time IS NOT NULL
                       AND a.return_status IN ('active', 'pending_acknowledgement')
                     ORDER BY a.clock_in_time DESC
                     LIMIT 1
                     FOR UPDATE";
    $active_stmt = $conn->prepare($active_query);
    if (!$active_stmt) {
        throw new Exception($conn->error);
    }
    $leader_squad_id = $leader['squad_id'];
    $active_stmt->bind_param("ss", $user_id, $leader_squad_id);
    $active_stmt->execute();
    $active = $active_stmt->get_result()->fetch_assoc();
    $active_stmt->close();

    if ($active) {
        $complete = $conn->prepare("UPDATE attendance SET
            clock_out_time = COALESCE(clock_out_time, NOW()),
            clock_out_latitude = ?,
            clock_out_longitude = ?,
            return_status = 'completed',
            return_requested_at = COALESCE(return_requested_at, NOW()),
            return_checkpoint_id = ?,
            return_latitude = ?,
            return_longitude = ?,
            return_acknowledged_at = COALESCE(return_acknowledged_at, NOW()),
            return_acknowledged_by = ?
            WHERE id = ?");
        if (!$complete) {
            throw new Exception($conn->error);
        }
        $checkpoint = shift_qr_payload('OUT', $active['schedule_id'], $active['squad_id'], $lat, $lon);
        $active_attendance_id = $active['id'];
        $complete->bind_param("sssssss", $lat, $lon, $checkpoint, $lat, $lon, $user_id, $active_attendance_id);
        if (!$complete->execute()) {
            throw new Exception('Gagal menamatkan shif.');
        }
        $complete->close();

        $equipment = $conn->prepare("UPDATE equipment_logs SET returned_at = COALESCE(returned_at, NOW()) WHERE attendance_id = ?");
        if (!$equipment) {
            throw new Exception($conn->error);
        }
        $equipment->bind_param("s", $active_attendance_id);
        if (!$equipment->execute()) {
            throw new Exception('Gagal merekod pemulangan peralatan ketua.');
        }
        $equipment->close();

        $schedule_id = $active['schedule_id'];
        $squad_id = $active['squad_id'];
    } else {
        $today = date('Y-m-d');
        $schedule_query = "SELECT sc.id AS schedule_id, sc.squad_id
                           FROM attendance a
                           JOIN schedules sc ON sc.id = a.schedule_id
                           WHERE a.user_id = ?
                             AND sc.squad_id = ?
                             AND sc.shift_date = ?
                             AND a.clock_out_time IS NOT NULL
                           ORDER BY a.clock_out_time DESC
                           LIMIT 1";
        $schedule_stmt = $conn->prepare($schedule_query);
        if (!$schedule_stmt) {
            throw new Exception($conn->error);
        }
        $schedule_stmt->bind_param("sss", $user_id, $leader_squad_id, $today);
        $schedule_stmt->execute();
        $completed = $schedule_stmt->get_result()->fetch_assoc();
        $schedule_stmt->close();

        if (!$completed) {
            http_response_code(400);
            echo json_encode(["status" => "error", "message" => "Tiada shif aktif untuk ditamatkan."]);
            $conn->rollback();
            exit();
        }

        $schedule_id = $completed['schedule_id'];
        $squad_id = $completed['squad_id'];
    }

    $conn->commit();

    echo json_encode([
        "status" => "success",
        "message" => "Shif skuad telah ditamatkan.",
        "qr_payload" => shift_qr_payload('OUT', $schedule_id, $squad_id, $lat, $lon),
        "expires_in" => 60
    ]);
} catch (Exception $e) {
    $conn->rollback();
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Database error: " . $e->getMessage()]);
}

$conn->close();
?>
