<?php
header('Content-Type: application/json');
require_once '../config/db_connect.php';
require_once '../config/access_control.php';
require_once '../config/account_validation.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["status" => "error", "message" => "Invalid request method."]);
    exit();
}

$actor = get_current_actor($conn);
require_role($actor, ['ketua_krt', 'super_admin']);

$action = trim($_POST['action'] ?? '');
$target_user_id = trim($_POST['user_id'] ?? '');

if (empty($action) || empty($target_user_id)) {
    echo json_encode(["status" => "error", "message" => "Missing action or user ID."]);
    exit();
}

function fetch_target_user($conn, $user_id) {
    $stmt = $conn->prepare("SELECT id, full_name, role, account_status, state_id, district_id, zone_id FROM users WHERE id = ?");
    if (!$stmt) {
        api_error(500, 'Unable to load user.');
    }
    $stmt->bind_param("s", $user_id);
    $stmt->execute();
    $target = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$target) {
        api_error(404, 'User not found.');
    }
    return $target;
}

function validate_location_path($conn, $state_id, $district_id, $zone_id) {
    $stmt = $conn->prepare(
        "SELECT z.name AS zone_name
         FROM zones z
         JOIN districts d ON d.id = z.district_id
         JOIN states st ON st.id = d.state_id
         WHERE z.id = ? AND d.id = ? AND st.id = ?
           AND z.is_active = 1 AND d.is_active = 1 AND st.is_active = 1"
    );
    if (!$stmt) {
        api_error(500, 'Unable to validate location.');
    }
    $stmt->bind_param("sss", $zone_id, $district_id, $state_id);
    $stmt->execute();
    $location = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$location) {
        api_error(400, 'Invalid state, district or zone selection.');
    }
    return $location;
}

function assert_one_active_krt_per_district($conn, $district_id, $target_user_id) {
    $stmt = $conn->prepare(
        "SELECT id, full_name
         FROM users
         WHERE role = 'ketua_krt'
           AND account_status = 'active'
           AND district_id = ?
           AND id <> ?
         LIMIT 1"
    );
    if (!$stmt) {
        api_error(500, 'Unable to verify Ketua KRT district ownership.');
    }
    $stmt->bind_param("ss", $district_id, $target_user_id);
    $stmt->execute();
    $existing = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if ($existing) {
        api_error(409, 'District already has an active Ketua KRT.');
    }
}

function remove_from_squad_and_notify($conn, $actor_id, $target_user_id, $target_name) {
    $stmt = $conn->prepare(
        "SELECT sm.squad_id, s.name AS squad_name, leader.user_id AS leader_user_id
         FROM squad_members sm
         JOIN squads s ON s.id = sm.squad_id
         LEFT JOIN squad_members leader
           ON leader.squad_id = sm.squad_id AND leader.role = 'leader' AND leader.user_id <> sm.user_id
         WHERE sm.user_id = ?"
    );
    if (!$stmt) {
        api_error(500, 'Unable to check squad membership.');
    }
    $stmt->bind_param("s", $target_user_id);
    $stmt->execute();
    $memberships = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    if (empty($memberships)) {
        return;
    }

    $delete = $conn->prepare("DELETE FROM squad_members WHERE user_id = ?");
    if (!$delete) {
        api_error(500, 'Unable to remove old squad membership.');
    }
    $delete->bind_param("s", $target_user_id);
    $delete->execute();
    $delete->close();

    $notified = [];
    foreach ($memberships as $membership) {
        $leader_id = $membership['leader_user_id'] ?? null;
        if (!$leader_id || isset($notified[$leader_id])) {
            continue;
        }
        $notified[$leader_id] = true;
        $payload = json_encode([
            'reason' => 'location_transfer',
            'member_id' => $target_user_id,
            'squad_id' => $membership['squad_id'],
        ]);
        $title = 'Ahli skuad dipindahkan';
        $body = $target_name . ' telah dikeluarkan daripada ' . ($membership['squad_name'] ?? 'skuad') . ' kerana lokasi tugasan beliau dipindahkan.';

        $notify = $conn->prepare(
            "INSERT INTO notifications (id, user_id, actor_user_id, type, title, body, payload_json)
             VALUES (UUID(), ?, ?, 'squad_member_transferred', ?, ?, ?)"
        );
        if ($notify) {
            $notify->bind_param("sssss", $leader_id, $actor_id, $title, $body, $payload);
            $notify->execute();
            $notify->close();
        }
    }
}

$target_user = fetch_target_user($conn, $target_user_id);

if ($actor['role'] === 'ketua_krt') {
    if (in_array($target_user['role'], ['ketua_krt', 'super_admin'], true)) {
        api_error(403, 'Ketua KRT cannot modify Ketua KRT or Super Admin accounts.');
    }

    if (!actor_can_access_district($actor, $target_user['district_id'])) {
        api_error(403, 'Ketua KRT can only modify users in their own district.');
    }

    if (!in_array($action, ['update_status', 'promote_role'], true)) {
        api_error(403, 'Ketua KRT can only approve accounts or promote peronda roles.');
    }
}

