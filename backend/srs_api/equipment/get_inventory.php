<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json; charset=UTF-8");

require_once '../config/db_connect.php';
require_once '../config/jwt_utils.php';

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($method !== 'GET') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Method not allowed']);
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

try {
    $stmt = $conn->prepare("SELECT id, item_name, total_quantity FROM equipment_inventory");
    if (!$stmt) {
        throw new Exception($conn->error);
    }
    $stmt->execute();
    $inv_result = $stmt->get_result();
    $inventory = [];
    while ($row = $inv_result->fetch_assoc()) {
        $inventory[] = $row;
    }
    $stmt->close();

    // Calculate available quantity by subtracting currently borrowed items
    // Currently borrowed items = equipment_logs where returned_at IS NULL
    $calc_stmt = $conn->prepare("SELECT equipment_id, COUNT(*) as borrowed_count FROM equipment_logs WHERE returned_at IS NULL GROUP BY equipment_id");
    if (!$calc_stmt) {
        throw new Exception($conn->error);
    }
    $calc_stmt->execute();
    $calc_result = $calc_stmt->get_result();
    $borrowed = [];
    while ($row = $calc_result->fetch_assoc()) {
        $borrowed[$row['equipment_id']] = (int)$row['borrowed_count'];
    }
    $calc_stmt->close();

    $results = [];
    foreach ($inventory as $item) {
        $borrowed_qty = $borrowed[$item['id']] ?? 0;
        $item['available_quantity'] = (int)$item['total_quantity'] - $borrowed_qty;
        $results[] = $item;
    }

    echo json_encode(['status' => 'success', 'data' => $results]);
} catch(Exception $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Database error: ' . $e->getMessage()]);
}

$conn->close();
?>
