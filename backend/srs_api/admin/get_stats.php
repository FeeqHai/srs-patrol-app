<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json; charset=UTF-8");

require_once '../config/db_connect.php';
require_once '../config/access_control.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(["status" => "error", "message" => "Method not allowed"]);
    exit();
}

function get_note_counts_by_day($conn, $scope_sql, $types, $params, $days) {
    $sql = "SELECT DATE(CONVERT_TZ(i.created_at, '+00:00', '+08:00')) AS note_date, COUNT(*) AS count
            FROM incidents i
            WHERE i.category != 'Kecemasan'
              AND $scope_sql
              AND DATE(CONVERT_TZ(i.created_at, '+00:00', '+08:00')) >=
                  DATE(UTC_TIMESTAMP() + INTERVAL 8 HOUR) - INTERVAL " . ($days - 1) . " DAY
            GROUP BY DATE(CONVERT_TZ(i.created_at, '+00:00', '+08:00'))";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception('Unable to prepare note statistics.');
    }

    if ($types !== '') {
        $stmt->bind_param($types, ...$params);
    }
    $stmt->execute();
    $result = $stmt->get_result();

    $counts_by_date = [];
    while ($row = $result->fetch_assoc()) {
        $counts_by_date[$row['note_date']] = (int)$row['count'];
    }
    $stmt->close();

    $malaysia_now = new DateTimeImmutable('now', new DateTimeZone('Asia/Kuala_Lumpur'));
    $counts = [];
    for ($offset = $days - 1; $offset >= 0; $offset--) {
        $date = $malaysia_now->modify("-$offset days")->format('Y-m-d');
        $counts[] = $counts_by_date[$date] ?? 0;
    }

    return $counts;
}

try {
    $actor = get_current_actor($conn);
    $scope_sql = '1 = 0';
    $scope_types = '';
    $scope_params = [];

    if ($actor['role'] === 'peronda') {
        $scope_sql = 'i.user_id = ?';
        $scope_types = 's';
        $scope_params[] = $actor['id'];
    } elseif ($actor['role'] === 'ketua_peronda') {
        $scope_sql = "EXISTS (
            SELECT 1
            FROM squad_members target_member
            JOIN squad_members leader_member ON leader_member.squad_id = target_member.squad_id
            WHERE target_member.user_id = i.user_id
              AND leader_member.user_id = ?
        )";
        $scope_types = 's';
        $scope_params[] = $actor['id'];
    } elseif ($actor['role'] === 'ketua_krt' && $actor['district_id'] !== null) {
        $scope_sql = "i.district_id = ? AND LOWER(COALESCE(i.status, '')) = 'submitted'";
        $scope_types = 's';
        $scope_params[] = $actor['district_id'];
    } elseif ($actor['role'] === 'super_admin') {
        $scope_sql = "LOWER(COALESCE(i.status, '')) = 'submitted'";
    }

    $weekly_note_counts = get_note_counts_by_day(
        $conn,
        $scope_sql,
        $scope_types,
        $scope_params,
        7
    );
    $monthly_note_counts = get_note_counts_by_day(
        $conn,
        $scope_sql,
        $scope_types,
        $scope_params,
        30
    );

    // Kept for the existing analytics screen, which still reads these keys.
    $patroller_res = $conn->query("SELECT COUNT(*) AS count FROM users WHERE role IN ('peronda', 'ketua_peronda')");
    $total_patrollers = (int)$patroller_res->fetch_assoc()['count'];
    $active_res = $conn->query("SELECT COUNT(*) AS count FROM attendance WHERE clock_out_time IS NULL AND clock_in_time IS NOT NULL AND return_status = 'active'");
    $active_shifts = (int)$active_res->fetch_assoc()['count'];
    $pending_res = $conn->query("SELECT COUNT(*) AS count FROM attendance WHERE clock_out_time IS NULL AND clock_in_time IS NOT NULL AND return_status = 'pending_acknowledgement'");
    $pending_returns = (int)$pending_res->fetch_assoc()['count'];

    echo json_encode([
        "status" => "success",
        "data" => [
            "total_patrollers" => $total_patrollers,
            "active_shifts" => $active_shifts,
            "pending_returns" => $pending_returns,
            "weekly_incidents" => array_sum($weekly_note_counts),
            "weekly_note_counts" => $weekly_note_counts,
            "monthly_note_counts" => $monthly_note_counts
        ]
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Unable to load dashboard statistics."]);
}
?>
