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
    echo json_encode(["status" => "error", "message" => "GPS location is required to start shift."]);
    exit();
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

function shift_qr_payload($mode, $schedule_id, $squad_id, $lat, $lon) {
    return 'SRS_SHIFT|' . strtoupper($mode) . '|' . $schedule_id . '|' . $squad_id . '|' . $lat . '|' . $lon . '|' . gmdate('c');
}

$conn->begin_transaction();

try {
    $squad_query = "SELECT sq.id AS squad_id, sq.name AS squad_name,
                           sq.state_id AS squad_state_id, sq.district_id AS squad_district_id, sq.zone_id AS squad_zone_id
                    FROM squad_members sm
                    JOIN squads sq ON sq.id = sm.squad_id
                    WHERE sm.user_id = ? AND sm.role = 'leader'
                    LIMIT 1";
    $squad_stmt = $conn->prepare($squad_query);
    if (!$squad_stmt) {
        throw new Exception($conn->error);
    }
    $squad_stmt->bind_param("s", $user_id);
    $squad_stmt->execute();
    $squad = $squad_stmt->get_result()->fetch_assoc();
    $squad_stmt->close();

    if (!$squad) {
        http_response_code(403);
        echo json_encode(["status" => "error", "message" => "Anda bukan ketua bagi mana-mana skuad."]);
        $conn->rollback();
        exit();
    }

    $today = date('Y-m-d');
    $schedule_query = "SELECT id, squad_id, state_id, district_id, zone_id, shift_date, start_time, end_time
                       FROM schedules
                       WHERE squad_id = ? AND shift_date = ?
                       ORDER BY start_time ASC
                       LIMIT 1";
    $schedule_stmt = $conn->prepare($schedule_query);
    if (!$schedule_stmt) {
        throw new Exception($conn->error);
    }
    $squad_id_value = $squad['squad_id'];
    $schedule_stmt->bind_param("ss", $squad_id_value, $today);
    $schedule_stmt->execute();
    $schedule = $schedule_stmt->get_result()->fetch_assoc();
    $schedule_stmt->close();

    if (!$schedule) {
        http_response_code(404);
        echo json_encode(["status" => "error", "message" => "Tiada jadual rondaan untuk skuad anda hari ini."]);
        $conn->rollback();
        exit();
    }

    $active_query = "SELECT id, schedule_id
                     FROM attendance
                     WHERE user_id = ?
                       AND clock_out_time IS NULL
                       AND clock_in_time IS NOT NULL
                       AND return_status IN ('active', 'pending_acknowledgement')
                     ORDER BY clock_in_time DESC
                     LIMIT 1
                     FOR UPDATE";
    $active_stmt = $conn->prepare($active_query);
    if (!$active_stmt) {
        throw new Exception($conn->error);
    }
    $active_stmt->bind_param("s", $user_id);
    $active_stmt->execute();
    $active = $active_stmt->get_result()->fetch_assoc();
    $active_stmt->close();

    if ($active && $active['schedule_id'] !== $schedule['id']) {
        http_response_code(409);
        echo json_encode(["status" => "error", "message" => "Anda masih mempunyai shif aktif lain."]);
        $conn->rollback();
        exit();
    }

    if ($active) {
        $attendance_id = $active['id'];
    } else {
        $attendance_id = uuid_v4();
        $checkpoint = 'SRS_SHIFT|LEADER_START|' . $schedule['id'] . '|' . $squad['squad_id'] . '|' . gmdate('c');
        $state_id = $schedule['state_id'] ?: $squad['squad_state_id'];
        $district_id = $schedule['district_id'] ?: $squad['squad_district_id'];
        $zone_id = $schedule['zone_id'] ?: $squad['squad_zone_id'];

        $schedule_id_value = $schedule['id'];
        $insert = $conn->prepare("INSERT INTO attendance
            (id, user_id, state_id, district_id, zone_id, schedule_id, checkpoint_id, latitude, longitude, clock_in_time, return_status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), 'active')");
        if (!$insert) {
            throw new Exception($conn->error);
        }
        $insert->bind_param("sssssssss", $attendance_id, $user_id, $state_id, $district_id, $zone_id, $schedule_id_value, $checkpoint, $lat, $lon);
        if (!$insert->execute()) {
            throw new Exception('Gagal memulakan shif.');
        }
        $insert->close();
    }

    $conn->commit();

    echo json_encode([
        "status" => "success",
        "message" => "Shif skuad telah dimulakan.",
        "attendance_id" => $attendance_id,
        "qr_payload" => shift_qr_payload('IN', $schedule['id'], $squad['squad_id'], $lat, $lon),
        "expires_in" => 60,
        "squad" => $squad,
        "schedule" => $schedule
    ]);
} catch (Exception $e) {
    $conn->rollback();
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Database error: " . $e->getMessage()]);
}

$conn->close();
?>
