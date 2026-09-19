<?php
require_once __DIR__ . '/jwt_utils.php';

function api_error($status_code, $message) {
    http_response_code($status_code);
    echo json_encode(["status" => "error", "message" => $message]);
    exit();
}

function get_current_actor($conn) {
    $token = get_bearer_token();
    if (!$token) {
        api_error(401, 'Missing authentication token.');
    }

    $decoded = verify_jwt($token);
    if (!$decoded || empty($decoded['user_id'])) {
        api_error(401, 'Invalid or expired token.');
    }

    $query = "SELECT id, full_name, email, role, account_status, state_id, district_id, zone_id
              FROM users
              WHERE id = ?";
    $stmt = $conn->prepare($query);
    if (!$stmt) {
        api_error(500, 'Unable to verify the current user.');
    }

    $stmt->bind_param('s', $decoded['user_id']);
    $stmt->execute();
    $actor = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$actor || $actor['account_status'] !== 'active') {
        api_error(403, 'This account is not active.');
    }

    return $actor;
}

function require_role($actor, $allowed_roles) {
    if (!in_array($actor['role'], $allowed_roles, true)) {
        api_error(403, 'You do not have permission for this action.');
    }
}

function actor_can_access_district($actor, $district_id) {
    return $actor['role'] === 'super_admin'
        || ($actor['district_id'] !== null && $actor['district_id'] === $district_id);
}

function actor_can_access_user($conn, $actor, $target_user_id) {
    if ($actor['role'] === 'super_admin' || $actor['id'] === $target_user_id) {
        return true;
    }

    $stmt = $conn->prepare('SELECT district_id FROM users WHERE id = ?');
    if (!$stmt) {
        api_error(500, 'Unable to verify user scope.');
    }
    $stmt->bind_param('s', $target_user_id);
    $stmt->execute();
    $target = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    return $target && $actor['role'] === 'ketua_krt'
        && $target['district_id'] === $actor['district_id'];
}
?>
