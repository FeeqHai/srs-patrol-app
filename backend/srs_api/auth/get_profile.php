<?php
header('Content-Type: application/json');
require_once '../config/db_connect.php';
require_once '../config/access_control.php';

$actor = get_current_actor($conn);
$user_id = $actor['id'];

$has_profile_image_url = false;
$profile_url_check = $conn->query("SHOW COLUMNS FROM users LIKE 'profile_image_url'");
if ($profile_url_check && $profile_url_check->num_rows > 0) {
    $has_profile_image_url = true;
}

$has_profile_image_path = false;
$profile_path_check = $conn->query("SHOW COLUMNS FROM users LIKE 'profile_image_path'");
if ($profile_path_check && $profile_path_check->num_rows > 0) {
    $has_profile_image_path = true;
}

if ($has_profile_image_url && $has_profile_image_path) {
    $profile_image_column = "COALESCE(u.profile_image_url, u.profile_image_path) AS profile_image_url, u.profile_image_path";
} elseif ($has_profile_image_url) {
    $profile_image_column = "u.profile_image_url, NULL AS profile_image_path";
} elseif ($has_profile_image_path) {
    $profile_image_column = "u.profile_image_path AS profile_image_url, u.profile_image_path";
} else {
    $profile_image_column = "NULL AS profile_image_url, NULL AS profile_image_path";
}

$query = "SELECT u.id, u.full_name, u.ic_number, u.phone_number, u.email, {$profile_image_column}, u.district_zone,
                 u.state_id, u.district_id, u.zone_id, u.role, u.account_status, u.created_at,
                 st.name AS state_name, d.name AS district_name, z.name AS zone_name,
                 s.name AS squad_name
          FROM users u
          LEFT JOIN states st ON st.id = u.state_id
          LEFT JOIN districts d ON d.id = u.district_id
          LEFT JOIN zones z ON z.id = u.zone_id
          LEFT JOIN squad_members sm ON sm.user_id = u.id
          LEFT JOIN squads s ON s.id = sm.squad_id
          WHERE u.id = ?";
$stmt = $conn->prepare($query);

if (!$stmt) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Database error: " . $conn->error]);
    exit();
}

$stmt->bind_param("s", $user_id);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 1) {
    $user = $result->fetch_assoc();
    echo json_encode([
        "status" => "success",
        "data" => $user
    ]);
} else {
    http_response_code(404);
    echo json_encode(["status" => "error", "message" => "User not found."]);
}

$stmt->close();
$conn->close();
?>
