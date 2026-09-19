<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json; charset=UTF-8");

require_once '../config/db_connect.php';
require_once '../config/access_control.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(["status" => "error", "message" => "Method not allowed"]);
    exit();
}

$actor = get_current_actor($conn);
require_role($actor, ['super_admin']);

function scalar_count($conn, $sql) {
    $result = $conn->query($sql);
    if (!$result) {
        throw new Exception($conn->error);
    }
    $row = $result->fetch_assoc();
    return (int)($row['count'] ?? 0);
}

try {
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
        $profile_image_column = "COALESCE(u.profile_image_url, u.profile_image_path) AS profile_image_url";
    } elseif ($has_profile_image_url) {
        $profile_image_column = "u.profile_image_url";
    } elseif ($has_profile_image_path) {
        $profile_image_column = "u.profile_image_path AS profile_image_url";
    } else {
        $profile_image_column = "NULL AS profile_image_url";
    }

    $stats = [
        "total_users" => scalar_count($conn, "SELECT COUNT(*) AS count FROM users"),
        "total_krt_admins" => scalar_count($conn, "SELECT COUNT(*) AS count FROM users WHERE role = 'ketua_krt'"),
        "active_krt_admins" => scalar_count($conn, "SELECT COUNT(*) AS count FROM users WHERE role = 'ketua_krt' AND account_status = 'active'"),
        "total_patrollers" => scalar_count($conn, "SELECT COUNT(*) AS count FROM users WHERE role = 'peronda'"),
        "total_squad_leaders" => scalar_count($conn, "SELECT COUNT(*) AS count FROM users WHERE role = 'ketua_peronda'"),
        "pending_accounts" => scalar_count($conn, "SELECT COUNT(*) AS count FROM users WHERE account_status = 'pending'"),
        "inactive_accounts" => scalar_count($conn, "SELECT COUNT(*) AS count FROM users WHERE account_status = 'inactive'"),
        "active_shifts" => scalar_count($conn, "SELECT COUNT(*) AS count FROM attendance WHERE clock_out_time IS NULL AND return_status = 'active'"),
        "pending_returns" => scalar_count($conn, "SELECT COUNT(*) AS count FROM attendance WHERE return_status = 'pending_acknowledgement'"),
        "today_incidents" => scalar_count($conn, "SELECT COUNT(*) AS count FROM incidents WHERE category != 'Kecemasan' AND DATE(CONVERT_TZ(created_at, '+00:00', '+08:00')) = DATE(UTC_TIMESTAMP() + INTERVAL 8 HOUR)"),
        "total_states" => scalar_count($conn, "SELECT COUNT(*) AS count FROM states"),
        "total_districts" => scalar_count($conn, "SELECT COUNT(*) AS count FROM districts"),
        "total_zones" => scalar_count($conn, "SELECT COUNT(*) AS count FROM zones")
    ];

    $admin_query = "SELECT u.id, u.full_name, u.email, u.phone_number, u.account_status,
                           {$profile_image_column},
                           u.state_id, u.district_id, u.zone_id,
                           st.name AS state_name, d.name AS district_name, z.name AS zone_name
                    FROM users u
                    LEFT JOIN states st ON st.id = u.state_id
                    LEFT JOIN districts d ON d.id = u.district_id
                    LEFT JOIN zones z ON z.id = u.zone_id
                    WHERE u.role = 'ketua_krt'
                    ORDER BY st.name ASC, d.name ASC, z.name ASC, u.full_name ASC";
    $admin_result = $conn->query($admin_query);
    if (!$admin_result) {
        throw new Exception($conn->error);
    }

    $krt_admins = [];
    while ($row = $admin_result->fetch_assoc()) {
        $krt_admins[] = $row;
    }

    $coverage_query = "SELECT st.name AS state_name, d.name AS district_name,
                              COUNT(DISTINCT z.id) AS zones,
                              COUNT(DISTINCT CASE WHEN u.role = 'ketua_krt' THEN u.id END) AS krt_admins,
                              COUNT(DISTINCT CASE WHEN u.role IN ('peronda', 'ketua_peronda') THEN u.id END) AS patrol_members
                       FROM districts d
                       JOIN states st ON st.id = d.state_id
                       LEFT JOIN zones z ON z.district_id = d.id
                       LEFT JOIN users u ON u.district_id = d.id
                       GROUP BY d.id, st.name, d.name
                       ORDER BY st.name ASC, d.name ASC";
    $coverage_result = $conn->query($coverage_query);
    if (!$coverage_result) {
        throw new Exception($conn->error);
    }

    $district_coverage = [];
    while ($row = $coverage_result->fetch_assoc()) {
        $row['zones'] = (int)$row['zones'];
        $row['krt_admins'] = (int)$row['krt_admins'];
        $row['patrol_members'] = (int)$row['patrol_members'];
        $district_coverage[] = $row;
    }

    echo json_encode([
        "status" => "success",
        "data" => [
            "stats" => $stats,
            "krt_admins" => $krt_admins,
            "district_coverage" => $district_coverage
        ]
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Unable to load super admin overview."
    ]);
}

$conn->close();
?>
