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

$jwt_user_id = $decoded['user_id'];

// Support JSON POST body (Flutter often sends JSON)
$json = file_get_contents('php://input');
$data = json_decode($json, true);
if ($data) {
    $_POST = array_merge($_POST, $data);
}

$id = trim($_POST['id'] ?? '');
$user_id = $jwt_user_id; // Extract from JWT
$checkpoint_id = trim($_POST['checkpoint_id'] ?? '');
$lat = (float)($_POST['latitude'] ?? 0);
$lon = (float)($_POST['longitude'] ?? 0);
$equipment = $_POST['equipment'] ?? []; // Array of equipment_ids

if (empty($id) || empty($user_id) || empty($checkpoint_id) || $lat == 0 || $lon == 0) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Missing required attendance data or GPS."]);
    exit();
}

// 1. Fetch user details and their squad
$query = "SELECT u.district_zone, u.state_id, u.district_id, u.zone_id, sm.squad_id
          FROM users u
          LEFT JOIN squad_members sm ON u.id = sm.user_id
          WHERE u.id = ?";
$stmt = $conn->prepare($query);
$stmt->bind_param("s", $user_id);
$stmt->execute();
$res = $stmt->get_result();

if ($res->num_rows !== 1) {
    echo json_encode(["status" => "error", "message" => "User not found."]);
    exit();
}
$user = $res->fetch_assoc();
$district_zone = $user['district_zone'];
$state_id = $user['state_id'];
$district_id = $user['district_id'];
$zone_id = $user['zone_id'];
$squad_id = $user['squad_id']; // Might be null if they don't have a squad
$stmt->close();