if ($action === 'update_status') {
    $status = trim($_POST['account_status'] ?? '');
    if (!in_array($status, ['pending', 'active', 'inactive'], true)) {
        api_error(400, 'Invalid account status.');
    }

    if ($target_user['role'] === 'ketua_krt' && $status === 'active') {
        assert_one_active_krt_per_district($conn, $target_user['district_id'], $target_user_id);
    }

    $stmt = $conn->prepare("UPDATE users SET account_status = ? WHERE id = ?");
    $stmt->bind_param("ss", $status, $target_user_id);
    $ok = $stmt->execute();
    $stmt->close();
    echo json_encode($ok
        ? ["status" => "success", "message" => "Status akaun berjaya dikemas kini."]
        : ["status" => "error", "message" => "Status akaun gagal dikemas kini."]);
} elseif ($action === 'promote_role' || $action === 'update_role') {
    $role = trim($_POST['role'] ?? '');
    $allowed_roles = $actor['role'] === 'super_admin'
        ? ['peronda', 'ketua_peronda', 'ketua_krt', 'super_admin']
        : ['peronda', 'ketua_peronda'];

    if (!in_array($role, $allowed_roles, true)) {
        api_error(403, 'Invalid role selected for this administrator.');
    }
    if ($role === 'ketua_krt') {
        assert_one_active_krt_per_district($conn, $target_user['district_id'], $target_user_id);
    }

    $stmt = $conn->prepare("UPDATE users SET role = ? WHERE id = ?");
    $stmt->bind_param("ss", $role, $target_user_id);
    $ok = $stmt->execute();
    $stmt->close();
    echo json_encode($ok
        ? ["status" => "success", "message" => "User role updated successfully."]
        : ["status" => "error", "message" => "Failed to update user role."]);
} elseif ($action === 'update_profile') {
    require_role($actor, ['super_admin']);

    $full_name = trim(account_string($_POST['full_name'] ?? ''));
    $ic_number = account_normalize_ic($_POST['ic_number'] ?? '');
    $phone_number = account_string($_POST['phone_number'] ?? '');
    $email = trim(account_string($_POST['email'] ?? ''));

    if ($full_name === '' || $ic_number === '' || $phone_number === '' || $email === '') {
        api_error(400, 'Full name, IC number, phone number and email are required.');
    }

    $validation_error = account_ic_error($ic_number) ?? account_phone_error($phone_number);
    if ($validation_error !== null) api_error(422, $validation_error);
    $phone_number = account_normalize_phone($phone_number);

    $stmt = $conn->prepare("UPDATE users SET full_name = ?, ic_number = ?, phone_number = ?, email = ? WHERE id = ?");
    if (!$stmt) api_error(500, 'Failed to update user profile.');
    $stmt->bind_param("sssss", $full_name, $ic_number, $phone_number, $email, $target_user_id);
    try {
        $ok = $stmt->execute();
        $update_errno = $stmt->errno;
    } catch (mysqli_sql_exception $e) {
        $ok = false;
        $update_errno = (int) $e->getCode();
    }
    $stmt->close();
    if (!$ok && $update_errno === 1062) {
        api_error(409, 'No. Kad Pengenalan atau E-mel telah didaftarkan dalam sistem.');
    }
    echo json_encode($ok
        ? ["status" => "success", "message" => "User profile updated successfully."]
        : ["status" => "error", "message" => "Failed to update user profile."]);
} elseif ($action === 'transfer_location') {
    require_role($actor, ['super_admin']);

    $state_id = trim($_POST['state_id'] ?? '');
    $district_id = trim($_POST['district_id'] ?? '');
    $zone_id = trim($_POST['zone_id'] ?? '');
    if ($state_id === '' || $district_id === '' || $zone_id === '') {
        api_error(400, 'State, district and zone are required.');
    }

    if ($target_user['role'] === 'ketua_krt') {
        assert_one_active_krt_per_district($conn, $district_id, $target_user_id);
    }

    $location = validate_location_path($conn, $state_id, $district_id, $zone_id);
    $conn->begin_transaction();
    try {
        remove_from_squad_and_notify($conn, $actor['id'], $target_user_id, $target_user['full_name']);

        $stmt = $conn->prepare("UPDATE users SET state_id = ?, district_id = ?, zone_id = ?, district_zone = ? WHERE id = ?");
        if (!$stmt) {
            throw new Exception('Unable to update user location.');
        }
        $stmt->bind_param("sssss", $state_id, $district_id, $zone_id, $location['zone_name'], $target_user_id);
        $stmt->execute();
        $stmt->close();
        $conn->commit();
        echo json_encode(["status" => "success", "message" => "User location transferred successfully."]);
    } catch (Throwable $e) {
        $conn->rollback();
        api_error(500, 'Failed to transfer user location.');
    }
} elseif ($action === 'reset_password') {
    require_role($actor, ['super_admin']);

    $temporary_password = account_string($_POST['temporary_password'] ?? '');
    if (isset($_POST['temporary_password']) && !is_string($_POST['temporary_password'])) {
        api_error(422, 'Ruangan ini wajib diisi');
    }
    if ($temporary_password === '') {
        $temporary_password = 'SRS-' . substr(str_replace(['+', '/', '='], '', base64_encode(random_bytes(9))), 0, 10);
    }
    if (($validation_error = account_password_error($temporary_password)) !== null) {
        api_error(422, $validation_error);
    }

    $password_hash = password_hash($temporary_password, PASSWORD_BCRYPT);
    $stmt = $conn->prepare("UPDATE users SET password_hash = ?, must_change_password = 1 WHERE id = ?");
    $stmt->bind_param("ss", $password_hash, $target_user_id);
    $ok = $stmt->execute();
    $stmt->close();
    echo json_encode($ok
        ? ["status" => "success", "message" => "Password reset successfully.", "temporary_password" => $temporary_password]
        : ["status" => "error", "message" => "Failed to reset password."]);
} else {
    api_error(400, 'Invalid action.');
}

$conn->close();
?>
