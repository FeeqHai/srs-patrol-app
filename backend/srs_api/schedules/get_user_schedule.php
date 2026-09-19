<?php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

require_once '../config/db_connect.php';
require_once '../config/jwt_utils.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

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

$user_id = $decoded['user_id'];

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

    // 1. Get the user's squad
    $squad_query = "SELECT s.id as squad_id, s.name as squad_name, sm.role as squad_role
                    FROM squad_members sm
                    JOIN squads s ON sm.squad_id = s.id
                    WHERE sm.user_id = ?";
    $stmt = $conn->prepare($squad_query);
    if (!$stmt) {
        throw new Exception($conn->error);
    }
    $stmt->bind_param("s", $user_id);
    $stmt->execute();
    $squad_res = $stmt->get_result();

    $squad = null;
    $schedules = [];

    if ($squad_res->num_rows > 0) {
        $squad = $squad_res->fetch_assoc();
        $squad_id = $squad['squad_id'];
        $stmt->close();

        // 2. Get the squad's schedules (today and upcoming/all)
        $schedule_query = "SELECT sc.id, sc.shift_date, sc.start_time, sc.end_time,
                                  COALESCE(sc.state_id, sq.state_id) AS state_id,
                                  COALESCE(sc.district_id, sq.district_id) AS district_id,
                                  COALESCE(sc.zone_id, sq.zone_id) AS zone_id,
                                  st.name AS state_name, d.name AS district_name, z.name AS zone_name
                           FROM schedules sc
                           JOIN squads sq ON sq.id = sc.squad_id
                           LEFT JOIN states st ON st.id = COALESCE(sc.state_id, sq.state_id)
                           LEFT JOIN districts d ON d.id = COALESCE(sc.district_id, sq.district_id)
                           LEFT JOIN zones z ON z.id = COALESCE(sc.zone_id, sq.zone_id)
                           WHERE sc.squad_id = ?
                           ORDER BY shift_date DESC, start_time ASC";
        $stmt2 = $conn->prepare($schedule_query);
        if (!$stmt2) {
            throw new Exception($conn->error);
        }
        $stmt2->bind_param("s", $squad_id);
        $stmt2->execute();
        $schedule_res = $stmt2->get_result();
        while ($row = $schedule_res->fetch_assoc()) {
            $schedules[] = $row;
        }
        $stmt2->close();

        // 3. Get the squad's members
        $members = [];
        $members_query = "SELECT u.id as user_id, u.full_name, u.phone_number, {$profile_image_column}, sm.role as squad_role
                          FROM squad_members sm
                          JOIN users u ON sm.user_id = u.id
                          WHERE sm.squad_id = ?
                          ORDER BY sm.role DESC, u.full_name ASC";
        $stmt3 = $conn->prepare($members_query);
        if ($stmt3) {
            $stmt3->bind_param("s", $squad_id);
            $stmt3->execute();
            $members_res = $stmt3->get_result();
            while ($row = $members_res->fetch_assoc()) {
                $members[] = $row;
            }
            $stmt3->close();
        }
        $squad['members'] = $members;
    } else {
        $stmt->close();
    }

    echo json_encode([
        "status" => "success",
        "squad" => $squad,
        "schedules" => $schedules
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Database error: " . $e->getMessage()]);
}

$conn->close();
?>
