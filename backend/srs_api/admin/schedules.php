<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json; charset=UTF-8");

require_once '../config/db_connect.php';
require_once '../config/access_control.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

function bind_values($stmt, $types, &$values) {
    if ($types === '') {
        return;
    }
    $refs = [];
    $refs[] = $types;
    foreach ($values as $key => &$value) {
        $refs[] = &$value;
    }
    call_user_func_array([$stmt, 'bind_param'], $refs);
}

function schedule_scope_clause($actor, &$types, &$params) {
    if ($actor['role'] === 'super_admin') {
        return '1 = 1';
    }

    if ($actor['role'] === 'ketua_krt') {
        $types .= 's';
        $params[] = $actor['district_id'];
        return 'sq.district_id = ?';
    }

    $types .= 's';
    $params[] = $actor['id'];
    return 'EXISTS (
        SELECT 1 FROM squad_members own_sm
        WHERE own_sm.squad_id = sq.id AND own_sm.user_id = ?
    )';
}

function squad_is_allowed($conn, $actor, $squad_id) {
    $types = 's';
    $params = [$squad_id];
    $scope_types = '';
    $scope_params = [];
    $scope = schedule_scope_clause($actor, $scope_types, $scope_params);
    $types .= $scope_types;
    $params = array_merge($params, $scope_params);

    $stmt = $conn->prepare("SELECT sq.id FROM squads sq WHERE sq.id = ? AND {$scope} LIMIT 1");
    if (!$stmt) {
        api_error(500, 'Unable to verify squad scope.');
    }
    bind_values($stmt, $types, $params);
    $stmt->execute();
    $allowed = $stmt->get_result()->num_rows > 0;
    $stmt->close();
    return $allowed;
}

function fetch_squad($conn, $squad_id) {
    $stmt = $conn->prepare("SELECT id, state_id, district_id, zone_id FROM squads WHERE id = ? LIMIT 1");
    if (!$stmt) {
        api_error(500, 'Unable to load squad location.');
    }
    $stmt->bind_param('s', $squad_id);
    $stmt->execute();
    $squad = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$squad) {
        api_error(404, 'Squad not found.');
    }
    return $squad;
}

function validate_location_path($conn, $state_id, $district_id, $zone_id) {
    $stmt = $conn->prepare(
        "SELECT z.id
         FROM zones z
         JOIN districts d ON d.id = z.district_id
         WHERE z.id = ? AND d.id = ? AND d.state_id = ?
         LIMIT 1"
    );
    if (!$stmt) {
        api_error(500, 'Unable to validate patrol zone.');
    }
    $stmt->bind_param('sss', $zone_id, $district_id, $state_id);
    $stmt->execute();
    $valid = $stmt->get_result()->num_rows > 0;
    $stmt->close();
    if (!$valid) {
        api_error(400, 'Invalid patrol location.');
    }
}

function schedule_timestamp($shift_date, $time) {
    return strtotime($shift_date . ' ' . $time);
}

function schedule_overlaps($conn, $squad_id, $shift_date, $start_time, $end_time) {
    if ($shift_date < date('Y-m-d')) {
        api_error(400, 'Cannot assign a schedule in the past.');
    }

    $candidate_start = schedule_timestamp($shift_date, $start_time);
    $candidate_end = schedule_timestamp($shift_date, $end_time);
    if ($candidate_start === false || $candidate_end === false) {
        api_error(400, 'Invalid schedule date or time.');
    }
    if ($candidate_end <= $candidate_start) {
        $candidate_end = strtotime('+1 day', $candidate_end);
    }

    $previous_date = date('Y-m-d', strtotime($shift_date . ' -1 day'));
    $next_date = date('Y-m-d', strtotime($shift_date . ' +1 day'));
    $stmt = $conn->prepare(
        "SELECT shift_date, start_time, end_time
         FROM schedules
         WHERE squad_id = ?
           AND shift_date IN (?, ?, ?)"
    );
    if (!$stmt) {
        api_error(500, 'Unable to verify schedule conflict.');
    }
    $stmt->bind_param('ssss', $squad_id, $previous_date, $shift_date, $next_date);
    $stmt->execute();
    $result = $stmt->get_result();

    while ($row = $result->fetch_assoc()) {
        $existing_start = schedule_timestamp($row['shift_date'], $row['start_time']);
        $existing_end = schedule_timestamp($row['shift_date'], $row['end_time']);
        if ($existing_start === false || $existing_end === false) {
            continue;
        }
        if ($existing_end <= $existing_start) {
            $existing_end = strtotime('+1 day', $existing_end);
        }
        if ($candidate_start < $existing_end && $candidate_end > $existing_start) {
            $stmt->close();
            return true;
        }
    }

    $stmt->close();
    return false;
}

