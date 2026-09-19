<?php
header('Content-Type: application/json');
require_once '../config/db_connect.php';

$level = $_GET['level'] ?? 'states';
$parent_id = trim($_GET['parent_id'] ?? '');

if ($level === 'states') {
    $result = $conn->query('SELECT id, code, name FROM states WHERE is_active = 1 ORDER BY name ASC');
} elseif ($level === 'districts' && $parent_id !== '') {
    $stmt = $conn->prepare('
        SELECT d.id, d.name
        FROM districts d
        JOIN states st ON st.id = d.state_id
        WHERE d.state_id = ?
          AND d.is_active = 1
          AND st.is_active = 1
        ORDER BY d.name ASC
    ');
    $stmt->bind_param('s', $parent_id);
    $stmt->execute();
    $result = $stmt->get_result();
} elseif ($level === 'zones' && $parent_id !== '') {
    $stmt = $conn->prepare('
        SELECT z.id, z.name
        FROM zones z
        JOIN districts d ON d.id = z.district_id
        JOIN states st ON st.id = d.state_id
        WHERE z.district_id = ?
          AND z.is_active = 1
          AND d.is_active = 1
          AND st.is_active = 1
        ORDER BY z.name ASC
    ');
    $stmt->bind_param('s', $parent_id);
    $stmt->execute();
    $result = $stmt->get_result();
} else {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Invalid location request."]);
    $conn->close();
    exit();
}

$data = [];
while ($row = $result->fetch_assoc()) {
    $data[] = $row;
}

echo json_encode(["status" => "success", "data" => $data]);

if (isset($stmt)) {
    $stmt->close();
}
$conn->close();
?>
