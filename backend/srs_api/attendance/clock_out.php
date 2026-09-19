<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json; charset=UTF-8");

require_once '../config/db_connect.php';
require_once '../config/jwt_utils.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["status" => "error", "message" => "Method not allowed"]);
    exit();
}

$token = get_bearer_token();
$decoded = $token ? verify_jwt($token) : false;
if (!$decoded) {
    http_response_code(401);
    echo json_encode(["status" => "error", "message" => "Invalid or expired token"]);
    exit();
}

$json = file_get_contents('php://input');
$data = json_decode($json, true);
if ($data) {
    $_POST = array_merge($_POST, $data);
}

$user_id = $decoded['user_id'];
$checkpoint_id = trim($_POST['checkpoint_id'] ?? '');
$lat = (float)($_POST['latitude'] ?? 0);
$lon = (float)($_POST['longitude'] ?? 0);
$returned_equipment = $_POST['returned_equipment'] ?? [];

if (is_string($returned_equipment)) {
    $returned_equipment = json_decode($returned_equipment, true);
}
if (!is_array($returned_equipment)) {
    $returned_equipment = [];
}
$returned_equipment = array_values(array_unique(array_map('strval', $returned_equipment)));

if ($checkpoint_id === '' || $lat == 0 || $lon == 0) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Missing QR clock-out data or GPS."]);
    exit();
}

$qr_parts = explode('|', $checkpoint_id);
$is_shift_qr = false;
$qr_schedule_id = null;
$qr_squad_id = null;

if (count($qr_parts) === 7 && $qr_parts[0] === 'SRS_SHIFT' && strtoupper($qr_parts[1]) === 'OUT') {
    $is_shift_qr = true;
    $qr_schedule_id = $qr_parts[2];
    $qr_squad_id = $qr_parts[3];
    $post_lat = (float)$qr_parts[4];
    $post_lon = (float)$qr_parts[5];
    $qr_time = strtotime($qr_parts[6]);

    $member_stmt = $conn->prepare("SELECT 1 FROM squad_members WHERE user_id = ? AND squad_id = ? LIMIT 1");
    $member_stmt->bind_param("ss", $user_id, $qr_squad_id);
    $member_stmt->execute();
    $is_member = $member_stmt->get_result()->num_rows > 0;
    $member_stmt->close();
    if (!$is_member) {
        echo json_encode(["status" => "error", "message" => "QR ini hanya untuk ahli skuad yang ditetapkan."]);
        exit();
    }
} elseif (count($qr_parts) === 5 && $qr_parts[0] === 'SRS_ATTENDANCE' && strtoupper($qr_parts[1]) === 'OUT') {
    $post_lat = (float)$qr_parts[2];
    $post_lon = (float)$qr_parts[3];
    $qr_time = strtotime($qr_parts[4]);
} else {
    echo json_encode(["status" => "error", "message" => "Sila gunakan QR Clock Out yang sah."]);
    exit();
}

if (!$qr_time || abs(time() - $qr_time) > 65) {
    echo json_encode(["status" => "error", "message" => "Kod QR telah tamat tempoh."]);
    exit();
}

function calculate_distance($lat1, $lon1, $lat2, $lon2) {
    $earth_radius = 6371000;
    $dLat = deg2rad($lat2 - $lat1);
    $dLon = deg2rad($lon2 - $lon1);
    $a = sin($dLat / 2) * sin($dLat / 2) + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLon / 2) * sin($dLon / 2);
    return $earth_radius * (2 * atan2(sqrt($a), sqrt(1 - $a)));
}

$distance = calculate_distance($lat, $lon, $post_lat, $post_lon);
if ($distance > 100) {
    echo json_encode(["status" => "error", "message" => "GPS dikesan terlalu jauh daripada Pos Utama."]);
    exit();
}

$attendance_query = "SELECT id, return_status, schedule_id
                     FROM attendance
                     WHERE user_id = ?
                       AND clock_out_time IS NULL
                       AND clock_in_time IS NOT NULL
                       AND return_status IN ('active', 'pending_acknowledgement')
                     ORDER BY clock_in_time DESC
                     LIMIT 1";
$attendance_stmt = $conn->prepare($attendance_query);
$attendance_stmt->bind_param("s", $user_id);
$attendance_stmt->execute();
$attendance_result = $attendance_stmt->get_result();
if ($attendance_result->num_rows === 0) {
    echo json_encode(["status" => "error", "message" => "Tiada shif aktif dijumpai."]);
    exit();
}
$attendance = $attendance_result->fetch_assoc();
$attendance_stmt->close();

if ($is_shift_qr && $attendance['schedule_id'] !== $qr_schedule_id) {
    echo json_encode(["status" => "error", "message" => "QR Clock Out ini bukan untuk shif aktif anda."]);
    exit();
}

if ($attendance['return_status'] !== 'active') {
    echo json_encode(["status" => "error", "message" => "Pemulangan anda telah dihantar dan menunggu pengesahan Ketua Peronda atau Ketua KRT."]);
    exit();
}

$equipment_query = "SELECT equipment_id FROM equipment_logs WHERE attendance_id = ? AND returned_at IS NULL ORDER BY equipment_id";
$equipment_stmt = $conn->prepare($equipment_query);
$attendance_id = $attendance['id'];
$equipment_stmt->bind_param("s", $attendance_id);
$equipment_stmt->execute();
$equipment_result = $equipment_stmt->get_result();
$borrowed_equipment = [];
while ($equipment = $equipment_result->fetch_assoc()) {
    $borrowed_equipment[] = $equipment['equipment_id'];
}
$equipment_stmt->close();

$expected_equipment = $borrowed_equipment;
$confirmed_equipment = $returned_equipment;
sort($expected_equipment);
sort($confirmed_equipment);
if ($expected_equipment !== $confirmed_equipment) {
    echo json_encode(["status" => "error", "message" => "Sila tandakan semua peralatan dipinjam sebelum clock out."]);
    exit();
}

$update_query = "UPDATE attendance
    SET return_status = 'pending_acknowledgement', return_requested_at = NOW(),
        return_checkpoint_id = ?, return_latitude = ?, return_longitude = ?
    WHERE id = ?";
$update_stmt = $conn->prepare($update_query);
$update_stmt->bind_param("ssss", $checkpoint_id, $lat, $lon, $attendance_id);

if ($update_stmt->execute()) {
    echo json_encode([
        "status" => "success",
        "message" => "Pemulangan dihantar. Sila tunggu pengesahan Ketua Peronda atau Ketua KRT."
    ]);
} else {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menghantar pemulangan."]);
}

$update_stmt->close();
$conn->close();
?>
