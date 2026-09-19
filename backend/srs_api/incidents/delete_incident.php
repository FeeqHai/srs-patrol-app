<?php
header('Content-Type: application/json');
require_once '../config/db_connect.php';
require_once '../config/jwt_utils.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
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

$id = trim($_POST['id'] ?? '');

if (empty($id)) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Incident ID required."]);
    exit();
}

// 1. Fetch the incident's image_url first to delete files from disk
$img_query = "SELECT image_url FROM incidents WHERE id = ?";
$img_stmt = $conn->prepare($img_query);
if ($img_stmt) {
    $img_stmt->bind_param("s", $id);
    $img_stmt->execute();
    $img_result = $img_stmt->get_result();
    if ($img_result->num_rows === 1) {
        $row = $img_result->fetch_assoc();
        $image_url_raw = $row['image_url'];
        if (!empty($image_url_raw)) {
            // Handle both JSON array and single string (legacy formats)
            $urls = json_decode($image_url_raw, true);
            if (!is_array($urls)) {
                if (strpos($image_url_raw, '[') === 0) {
                    $urls = [];
                } else {
                    $urls = [$image_url_raw];
                }
            }

            foreach ($urls as $url) {
                $path_parts = parse_url($url);
                if (isset($path_parts['path'])) {
                    $filename = basename($path_parts['path']);
                    $filepath = __DIR__ . '/../uploads/incidents/' . $filename;
                    if (file_exists($filepath)) {
                        unlink($filepath);
                    }
                }
            }
        }
    }
    $img_stmt->close();
}

// 2. Delete the record from database
$query = "DELETE FROM incidents WHERE id = ?";
$stmt = $conn->prepare($query);

if (!$stmt) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Database prep failed."]);
    exit();
}

$stmt->bind_param("s", $id);

if ($stmt->execute()) {
    if ($stmt->affected_rows > 0) {
        echo json_encode(["status" => "success", "message" => "Record deleted."]);
    } else {
        http_response_code(444);
        echo json_encode(["status" => "error", "message" => "Record not found."]);
    }
} else {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Database execution failed."]);
}

$stmt->close();
$conn->close();
?>