// 2. Anti-cheat validation. Legacy four-part QR codes are treated as clock-in.
$is_shift_qr = false;
$qr_parts = explode('|', $checkpoint_id);
if (count($qr_parts) === 7 && $qr_parts[0] === 'SRS_SHIFT') {
    $is_shift_qr = true;
    $qr_mode = strtoupper($qr_parts[1]);
    $qr_schedule_id = $qr_parts[2];
    $qr_squad_id = $qr_parts[3];
    $admin_lat = (float)$qr_parts[4];
    $admin_lon = (float)$qr_parts[5];
    $qr_time_str = $qr_parts[6];

    if ($qr_mode !== 'IN') {
        echo json_encode(["status" => "error", "message" => "Sila gunakan QR Clock In untuk memulakan shif."]);
        exit();
    }

    if (!$squad_id || $squad_id !== $qr_squad_id) {
        echo json_encode(["status" => "error", "message" => "QR ini hanya untuk ahli skuad yang ditetapkan."]);
        exit();
    }

    $shift_stmt = $conn->prepare("SELECT sc.id, sc.state_id, sc.district_id, sc.zone_id
                                  FROM schedules sc
                                  WHERE sc.id = ? AND sc.squad_id = ?
                                  LIMIT 1");
    $shift_stmt->bind_param("ss", $qr_schedule_id, $qr_squad_id);
    $shift_stmt->execute();
    $shift = $shift_stmt->get_result()->fetch_assoc();
    $shift_stmt->close();
    if (!$shift) {
        echo json_encode(["status" => "error", "message" => "Jadual rondaan QR tidak sah."]);
        exit();
    }

    $leader_stmt = $conn->prepare("SELECT a.id
                                   FROM attendance a
                                   JOIN squad_members sm ON sm.user_id = a.user_id
                                   WHERE a.schedule_id = ?
                                     AND sm.squad_id = ?
                                     AND sm.role = 'leader'
                                     AND a.clock_out_time IS NULL
                                     AND a.return_status = 'active'
                                   LIMIT 1");
    $leader_stmt->bind_param("ss", $qr_schedule_id, $qr_squad_id);
    $leader_stmt->execute();
    $leader_active = $leader_stmt->get_result()->num_rows > 0;
    $leader_stmt->close();
    if (!$leader_active) {
        echo json_encode(["status" => "error", "message" => "Shif skuad belum dimulakan atau telah tamat."]);
        exit();
    }

    $schedule_id = $shift['id'];
    $state_id = $shift['state_id'] ?: $state_id;
    $district_id = $shift['district_id'] ?: $district_id;
    $zone_id = $shift['zone_id'] ?: $zone_id;
} elseif (count($qr_parts) === 5 && $qr_parts[0] === 'SRS_ATTENDANCE') {
    $qr_mode = strtoupper($qr_parts[1]);
    $admin_lat = (float)$qr_parts[2];
    $admin_lon = (float)$qr_parts[3];
    $qr_time_str = $qr_parts[4];
} elseif (count($qr_parts) === 4 && $qr_parts[0] === 'SRS_ATTENDANCE') {
    $qr_mode = 'IN';
    $admin_lat = (float)$qr_parts[1];
    $admin_lon = (float)$qr_parts[2];
    $qr_time_str = $qr_parts[3];
} else {
    echo json_encode(["status" => "error", "message" => "Unknown Checkpoint: Kod QR tidak sah."]);
    exit();
}

if ($qr_mode !== 'IN') {
    echo json_encode(["status" => "error", "message" => "Sila gunakan QR Clock In untuk memulakan shif."]);
    exit();
}

// A. Time Expiration Validation
$qr_time = strtotime($qr_time_str);
$current_time = time();
if (abs($current_time - $qr_time) > 65) {
    echo json_encode(["status" => "error", "message" => "Kod QR telah tamat tempoh."]);
    exit();
}

// B. GPS Distance Validation (Haversine Formula)
function calculateDistance($lat1, $lon1, $lat2, $lon2) {
    $earth_radius = 6371000;
    $dLat = deg2rad($lat2 - $lat1);
    $dLon = deg2rad($lon2 - $lon1);
    $a = sin($dLat/2) * sin($dLat/2) + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLon/2) * sin($dLon/2);
    return $earth_radius * (2 * atan2(sqrt($a), sqrt(1-$a)));
}

$distance = calculateDistance($lat, $lon, $admin_lat, $admin_lon);
if ($distance > 100) {
    echo json_encode(["status" => "error", "message" => "GPS dikesan terlalu jauh (".round($distance)."m) dari Admin."]);
    exit();
}

// A patroller cannot open another shift while one is still active or awaiting return acknowledgement.
$active_query = "SELECT id
                 FROM attendance
                 WHERE user_id = ?
                   AND clock_out_time IS NULL
                   AND clock_in_time IS NOT NULL
                   AND return_status IN ('active', 'pending_acknowledgement')
                 ORDER BY clock_in_time DESC
                 LIMIT 1";
$active_stmt = $conn->prepare($active_query);
$active_stmt->bind_param("s", $user_id);
$active_stmt->execute();
if ($active_stmt->get_result()->num_rows > 0) {
    $active_stmt->close();
    echo json_encode(["status" => "error", "message" => "Anda masih mempunyai shif aktif atau pemulangan menunggu pengesahan Ketua Peronda atau Ketua KRT."]);
    exit();
}
$active_stmt->close();

// 3. Find matching schedule for the squad today for legacy QR codes.
if (!isset($schedule_id)) {
    $schedule_id = null;
}
if (!$is_shift_qr && $squad_id) {
    // Check if there's a schedule for today
    $cur_date = date('Y-m-d');
    $sch_query = "SELECT id, state_id, district_id, zone_id FROM schedules WHERE squad_id = ? AND shift_date = ?";
    $sch_stmt = $conn->prepare($sch_query);
    $sch_stmt->bind_param("ss", $squad_id, $cur_date);
    $sch_stmt->execute();
    $sch_res = $sch_stmt->get_result();
    if ($sch_row = $sch_res->fetch_assoc()) {
        $schedule_id = $sch_row['id'];
        $state_id = $sch_row['state_id'] ?: $state_id;
        $district_id = $sch_row['district_id'] ?: $district_id;
        $zone_id = $sch_row['zone_id'] ?: $zone_id;
    }
    $sch_stmt->close();
}

// 4. Record attendance
$query = "INSERT INTO attendance (id, user_id, state_id, district_id, zone_id, schedule_id, checkpoint_id, latitude, longitude, clock_in_time, return_status)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), 'active')";
$stmt = $conn->prepare($query);
$stmt->bind_param("sssssssss", $id, $user_id, $state_id, $district_id, $zone_id, $schedule_id, $checkpoint_id, $lat, $lon);

if ($stmt->execute()) {
    // 5. Record Equipment selection (Lampiran 3)
    if (is_array($equipment) && count($equipment) > 0) {
        $eq_query = "INSERT INTO equipment_logs (id, attendance_id, equipment_id) VALUES (?, ?, ?)";
        $eq_stmt = $conn->prepare($eq_query);
        foreach ($equipment as $eq_id) {
            $log_id = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
                mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff),
                mt_rand(0, 0x0fff) | 0x4000, mt_rand(0, 0x3fff) | 0x8000,
                mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
            );
            $eq_stmt->bind_param("sss", $log_id, $id, $eq_id);
            $eq_stmt->execute();
        }
        $eq_stmt->close();
    }

    echo json_encode(["status" => "success", "message" => "Kehadiran direkodkan.", "attendance_id" => $id]);
} else {
    echo json_encode(["status" => "error", "message" => "Gagal merekodkan kehadiran."]);
}

$stmt->close();
$conn->close();
?>
