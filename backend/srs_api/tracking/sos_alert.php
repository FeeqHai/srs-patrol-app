<?php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

require_once '../config/db_connect.php';
require_once '../config/access_control.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["status" => "error", "message" => "Invalid request method."]);
    exit();
}

$actor = get_current_actor($conn);
$jwt_user_id = $actor['id'];

// Decode incoming JSON payload
$json = file_get_contents('php://input');
$data = json_decode($json, true);

if (!$data) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Malformed JSON payload"]);
    exit();
}

$user_id = $data['user_id'] ?? '';
$latitude = $data['latitude'] ?? '';
$longitude = $data['longitude'] ?? '';
$state_id = $actor['state_id'];
$district_id = $actor['district_id'];
$zone_id = $actor['zone_id'];

// Double check payload matches JWT user
if (empty($user_id) || $user_id !== $jwt_user_id) {
    http_response_code(403);
    echo json_encode(["status" => "error", "message" => "Forbidden: User ID mismatch"]);
    exit();
}

if (empty($latitude) || empty($longitude)) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Coordinates are required."]);
    exit();
}

if (empty($state_id) || empty($district_id) || empty($zone_id)) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Account location is incomplete."]);
    exit();
}

$title = 'KECEMASAN / SOS DIHANTAR';
$description = 'Peronda ini memerlukan bantuan SEGERA di koordinat ini.';
$category = 'Kecemasan';
$status = 'Pending';
$location_name = 'Lokasi GPS Semasa';
$reported_to = 'Polis';

function srs_notification_id() {
    $hex = bin2hex(random_bytes(16));
    return substr($hex, 0, 8) . '-' . substr($hex, 8, 4) . '-' . substr($hex, 12, 4) . '-' . substr($hex, 16, 4) . '-' . substr($hex, 20);
}

function create_sos_notification($conn, $recipient_user_id, $actor_user_id, $incident_id, $actor_name) {
    $id = srs_notification_id();
    $payload_json = json_encode(['related_id' => $incident_id]);
    $body = $actor_name . ' memerlukan bantuan segera di Lokasi GPS Semasa.';
    $stmt = $conn->prepare(
        "INSERT INTO notifications (id, user_id, actor_user_id, type, title, body, payload_json)
         VALUES (?, ?, ?, 'sos', 'Amaran SOS', ?, ?)"
    );
    if (!$stmt) {
        return;
    }
    $stmt->bind_param('sssss', $id, $recipient_user_id, $actor_user_id, $body, $payload_json);
    $stmt->execute();
    $stmt->close();
}

function notify_sos_recipients($conn, $actor, $incident_id) {
    $stmt = $conn->prepare(
        "SELECT DISTINCT u.id
         FROM users u
         WHERE u.account_status = 'active'
           AND u.id != ?
           AND (
             u.role = 'super_admin'
             OR (u.role = 'ketua_krt' AND u.district_id = ?)
             OR u.id IN (
               SELECT sm2.user_id
               FROM squad_members sm1
               JOIN squad_members sm2 ON sm2.squad_id = sm1.squad_id
               WHERE sm1.user_id = ?
             )
             OR (
               u.district_id = ?
               AND u.zone_id = ?
               AND u.role IN ('peronda', 'ketua_peronda')
             )
           )"
    );
    if (!$stmt) {
        return;
    }
    $stmt->bind_param('sssss', $actor['id'], $actor['district_id'], $actor['id'], $actor['district_id'], $actor['zone_id']);
    $stmt->execute();
    $result = $stmt->get_result();
    while ($row = $result->fetch_assoc()) {
        create_sos_notification($conn, $row['id'], $actor['id'], $incident_id, $actor['full_name']);
    }
    $stmt->close();
}

$incident_id = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
    mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff),
    mt_rand(0, 0x0fff) | 0x4000, mt_rand(0, 0x3fff) | 0x8000,
    mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
);

$query = "INSERT INTO incidents (id, user_id, state_id, district_id, zone_id, title, description, category, latitude, longitude, status, location_name, reported_to) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
$stmt = $conn->prepare($query);

if (!$stmt) {
    echo json_encode(["status" => "error", "message" => "Database error: " . $conn->error]);
    exit();
}

$stmt->bind_param("sssssssssssss", $incident_id, $user_id, $state_id, $district_id, $zone_id, $title, $description, $category, $latitude, $longitude, $status, $location_name, $reported_to);

if ($stmt->execute()) {
    notify_sos_recipients($conn, $actor, $incident_id);
    echo json_encode([
        "status" => "success",
        "message" => "SOS alert recorded successfully."
    ]);
} else {
    echo json_encode(["status" => "error", "message" => "Failed to record SOS alert: " . $stmt->error]);
}

$stmt->close();
$conn->close();
?>
