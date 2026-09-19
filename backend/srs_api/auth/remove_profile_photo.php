<?php
header('Content-Type: application/json');
require_once '../config/db_connect.php';
require_once '../config/access_control.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_error(405, 'Invalid request method.');
}

$actor = get_current_actor($conn);

$has_profile_image_path = false;
$profile_path_check = $conn->query("SHOW COLUMNS FROM users LIKE 'profile_image_path'");
if ($profile_path_check && $profile_path_check->num_rows > 0) {
    $has_profile_image_path = true;
}

$select_column = $has_profile_image_path ? 'profile_image_url, profile_image_path' : 'profile_image_url';
$stmt = $conn->prepare("SELECT {$select_column} FROM users WHERE id = ?");
if (!$stmt) {
    api_error(500, 'Unable to load profile photo.');
}
$stmt->bind_param('s', $actor['id']);
$stmt->execute();
$current = $stmt->get_result()->fetch_assoc();
$stmt->close();

$old_path = $current['profile_image_url'] ?? ($current['profile_image_path'] ?? null);

$update_sql = $has_profile_image_path
    ? 'UPDATE users SET profile_image_url = NULL, profile_image_path = NULL WHERE id = ?'
    : 'UPDATE users SET profile_image_url = NULL WHERE id = ?';
$update = $conn->prepare($update_sql);
if (!$update) {
    api_error(500, 'Unable to remove profile photo.');
}
$update->bind_param('s', $actor['id']);
if (!$update->execute()) {
    $update->close();
    api_error(500, 'Unable to remove profile photo.');
}
$update->close();

if ($old_path && strpos($old_path, 'uploads/profiles/') === 0) {
    $absolute = realpath(__DIR__ . '/../' . $old_path);
    $profiles_dir = realpath(__DIR__ . '/../uploads/profiles');
    if ($absolute && $profiles_dir && strpos($absolute, $profiles_dir) === 0 && is_file($absolute)) {
        @unlink($absolute);
    }
}

$conn->close();

echo json_encode([
    'status' => 'success',
    'message' => 'Profile photo removed successfully',
    'data' => [
        'profile_image_url' => null
    ]
]);
?>
