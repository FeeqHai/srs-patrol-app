<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json; charset=UTF-8");

require_once '../config/db_connect.php';
require_once '../config/jwt_utils.php';

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($method !== 'POST') {
    http_response_code(405);
    echo json_encode(["status" => "error", "message" => "Method not allowed"]);
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

if (!in_array($decoded['role'], ['ketua_krt', 'super_admin'], true)) {
    http_response_code(403);
    echo json_encode(["status" => "error", "message" => "Access denied. Only Ketua KRT can perform this action."]);
    exit();
}

try {
    // Support JSON body
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    if ($data) {
        $_POST = array_merge($_POST, $data);
    }

    $action = trim($_POST['action'] ?? '');

    if ($action === 'add') {
        $item_name = trim($_POST['item_name'] ?? '');
        $total_quantity = (int)($_POST['total_quantity'] ?? 0);

        if (empty($item_name) || $total_quantity < 0) {
            echo json_encode(["status" => "error", "message" => "Nama peralatan dan kuantiti diperlukan."]);
            exit();
        }

        $id = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
            mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff),
            mt_rand(0, 0x0fff) | 0x4000, mt_rand(0, 0x3fff) | 0x8000,
            mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
        );

        $stmt = $conn->prepare("INSERT INTO equipment_inventory (id, item_name, total_quantity) VALUES (?, ?, ?)");
        $stmt->bind_param("ssi", $id, $item_name, $total_quantity);
        if ($stmt->execute()) {
            echo json_encode(["status" => "success", "message" => "Peralatan berjaya ditambah."]);
        } else {
            echo json_encode(["status" => "error", "message" => "Gagal menambah peralatan."]);
        }
        $stmt->close();

    } else if ($action === 'update') {
        $id = trim($_POST['id'] ?? '');
        $item_name = trim($_POST['item_name'] ?? '');
        $total_quantity = (int)($_POST['total_quantity'] ?? 0);

        if (empty($id) || empty($item_name) || $total_quantity < 0) {
            echo json_encode(["status" => "error", "message" => "ID, nama peralatan dan kuantiti diperlukan."]);
            exit();
        }

        $stmt = $conn->prepare("UPDATE equipment_inventory SET item_name = ?, total_quantity = ? WHERE id = ?");
        $stmt->bind_param("sis", $item_name, $total_quantity, $id);
        if ($stmt->execute()) {
            echo json_encode(["status" => "success", "message" => "Peralatan berjaya dikemaskini."]);
        } else {
            echo json_encode(["status" => "error", "message" => "Gagal mengemaskini peralatan."]);
        }
        $stmt->close();

    } else if ($action === 'delete') {
        $id = trim($_POST['id'] ?? '');

        if (empty($id)) {
            echo json_encode(["status" => "error", "message" => "ID peralatan diperlukan."]);
            exit();
        }

        // Check if currently borrowed
        $check_stmt = $conn->prepare("SELECT COUNT(*) as active_borrows FROM equipment_logs WHERE equipment_id = ? AND returned_at IS NULL");
        $check_stmt->bind_param("s", $id);
        $check_stmt->execute();
        $check_res = $check_stmt->get_result()->fetch_assoc();
        $check_stmt->close();

        if ($check_res['active_borrows'] > 0) {
            echo json_encode(["status" => "error", "message" => "Peralatan tidak boleh dipadam kerana sedang dipinjam oleh peronda."]);
            exit();
        }

        // Safe to delete logs (cascade manually if needed)
        $del_logs_stmt = $conn->prepare("DELETE FROM equipment_logs WHERE equipment_id = ?");
        $del_logs_stmt->bind_param("s", $id);
        $del_logs_stmt->execute();
        $del_logs_stmt->close();

        $stmt = $conn->prepare("DELETE FROM equipment_inventory WHERE id = ?");
        $stmt->bind_param("s", $id);
        if ($stmt->execute()) {
            echo json_encode(["status" => "success", "message" => "Peralatan berjaya dipadam."]);
        } else {
            echo json_encode(["status" => "error", "message" => "Gagal memadam peralatan."]);
        }
        $stmt->close();

    } else {
        echo json_encode(["status" => "error", "message" => "Tindakan tidak sah."]);
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Database error: " . $e->getMessage()]);
}

$conn->close();
?>
