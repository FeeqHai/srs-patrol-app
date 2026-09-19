<?php
header('Content-Type: application/json');
require_once '../config/db_connect.php';
require_once '../config/access_control.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["status" => "error", "message" => "Sistem menolak request ini."]);
    exit();
}

$actor = get_current_actor($conn);
$jwt_user_id = $actor['id'];

// 1. Data Extraction & Sanitization (Strictly aligned with incident_service.dart)
$id = trim($_POST['id'] ?? '');
$reported_by = $jwt_user_id;
$title = trim($_POST['title'] ?? '');
$description = trim($_POST['description'] ?? '');
$category = trim($_POST['category'] ?? '');
$latitude = trim($_POST['latitude'] ?? '');
$longitude = trim($_POST['longitude'] ?? '');
$location_name = trim($_POST['location_name'] ?? '');
$reported_to = trim($_POST['reported_to'] ?? '');
$state_id = $actor['state_id'];
$district_id = $actor['district_id'];
$zone_id = $actor['zone_id'];

function srs_notification_id() {
    $hex = bin2hex(random_bytes(16));
    return substr($hex, 0, 8) . '-' . substr($hex, 8, 4) . '-' . substr($hex, 12, 4) . '-' . substr($hex, 16, 4) . '-' . substr($hex, 20);
}

function create_notification($conn, $recipient_user_id, $actor_user_id, $type, $title, $body, $related_id) {
    $id = srs_notification_id();
    $payload_json = json_encode(['related_id' => $related_id]);
    $stmt = $conn->prepare(
        'INSERT INTO notifications (id, user_id, actor_user_id, type, title, body, payload_json)
         VALUES (?, ?, ?, ?, ?, ?, ?)'
    );
    if (!$stmt) {
        return;
    }
    $stmt->bind_param('sssssss', $id, $recipient_user_id, $actor_user_id, $type, $title, $body, $payload_json);
    $stmt->execute();
    $stmt->close();
}

function notify_daily_note_recipients($conn, $actor, $incident_id, $location_name) {
    $stmt = $conn->prepare(
        "SELECT DISTINCT id
         FROM users
         WHERE account_status = 'active'
           AND role = 'ketua_krt'
           AND id != ?
           AND district_id = ?"
    );
    if (!$stmt) {
        return;
    }
    $stmt->bind_param('ss', $actor['id'], $actor['district_id']);
    $stmt->execute();
    $result = $stmt->get_result();
    $body = $actor['full_name'] . ' menghantar nota harian' . ($location_name ? ' di ' . $location_name : '') . '.';
    while ($row = $result->fetch_assoc()) {
        create_notification($conn, $row['id'], $actor['id'], 'daily_note', 'Nota Harian Baharu', $body, $incident_id);
    }
    $stmt->close();
}

function notify_sos_recipients($conn, $actor, $incident_id, $location_name) {
    $stmt = $conn->prepare(
        "SELECT DISTINCT u.id
         FROM users u
         WHERE u.account_status = 'active'
           AND u.id != ?
           AND (
             u.role = 'super_admin'
             OR (
               u.role = 'ketua_krt'
               AND u.district_id = ?
             )
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
    $stmt->bind_param(
        'sssss',
        $actor['id'],
        $actor['district_id'],
        $actor['id'],
        $actor['district_id'],
        $actor['zone_id']
    );
    $stmt->execute();
    $result = $stmt->get_result();
    $body = $actor['full_name'] . ' memerlukan bantuan segera' . ($location_name ? ' di ' . $location_name : '') . '.';
    while ($row = $result->fetch_assoc()) {
        create_notification($conn, $row['id'], $actor['id'], 'sos', 'Amaran SOS', $body, $incident_id);
    }
    $stmt->close();
}

// 2. Payload Validation
if ($id === '' || $reported_by === '' || $title === '' || $description === '' || $category === '' || $latitude === '' || $longitude === '') {
    echo json_encode(["status" => "error", "message" => "Ralat pelayan: Medan data tidak lengkap dihantar oleh aplikasi."]);
    exit();
}

if (empty($state_id) || empty($district_id) || empty($zone_id)) {
    echo json_encode(["status" => "error", "message" => "Lokasi akaun tidak lengkap. Sila hubungi Ketua KRT."]);
    exit();
}

// 3. Binary Image Handling
$uploaded_urls = [];
$upload_dir = __DIR__ . '/../uploads/incidents/';
if (!is_dir($upload_dir) && !mkdir($upload_dir, 0777, true)) {
    echo json_encode(["status" => "error", "message" => "Gagal menyediakan storan gambar."]);
    exit();
}

$files_to_process = [];
if (isset($_FILES['images'])) {
    $file_count = count($_FILES['images']['name']);
    for ($i = 0; $i < $file_count; $i++) {
        if ($_FILES['images']['error'][$i] === UPLOAD_ERR_OK) {
            $files_to_process[] = [
                'name' => $_FILES['images']['name'][$i],
                'tmp_name' => $_FILES['images']['tmp_name'][$i],
            ];
        }
    }
} elseif (isset($_FILES['image']) && $_FILES['image']['error'] === UPLOAD_ERR_OK) {
    $files_to_process[] = $_FILES['image'];
}

foreach ($files_to_process as $index => $file) {
    $file_extension = pathinfo($file['name'], PATHINFO_EXTENSION);
    $secure_filename = $id . '_' . time() . '_' . $index . '.' . $file_extension;
    $target_filepath = $upload_dir . $secure_filename;

    if (move_uploaded_file($file['tmp_name'], $target_filepath)) {
        $uploaded_urls[] = 'uploads/incidents/' . $secure_filename;
    }
}

$public_image_url = empty($uploaded_urls) ? null : json_encode($uploaded_urls);

// 5. Database Insertion. New daily notes are saved as Pending drafts.
$status = 'Pending';
$query = "INSERT INTO incidents (id, user_id, state_id, district_id, zone_id, title, description, category, latitude, longitude, image_url, location_name, reported_to, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
$stmt = $conn->prepare($query);

if (!$stmt) {
    echo json_encode(["status" => "error", "message" => "Ralat pangkalan data: " . $conn->error]);
    exit();
}

// Bind variables (14 strings)
$stmt->bind_param("ssssssssssssss", $id, $reported_by, $state_id, $district_id, $zone_id, $title, $description, $category, $latitude, $longitude, $public_image_url, $location_name, $reported_to, $status);

// 6. Final Evaluation
if ($stmt->execute()) {
    if ($category === 'Kecemasan') {
        notify_sos_recipients($conn, $actor, $id, $location_name);
    }
    echo json_encode(["status" => "success", "message" => "Nota harian berjaya disimpan."]);
} else {
    echo json_encode(["status" => "error", "message" => "Gagal merekodkan insiden ke dalam sistem."]);
}

$stmt->close();
$conn->close();
?>
