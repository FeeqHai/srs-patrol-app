<?php
header('Content-Type: application/json');
require_once '../config/db_connect.php';
require_once '../config/access_control.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_error(405, 'Invalid request method.');
}

$actor = get_current_actor($conn);

if (!isset($_FILES['image']) || $_FILES['image']['error'] !== UPLOAD_ERR_OK) {
    api_error(400, 'Invalid image file.');
}

$max_size = 5 * 1024 * 1024;
if ($_FILES['image']['size'] > $max_size) {
    api_error(400, 'Image size is too large.');
}

$finfo = finfo_open(FILEINFO_MIME_TYPE);
if (!$finfo) {
    api_error(500, 'Unable to validate image.');
}
$mime_type = finfo_file($finfo, $_FILES['image']['tmp_name']);
finfo_close($finfo);

$allowed_types = [
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
];

if (!isset($allowed_types[$mime_type])) {
    api_error(400, 'Invalid image file.');
}

$upload_dir = __DIR__ . '/../uploads/profiles/';
if (!is_dir($upload_dir) && !mkdir($upload_dir, 0755, true)) {
    api_error(500, 'Unable to prepare profile image storage.');
}

$filename = 'profile_' . preg_replace('/[^A-Za-z0-9_-]/', '', $actor['id']) . '_' . bin2hex(random_bytes(12)) . '.' . $allowed_types[$mime_type];
$target_path = $upload_dir . $filename;

if (!move_uploaded_file($_FILES['image']['tmp_name'], $target_path)) {
    api_error(500, 'Failed to upload profile photo.');
}

$relative_path = 'uploads/profiles/' . $filename;
$stmt = $conn->prepare('UPDATE users SET profile_image_url = ? WHERE id = ?');
if (!$stmt) {
    @unlink($target_path);
    api_error(500, 'Unable to update profile photo.');
}

$stmt->bind_param('ss', $relative_path, $actor['id']);
if (!$stmt->execute()) {
    $stmt->close();
    @unlink($target_path);
    api_error(500, 'Unable to update profile photo.');
}

$stmt->close();
$conn->close();

echo json_encode([
    'status' => 'success',
    'message' => 'Profile photo updated successfully',
    'data' => [
        'profile_image_url' => $relative_path
    ]
]);
?>
