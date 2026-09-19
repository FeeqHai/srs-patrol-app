<?php
header('Content-Type: application/json');
require_once '../config/db_connect.php';
require_once '../config/jwt_utils.php';
require_once '../config/account_validation.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(["status" => "error", "message" => "Invalid request method."]);
    exit();
}

$email = trim(account_string($_POST['email'] ?? ''));
$password = account_string($_POST['password'] ?? '');

if (empty($email) || empty($password)) {
    echo json_encode(["status" => "error", "message" => "Email and password are required."]);
    exit();
}

$must_change_password_column = "0 AS must_change_password";
$column_check = $conn->query("SHOW COLUMNS FROM users LIKE 'must_change_password'");
if ($column_check && $column_check->num_rows > 0) {
    $must_change_password_column = "u.must_change_password";
}

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

$query = "SELECT u.id, u.full_name, u.email, u.password_hash, u.role, u.district_zone, u.account_status, {$must_change_password_column},
                 {$profile_image_column},
                 u.state_id, u.district_id, u.zone_id,
                 st.name AS state_name, d.name AS district_name, z.name AS zone_name
          FROM users u
          LEFT JOIN states st ON st.id = u.state_id
          LEFT JOIN districts d ON d.id = u.district_id
          LEFT JOIN zones z ON z.id = u.zone_id
          WHERE u.email = ?";
$stmt = $conn->prepare($query);
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 1) {
    $user = $result->fetch_assoc();

    // Verify the password before revealing account status. This prevents an
    // invalid password from being used to discover pending/inactive accounts.
    if (!password_verify($password, $user['password_hash'])) {
        echo json_encode(["status" => "error", "message" => "Invalid credentials."]);
    } elseif ($user['account_status'] === 'pending') {
        echo json_encode(["status" => "error", "message" => "Akaun anda sedang menunggu kelulusan Pentadbir KRT."]);
    } elseif ($user['account_status'] === 'inactive') {
        echo json_encode(["status" => "error", "message" => "Pendaftaran anda telah ditolak atau akaun telah dinyahaktifkan."]);
    } else {
        $token = generate_jwt(
            $user['id'],
            $user['role'],
            $user['district_zone'],
            $user['state_id'],
            $user['district_id'],
            $user['zone_id']
        );
        echo json_encode([
            "status" => "success",
            "message" => "Authentication successful.",
            "token" => $token,
            "data" => [
                "id" => $user['id'],
                "full_name" => $user['full_name'],
                "email" => $user['email'],
                "role" => $user['role'],
                "profile_image_url" => $user['profile_image_url'],
                "profile_image_path" => $user['profile_image_path'],
                "state_id" => $user['state_id'],
                "district_id" => $user['district_id'],
                "zone_id" => $user['zone_id'],
                "state_name" => $user['state_name'],
                "district_name" => $user['district_name'],
                "zone_name" => $user['zone_name'],
                "must_change_password" => (int)($user['must_change_password'] ?? 0)
            ]
        ]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Invalid credentials."]);
}

$stmt->close();
$conn->close();
?>
