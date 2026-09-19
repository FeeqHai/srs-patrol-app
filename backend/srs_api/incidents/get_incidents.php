<?php
header('Content-Type: application/json');
require_once '../config/db_connect.php';
require_once '../config/jwt_utils.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(["status" => "error", "message" => "Method Not Allowed."]);
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
$jwt_role = $decoded['role'];

// For peronda, restrict query to their own ID. Others can query any user or all.
if ($jwt_role === 'peronda') {
    $user_id = $jwt_user_id;
} else {
    $user_id = isset($_GET['user_id']) ? trim($_GET['user_id']) : null;
}

if ($user_id) {
    $query = "SELECT i.*, u.full_name, u.district_zone AS zone, 'Durian Tunggal' AS district, 'Melaka' AS state FROM incidents i JOIN users u ON i.user_id = u.id WHERE i.user_id = ? ORDER BY i.created_at DESC";
    $stmt = $conn->prepare($query);
    if (!$stmt) {
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Database prep failed: " . $conn->error]);
        exit();
    }
    $stmt->bind_param("s", $user_id);
    $stmt->execute();
    $result = $stmt->get_result();
} else {
    $query = "SELECT i.*, u.full_name, u.district_zone AS zone, 'Durian Tunggal' AS district, 'Melaka' AS state FROM incidents i JOIN users u ON i.user_id = u.id ORDER BY i.created_at DESC";
    $result = $conn->query($query);
}

$incidents = [];
if ($result && $result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $incidents[] = $row;
    }
}

if ($user_id && isset($stmt)) {
    $stmt->close();
}

echo json_encode(["status" => "success", "data" => $incidents]);

$conn->close();
?>
