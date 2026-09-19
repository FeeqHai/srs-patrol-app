<?php
header('Content-Type: application/json');
require_once '../config/db_connect.php';
require_once '../config/access_control.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_error(405, 'Kaedah permintaan tidak sah.');
}

$actor = get_current_actor($conn);

if (!isset($_FILES['image']) || $_FILES['image']['error'] !== UPLOAD_ERR_OK) {
    api_error(400, 'Sila pilih gambar profil yang sah.');
}

if ($_FILES['image']['size'] > 5 * 1024 * 1024) {
    api_error(400, 'Saiz gambar profil tidak boleh melebihi 5MB.');
}

$finfo = finfo_open(FILEINFO_MIME_TYPE);
$mime_type = finfo_file($finfo, $_FILES['image']['tmp_name']);
finfo_close($finfo);

$extensions = [
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
];
if (!isset($extensions[$mime_type])) {
    api_error(400, 'Format gambar tidak disokong. Gunakan JPG, PNG atau WEBP.');
}

$upload_dir = __DIR__ . '/../uploads/profile_pictures/';
if (!is_dir($upload_dir) && !mkdir($upload_dir, 0777, true)) {
    api_error(500, 'Gagal menyediakan storan gambar profil.');
}

$filename = 'user_' . $actor['id'] . '_profile_' . bin2hex(random_bytes(8)) . '.' . $extensions[$mime_type];
$target_path = $upload_dir . $filename;
if (!move_uploaded_file($_FILES['image']['tmp_name'], $target_path)) {
    api_error(500, 'Gagal memuat naik gambar profil.');
}

$relative_path = 'uploads/profile_pictures/' . $filename;
$has_profile_image_url = false;
$profile_url_check = $conn->query("SHOW COLUMNS FROM users LIKE 'profile_image_url'");
if ($profile_url_check && $profile_url_check->num_rows > 0) {
    $has_profile_image_url = true;
}

$update_query = $has_profile_image_url
    ? 'UPDATE users SET profile_image_path = ?, profile_image_url = ? WHERE id = ?'
    : 'UPDATE users SET profile_image_path = ? WHERE id = ?';
$stmt = $conn->prepare($update_query);
if (!$stmt) {
    api_error(500, 'Gagal mengemas kini gambar profil.');
}
if ($has_profile_image_url) {
    $stmt->bind_param('sss', $relative_path, $relative_path, $actor['id']);
} else {
    $stmt->bind_param('ss', $relative_path, $actor['id']);
}
if (!$stmt->execute()) {
    $stmt->close();
    api_error(500, 'Gagal mengemas kini gambar profil.');
}

$stmt->close();
$conn->close();
echo json_encode([
    'status' => 'success',
    'profile_image_path' => $relative_path,
    'data' => [
        'profile_image_url' => $relative_path
    ]
]);
?>
