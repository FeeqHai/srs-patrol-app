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

if (($decoded['role'] ?? '') !== 'ketua_peronda') {
    http_response_code(403);
    echo json_encode(["status" => "error", "message" => "Ketua Peronda access required."]);
    exit();
}

$actor_id = $decoded['user_id'];
$requested_schedule_id = trim($_GET['schedule_id'] ?? '');

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
    $leader_stmt->bind_param("s", $actor_id);
    $leader_stmt->execute();
    $leader = $leader_stmt->get_result()->fetch_assoc();
    $leader_stmt->close();

    if (!$leader) {
        http_response_code(403);
        echo json_encode(["status" => "error", "message" => "Anda bukan ketua bagi mana-mana skuad."]);
        exit();
    }

    $leader_squad_id = $leader['squad_id'];
    $schedule = null;
    if ($requested_schedule_id !== '') {
        $schedule_stmt = $conn->prepare("SELECT id, squad_id, shift_date, start_time, end_time
                                         FROM schedules
                                         WHERE id = ? AND squad_id = ?
                                         LIMIT 1");
        if (!$schedule_stmt) {
            throw new Exception($conn->error);
        }
        $schedule_stmt->bind_param("ss", $requested_schedule_id, $leader_squad_id);
        $schedule_stmt->execute();
        $schedule = $schedule_stmt->get_result()->fetch_assoc();
        $schedule_stmt->close();
    }

    if (!$schedule) {
        $active_stmt = $conn->prepare("SELECT sc.id, sc.squad_id, sc.shift_date, sc.start_time, sc.end_time
                                       FROM attendance a
                                       JOIN schedules sc ON sc.id = a.schedule_id
                                       WHERE a.user_id = ?
                                         AND sc.squad_id = ?
                                         AND a.clock_in_time IS NOT NULL
                                         AND a.clock_out_time IS NULL
                                         AND a.return_status = 'active'
                                       ORDER BY a.clock_in_time DESC
                                       LIMIT 1");
        if (!$active_stmt) {
            throw new Exception($conn->error);
        }
        $active_stmt->bind_param("ss", $actor_id, $leader_squad_id);
        $active_stmt->execute();
        $schedule = $active_stmt->get_result()->fetch_assoc();
        $active_stmt->close();
    }

    if (!$schedule) {
        $today = date('Y-m-d');
        $today_stmt = $conn->prepare("SELECT id, squad_id, shift_date, start_time, end_time
                                      FROM schedules
                                      WHERE squad_id = ? AND shift_date = ?
                                      ORDER BY start_time ASC
                                      LIMIT 1");
        if (!$today_stmt) {
            throw new Exception($conn->error);
        }
        $today_stmt->bind_param("ss", $leader_squad_id, $today);
        $today_stmt->execute();
        $schedule = $today_stmt->get_result()->fetch_assoc();
        $today_stmt->close();
    }

    if (!$schedule) {
        echo json_encode([
            "status" => "success",
            "message" => "Tiada jadual rondaan untuk dinilai.",
            "squad" => $leader,
            "schedule" => null,
            "members" => []
        ]);
        exit();
    }

    $schedule_id = $schedule['id'];
    $member_query = "SELECT
            u.id AS user_id,
            u.full_name,
            u.phone_number,
            sm.role AS squad_role,
            a.id AS attendance_id,
            a.clock_in_time,
            a.clock_out_time,
            a.return_status,
            aa.status AS assessment_status,
            aa.notes AS assessment_notes,
            aa.acknowledged_at,
            aa.assessed_by
        FROM squad_members sm
        JOIN users u ON u.id = sm.user_id
        LEFT JOIN attendance a ON a.id = (
            SELECT a2.id
            FROM attendance a2
            WHERE a2.schedule_id = ? AND a2.user_id = u.id
            ORDER BY a2.clock_in_time DESC, a2.created_at DESC
            LIMIT 1
        )
        LEFT JOIN attendance_assessments aa
          ON aa.schedule_id = ? AND aa.user_id = u.id
        WHERE sm.squad_id = ?
        ORDER BY CASE WHEN sm.role = 'leader' THEN 0 ELSE 1 END, u.full_name ASC";
    $member_stmt = $conn->prepare($member_query);
    if (!$member_stmt) {
        throw new Exception($conn->error);
    }
    $member_stmt->bind_param("sss", $schedule_id, $schedule_id, $leader_squad_id);
    $member_stmt->execute();
    $result = $member_stmt->get_result();
    $members = [];
    while ($row = $result->fetch_assoc()) {
        $has_clock_in = !empty($row['clock_in_time']);
        $status = $row['assessment_status'];
        if (!$status) {
            $status = $has_clock_in ? 'present' : 'absent';
        }
        $row['effective_status'] = $status;
        $row['is_acknowledged'] = !empty($row['acknowledged_at']);
        $row['has_clock_in'] = $has_clock_in;
        $row['has_clock_out'] = !empty($row['clock_out_time']);
        $members[] = $row;
    }
    $member_stmt->close();

    echo json_encode([
        "status" => "success",
        "squad" => $leader,
        "schedule" => $schedule,
        "members" => $members
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Database error: " . $e->getMessage()]);
}

$conn->close();
?>