$method = $_SERVER['REQUEST_METHOD'];
$actor = get_current_actor($conn);

try {
    if ($method === 'GET') {
        $types = '';
        $params = [];
        $where = [schedule_scope_clause($actor, $types, $params)];

        foreach ([
            'date' => 'sc.shift_date',
            'state_id' => 'COALESCE(sc.state_id, sq.state_id)',
            'district_id' => 'COALESCE(sc.district_id, sq.district_id)',
            'zone_id' => 'COALESCE(sc.zone_id, sq.zone_id)'
        ] as $query_key => $column) {
            $value = trim($_GET[$query_key] ?? '');
            if ($value !== '') {
                $where[] = "{$column} = ?";
                $types .= 's';
                $params[] = $value;
            }
        }

        $sql = "SELECT sc.id, sc.squad_id, sc.shift_date, sc.start_time, sc.end_time, sc.created_at,
                       sq.name AS squad_name,
                       COALESCE(sc.state_id, sq.state_id) AS state_id,
                       COALESCE(sc.district_id, sq.district_id) AS district_id,
                       COALESCE(sc.zone_id, sq.zone_id) AS zone_id,
                       st.name AS state_name, d.name AS district_name, z.name AS zone_name,
                       sq.state_id AS squad_state_id, sq.district_id AS squad_district_id, sq.zone_id AS squad_zone_id,
                       sst.name AS squad_state_name, sd.name AS squad_district_name, sz.name AS squad_zone_name,
                       COUNT(sm.user_id) AS member_count
                FROM schedules sc
                JOIN squads sq ON sc.squad_id = sq.id
                LEFT JOIN states st ON st.id = COALESCE(sc.state_id, sq.state_id)
                LEFT JOIN districts d ON d.id = COALESCE(sc.district_id, sq.district_id)
                LEFT JOIN zones z ON z.id = COALESCE(sc.zone_id, sq.zone_id)
                LEFT JOIN states sst ON sst.id = sq.state_id
                LEFT JOIN districts sd ON sd.id = sq.district_id
                LEFT JOIN zones sz ON sz.id = sq.zone_id
                LEFT JOIN squad_members sm ON sm.squad_id = sq.id
                WHERE " . implode(' AND ', $where) . "
                GROUP BY sc.id, sc.squad_id, sc.shift_date, sc.start_time, sc.end_time, sc.created_at,
                         sq.name, sc.state_id, sc.district_id, sc.zone_id, sq.state_id, sq.district_id, sq.zone_id,
                         st.name, d.name, z.name, sst.name, sd.name, sz.name
                ORDER BY sc.shift_date ASC, sc.start_time ASC";

        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            api_error(500, 'Unable to load schedules.');
        }
        bind_values($stmt, $types, $params);
        $stmt->execute();
        $result = $stmt->get_result();
        $schedules = $result->fetch_all(MYSQLI_ASSOC);
        $stmt->close();

        echo json_encode(['status' => 'success', 'message' => 'Schedules loaded.', 'data' => $schedules]);
    } elseif ($method === 'POST') {
        $json = file_get_contents('php://input');
        $data = json_decode($json, true);
        if (is_array($data)) {
            $_POST = array_merge($_POST, $data);
        }

        $action = $_POST['action'] ?? 'create_schedule';

        if ($action === 'create_schedule') {
            require_role($actor, ['super_admin', 'ketua_krt']);

            $squad_id = trim($_POST['squad_id'] ?? '');
            $shift_date = trim($_POST['shift_date'] ?? '');
            $start_time = trim($_POST['start_time'] ?? '');
            $end_time = trim($_POST['end_time'] ?? '');
            $squad = null;

            if ($squad_id === '' || $shift_date === '' || $start_time === '' || $end_time === '') {
                api_error(400, 'All fields are required.');
            }

            if (!squad_is_allowed($conn, $actor, $squad_id)) {
                api_error(403, 'You cannot assign schedules to this squad.');
            }
            $squad = fetch_squad($conn, $squad_id);

            $state_id = trim($_POST['state_id'] ?? '') ?: $squad['state_id'];
            $district_id = trim($_POST['district_id'] ?? '') ?: $squad['district_id'];
            $zone_id = trim($_POST['zone_id'] ?? '') ?: $squad['zone_id'];
            if ($state_id === '' || $district_id === '' || $zone_id === '') {
                api_error(400, 'Patrol location is required.');
            }
            validate_location_path($conn, $state_id, $district_id, $zone_id);
            if ($actor['role'] === 'ketua_krt' && $district_id !== $actor['district_id']) {
                api_error(403, 'You can only assign patrols within your district.');
            }

            if (schedule_overlaps($conn, $squad_id, $shift_date, $start_time, $end_time)) {
                api_error(409, 'This squad already has a schedule during that time.');
            }

            $id = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
                mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff),
                mt_rand(0, 0x0fff) | 0x4000, mt_rand(0, 0x3fff) | 0x8000,
                mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
            );

            $stmt = $conn->prepare("INSERT INTO schedules (id, squad_id, state_id, district_id, zone_id, shift_date, start_time, end_time) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
            if (!$stmt) {
                api_error(500, 'Unable to create schedule.');
            }
            $stmt->bind_param('ssssssss', $id, $squad_id, $state_id, $district_id, $zone_id, $shift_date, $start_time, $end_time);
            if (!$stmt->execute()) {
                $stmt->close();
                api_error(500, 'Unable to create schedule.');
            }
            $stmt->close();

            echo json_encode(['status' => 'success', 'message' => 'Schedule created successfully', 'schedule_id' => $id]);
        } elseif ($action === 'delete_schedule') {
            require_role($actor, ['super_admin', 'ketua_krt']);

            $schedule_id = trim($_POST['schedule_id'] ?? '');
            if ($schedule_id === '') {
                api_error(400, 'Schedule ID required.');
            }

            $types = 's';
            $params = [$schedule_id];
            $scope_types = '';
            $scope_params = [];
            $scope = schedule_scope_clause($actor, $scope_types, $scope_params);
            $types .= $scope_types;
            $params = array_merge($params, $scope_params);

            $stmt = $conn->prepare(
                "DELETE sc FROM schedules sc
                 JOIN squads sq ON sc.squad_id = sq.id
                 WHERE sc.id = ? AND {$scope}"
            );
            if (!$stmt) {
                api_error(500, 'Unable to delete schedule.');
            }
            bind_values($stmt, $types, $params);
            if (!$stmt->execute()) {
                $stmt->close();
                api_error(500, 'Unable to delete schedule.');
            }
            $stmt->close();

            echo json_encode(['status' => 'success', 'message' => 'Schedule deleted']);
        } else {
            api_error(400, 'Invalid action.');
        }
    } else {
        api_error(405, 'Invalid request method.');
    }
} catch(Exception $e) {
    api_error(500, 'Database error: ' . $e->getMessage());
}
?>
