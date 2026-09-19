<?php
header('Content-Type: application/json');
require_once '../config/db_connect.php';
require_once '../config/access_control.php';

$actor = get_current_actor($conn);

$page = isset($_GET['page']) ? (int)$_GET['page'] : 1;
$limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 10;
if ($page < 1) $page = 1;
if ($limit < 1 || $limit > 1000) $limit = 1000;

$offset = ($page - 1) * $limit;

$user_id = isset($_GET['user_id']) ? trim($_GET['user_id']) : null;
$category_filter = $_GET['category'] ?? null;
$state_filter = isset($_GET['state_id']) ? trim($_GET['state_id']) : '';
$district_filter = isset($_GET['district_id']) ? trim($_GET['district_id']) : '';
$zone_id_filter = isset($_GET['zone_id']) ? trim($_GET['zone_id']) : '';

$where_clauses = [];
$params = [];
$types = "";

if ($actor['role'] === 'peronda') {
    $user_id = $actor['id'];
} elseif ($actor['role'] === 'ketua_peronda') {
    $where_clauses[] = "EXISTS (
        SELECT 1
        FROM squad_members target_member
        JOIN squad_members leader_member ON leader_member.squad_id = target_member.squad_id
        WHERE target_member.user_id = i.user_id AND leader_member.user_id = ?
    )";
    $params[] = $actor['id'];
    $types .= "s";
} elseif ($actor['role'] === 'ketua_krt') {
    $where_clauses[] = "u.district_id = ?";
    $params[] = $actor['district_id'];
    $types .= "s";
    $where_clauses[] = "LOWER(i.status) = 'submitted'";
} elseif ($actor['role'] === 'super_admin') {
    $where_clauses[] = "LOWER(i.status) = 'submitted'";
}

if ($user_id) {
    $where_clauses[] = "i.user_id = ?";
    $params[] = $user_id;
    $types .= "s";
}

$zone_filter = $_GET['zone'] ?? null;
if ($state_filter !== '') {
    $where_clauses[] = "COALESCE(i.state_id, u.state_id) = ?";
    $params[] = $state_filter;
    $types .= "s";
}
if ($district_filter !== '') {
    $where_clauses[] = "COALESCE(i.district_id, u.district_id) = ?";
    $params[] = $district_filter;
    $types .= "s";
}
if ($zone_id_filter !== '') {
    $where_clauses[] = "COALESCE(i.zone_id, u.zone_id) = ?";
    $params[] = $zone_id_filter;
    $types .= "s";
} elseif ($zone_filter && $zone_filter !== 'Semua') {
    $where_clauses[] = "u.district_zone = ?";
    $params[] = $zone_filter;
    $types .= "s";
}

$start_date = $_GET['start_date'] ?? null;
$end_date = $_GET['end_date'] ?? null;

if ($category_filter && $category_filter !== 'Semua') {
    // Exact match or prefix match (e.g., "Jenayah Kekerasan" should match "Jenayah Kekerasan - Pembunuhan")
    // Use LIKE with % to allow matching the parent category
    $where_clauses[] = "i.category LIKE ?";
    $params[] = $category_filter . "%";
    $types .= "s";
}

if ($start_date && $end_date) {
    // XAMPP stores MySQL TIMESTAMP values in the local Malaysia session time.
    // Filter by the stored calendar date so late-night local rows stay in Today.
    $where_clauses[] = "DATE(i.created_at) BETWEEN ? AND ?";
    $params[] = $start_date;
    $params[] = $end_date;
    $types .= "ss";
}

$where_sql = "WHERE i.category != 'Kecemasan'";
if (count($where_clauses) > 0) {
    $where_sql .= " AND " . implode(" AND ", $where_clauses);
}

$query = "SELECT i.*, u.full_name, u.district_zone,
                 COALESCE(ist.name, ust.name) AS state_name,
                 COALESCE(idt.name, udt.name) AS district_name,
                 COALESCE(iz.name, uz.name, u.district_zone) AS zone_name,
                 COALESCE(iz.name, uz.name, u.district_zone) AS zone
          FROM incidents i
          JOIN users u ON i.user_id = u.id
          LEFT JOIN states ist ON ist.id = i.state_id
          LEFT JOIN districts idt ON idt.id = i.district_id
          LEFT JOIN zones iz ON iz.id = i.zone_id
          LEFT JOIN states ust ON ust.id = u.state_id
          LEFT JOIN districts udt ON udt.id = u.district_id
          LEFT JOIN zones uz ON uz.id = u.zone_id
          $where_sql
          ORDER BY i.created_at DESC
          LIMIT ? OFFSET ?";

$stmt = $conn->prepare($query);
if (!$stmt) {
    echo json_encode(["status" => "error", "message" => "Server error: " . $conn->error]);
    exit();
}
$params[] = $limit;
$params[] = $offset;
$types .= "ii";

// Call bind_param dynamically
$stmt->bind_param($types, ...$params);
$stmt->execute();
$result = $stmt->get_result();

$incidents = [];
while ($row = $result->fetch_assoc()) {
    $incidents[] = $row;
}

echo json_encode([
    "status" => "success",
    "page" => $page,
    "limit" => $limit,
    "data" => $incidents
]);

$stmt->close();
$conn->close();
?>
