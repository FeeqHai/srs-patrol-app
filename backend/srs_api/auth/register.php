<?php
header('Content-Type: application/json');
require_once '../config/db_connect.php';
require_once '../config/registration_verification.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(["status" => "error", "message" => "Sistem menolak request ini."]);
    exit();
}

$id = trim(account_string($_POST['id'] ?? ''));
$ic_number = verification_normalize_ic($_POST['ic_number'] ?? '');
$phone_number = account_string($_POST['phone_number'] ?? '');
$email = trim(account_string($_POST['email'] ?? ''));
$password = account_string($_POST['password'] ?? '');
$state_id = trim(account_string($_POST['state_id'] ?? ''));
$district_id = trim(account_string($_POST['district_id'] ?? ''));
$zone_id = trim(account_string($_POST['zone_id'] ?? ''));
$verification_token = trim(account_string($_POST['verification_token'] ?? ''));

// Strict Validation
if (empty($id) || empty($ic_number) || empty($phone_number) || empty($email) || empty($password) || empty($state_id) || empty($district_id) || empty($zone_id) || empty($verification_token)) {
    echo json_encode(["status" => "error", "message" => "Borang tidak lengkap. Sila isi semua butiran."]);
    exit();
}

$validation_error = account_ic_error($ic_number)
    ?? account_phone_error($phone_number)
    ?? account_password_error($password);
if ($validation_error !== null) {
    verification_json_error($validation_error, 422);
}
$phone_number = account_normalize_phone($phone_number);

verification_enforce_rate_limit($conn, 'register', 20, 60);
if (!verification_is_valid_token($verification_token)) {
    echo json_encode(["status" => "error", "message" => "Imbasan MyKad tidak sah atau telah tamat."]);
    exit();
}

verification_cleanup($conn);
$token_hash = hash('sha256', $verification_token);
$ic_hash = verification_hash($ic_number);

$conn->begin_transaction();

$verification_query = "SELECT id, ic_hash, full_name, verification_method
                       FROM registration_verifications
                       WHERE token_hash = ?
                         AND status = 'verified'
                         AND expires_at > NOW()
                       FOR UPDATE";
$verification_stmt = $conn->prepare($verification_query);
if (!$verification_stmt) {
    $conn->rollback();
    echo json_encode(["status" => "error", "message" => "Ralat pelayan semasa menyemak imbasan MyKad."]);
    exit();
}
$verification_stmt->bind_param('s', $token_hash);
$verification_stmt->execute();
$verification = $verification_stmt->get_result()->fetch_assoc();
$verification_stmt->close();

if (!$verification || !hash_equals($verification['ic_hash'], $ic_hash)) {
    $conn->rollback();
    echo json_encode(["status" => "error", "message" => "Imbasan MyKad tidak sah atau telah tamat."]);
    exit();
}

$full_name = $verification['full_name'];

// Identity verification does not determine the patroller's operating
// location. The applicant chooses it, while the server still verifies that the
// selected zone belongs to the supplied district and active state.
$location_query = "SELECT z.name AS zone_name
                   FROM zones z
                   JOIN districts d ON d.id = z.district_id
                   JOIN states st ON st.id = d.state_id
                   WHERE z.id = ?
                     AND d.id = ?
                     AND st.id = ?
                     AND z.is_active = 1
                     AND d.is_active = 1
                     AND st.is_active = 1";
$location_stmt = $conn->prepare($location_query);
if (!$location_stmt) {
    $conn->rollback();
    echo json_encode(["status" => "error", "message" => "Ralat pelayan semasa menyemak lokasi."]);
    exit();
}
$location_stmt->bind_param("sss", $zone_id, $district_id, $state_id);
$location_stmt->execute();
$location = $location_stmt->get_result()->fetch_assoc();
$location_stmt->close();

if (!$location) {
    $conn->rollback();
    echo json_encode(["status" => "error", "message" => "Pilihan negeri, daerah dan zon tidak sah."]);
    exit();
}

$district_zone = $location['zone_name'];

// Security: Hash the password before storage
$password_hash = password_hash($password, PASSWORD_BCRYPT);
$default_role = 'peronda';
$default_status = 'pending';
$identity_status = 'not_verified';
$identity_method = $verification['verification_method'];
$identity_verified_at = null;

$query = "INSERT INTO users (id, full_name, ic_number, phone_number, email, password_hash, district_zone, state_id, district_id, zone_id, role, account_status, identity_verification_status, identity_verification_method, identity_verified_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
$stmt = $conn->prepare($query);

if (!$stmt) {
    $conn->rollback();
    echo json_encode(["status" => "error", "message" => "Ralat pelayan semasa mendaftar akaun."]);
    exit();
}

$stmt->bind_param("sssssssssssssss", $id, $full_name, $ic_number, $phone_number, $email, $password_hash, $district_zone, $state_id, $district_id, $zone_id, $default_role, $default_status, $identity_status, $identity_method, $identity_verified_at);

try {
    $insert_succeeded = $stmt->execute();
    $insert_errno = $stmt->errno;
} catch (mysqli_sql_exception $e) {
    $insert_succeeded = false;
    $insert_errno = (int) $e->getCode();
}

if ($insert_succeeded) {
    $consume_verification = $conn->prepare(
        "UPDATE registration_verifications
         SET status = 'consumed', consumed_at = NOW(), full_name = NULL
         WHERE id = ? AND status = 'verified'"
    );
    if (!$consume_verification) {
        $conn->rollback();
        echo json_encode(["status" => "error", "message" => "Ralat pelayan semasa menamatkan sesi pengesahan."]);
        exit();
    }
    $consume_verification->bind_param('s', $verification['id']);
    $consume_succeeded = $consume_verification->execute()
        && $consume_verification->affected_rows === 1;
    $consume_verification->close();
    if (!$consume_succeeded) {
        $conn->rollback();
        echo json_encode(["status" => "error", "message" => "Ralat pelayan semasa menamatkan sesi pengesahan."]);
        exit();
    }
    $conn->commit();
    echo json_encode(["status" => "success", "message" => "Pendaftaran berjaya. Akaun sedang menunggu pengesahan Ketua KRT."]);
} else {
    $conn->rollback();
    // Catch duplicate IC or Email errors
    if ($insert_errno === 1062) {
        echo json_encode(["status" => "error", "message" => "No. Kad Pengenalan atau E-mel telah didaftarkan dalam sistem."]);
    } else {
        echo json_encode(["status" => "error", "message" => "Ralat pangkalan data."]);
    }
}

$stmt->close();
$conn->close();
?>
