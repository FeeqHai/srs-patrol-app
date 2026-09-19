<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json; charset=UTF-8");

require_once '../config/db_connect.php';
require_once '../config/access_control.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

function bind_values($stmt, $types, &$values) {
    if ($types === '') {
        return;
    }
    $refs = [];
    $refs[] = $types;
    foreach ($values as $key => &$value) {
        $refs[] = &$value;
    }
    call_user_func_array([$stmt, 'bind_param'], $refs);
}

function squad_scope_clause($actor, &$types, &$params) {
    if ($actor['role'] === 'super_admin') {
        return '1 = 1';
    }
    if ($actor['role'] === 'ketua_krt') {
        $types .= 's';
        $params[] = $actor['district_id'];
        return 's.district_id = ?';
    }
    $types .= 's';
    $params[] = $actor['id'];
    return 'EXISTS (
        SELECT 1 FROM squad_members own_sm
        WHERE own_sm.squad_id = s.id AND own_sm.user_id = ?
    )';
}

function ensure_squad_allowed($conn, $actor, $squad_id) {
    $types = 's';
    $params = [$squad_id];
    $scope_types = '';
    $scope_params = [];
    $scope = squad_scope_clause($actor, $scope_types, $scope_params);
    $types .= $scope_types;
    $params = array_merge($params, $scope_params);

    $stmt = $conn->prepare("SELECT s.* FROM squads s WHERE s.id = ? AND {$scope} LIMIT 1");
    if (!$stmt) {
        api_error(500, 'Unable to verify squad scope.');
    }
    bind_values($stmt, $types, $params);
    $stmt->execute();
    $squad = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$squad) {
        api_error(403, 'You cannot manage this squad.');
    }
    return $squad;
}

$method = $_SERVER['REQUEST_METHOD'];
$actor = get_current_actor($conn);

try {
    if ($method === 'GET') {
        $types = '';
        $params = [];
        $where = [squad_scope_clause($actor, $types, $params)];

        foreach (['state_id' => 's.state_id', 'district_id' => 's.district_id', 'zone_id' => 's.zone_id'] as $query_key => $column) {
            $value = trim($_GET[$query_key] ?? '');
            if ($value !== '') {
                $where[] = "{$column} = ?";
                $types .= 's';
                $params[] = $value;
            }
        }

        $sql = "SELECT s.id AS squad_id, s.name AS squad_name, s.state_id, s.district_id, s.zone_id,
                       st.name AS state_name, d.name AS district_name, z.name AS zone_name,
                       s.created_at, sm.user_id, sm.role, u.full_name, u.ic_number,
                       u.state_id AS member_state_id, u.district_id AS member_district_id, u.zone_id AS member_zone_id,
                       ust.name AS member_state_name, ud.name AS member_district_name, uz.name AS member_zone_name
                FROM squads s
                LEFT JOIN states st ON st.id = s.state_id
                LEFT JOIN districts d ON d.id = s.district_id
                LEFT JOIN zones z ON z.id = s.zone_id
                LEFT JOIN squad_members sm ON s.id = sm.squad_id
                LEFT JOIN users u ON sm.user_id = u.id
                LEFT JOIN states ust ON ust.id = u.state_id
                LEFT JOIN districts ud ON ud.id = u.district_id
                LEFT JOIN zones uz ON uz.id = u.zone_id
                WHERE " . implode(' AND ', $where) . "
                ORDER BY s.created_at DESC, u.full_name ASC";

        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            api_error(500, 'Unable to load squads.');
        }
        bind_values($stmt, $types, $params);
        $stmt->execute();
        $results = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $stmt->close();

        $squads = [];
        foreach ($results as $row) {
            $squad_id = $row['squad_id'];
            if (!isset($squads[$squad_id])) {
                $squads[$squad_id] = [
                    'id' => $squad_id,
                    'name' => $row['squad_name'],
                    'state_id' => $row['state_id'],
                    'district_id' => $row['district_id'],
                    'zone_id' => $row['zone_id'],
                    'state_name' => $row['state_name'],
                    'district_name' => $row['district_name'],
                    'zone_name' => $row['zone_name'],
                    'created_at' => $row['created_at'],
                    'members' => []
                ];
            }
            if ($row['user_id']) {
                $squads[$squad_id]['members'][] = [
                    'user_id' => $row['user_id'],
                    'role' => $row['role'],
                    'full_name' => $row['full_name'],
                    'ic_number' => $row['ic_number'],
                    'member_state_id' => $row['member_state_id'],
                    'member_district_id' => $row['member_district_id'],
                    'member_zone_id' => $row['member_zone_id'],
                    'member_state_name' => $row['member_state_name'],
                    'member_district_name' => $row['member_district_name'],
                    'member_zone_name' => $row['member_zone_name']
                ];
            }
        }

        echo json_encode(['status' => 'success', 'message' => 'Squads loaded.', 'data' => array_values($squads)]);
    } elseif ($method === 'POST') {
        $json = file_get_contents('php://input');
        $data = json_decode($json, true);
        if (is_array($data)) {
            $_POST = array_merge($_POST, $data);
        }

        $action = $_POST['action'] ?? '';

        if ($action === 'create_squad') {
            require_role($actor, ['super_admin', 'ketua_krt']);
            $name = trim($_POST['name'] ?? '');
            if ($name === '') {
                api_error(400, 'Squad name is required.');
            }

            $state_id = $actor['role'] === 'super_admin' ? ($_POST['state_id'] ?? null) : $actor['state_id'];
            $district_id = $actor['role'] === 'super_admin' ? ($_POST['district_id'] ?? null) : $actor['district_id'];
            $zone_id = trim($_POST['zone_id'] ?? '');
            $zone_id = $zone_id === '' ? null : $zone_id;
            $head_user_id = trim($_POST['head_user_id'] ?? '');
            $member_ids_raw = $_POST['member_ids'] ?? '';
            if (is_array($member_ids_raw)) {
                $member_ids = $member_ids_raw;
            } else {
                $member_ids = explode(',', $member_ids_raw);
            }
            $member_ids = array_values(array_unique(array_filter(array_map('trim', $member_ids))));

            if (!$state_id || !$district_id) {
                api_error(400, 'State and district are required.');
            }
            if ($head_user_id === '') {
                api_error(400, 'Head patroller is required.');
            }
            if (in_array($head_user_id, $member_ids, true)) {
                api_error(400, 'Head patroller cannot also be selected as a patroller.');
            }
            if (count($member_ids) < 2 || count($member_ids) > 20) {
                api_error(400, 'Please select between 2 and 20 patrollers.');
            }

            $district_stmt = $conn->prepare("SELECT id FROM districts WHERE id = ? AND state_id = ? LIMIT 1");
            if (!$district_stmt) {
                api_error(500, 'Unable to verify district.');
            }
            $district_stmt->bind_param('ss', $district_id, $state_id);
            $district_stmt->execute();
            $district_ok = $district_stmt->get_result()->fetch_assoc();
            $district_stmt->close();
            if (!$district_ok) {
                api_error(400, 'District does not belong to the selected state.');
            }

            $selected_user_ids = array_merge([$head_user_id], $member_ids);
            $placeholders = implode(',', array_fill(0, count($selected_user_ids), '?'));
            $user_sql = "SELECT u.id, u.full_name, u.role, u.account_status, u.district_id,
                                sm.squad_id, existing.name AS squad_name
                         FROM users u
                         LEFT JOIN squad_members sm ON sm.user_id = u.id
                         LEFT JOIN squads existing ON existing.id = sm.squad_id
                         WHERE u.id IN ($placeholders)";
            $user_stmt = $conn->prepare($user_sql);
            if (!$user_stmt) {
                api_error(500, 'Unable to verify squad members.');
            }
            $user_types = str_repeat('s', count($selected_user_ids));
            bind_values($user_stmt, $user_types, $selected_user_ids);
            $user_stmt->execute();
            $users = [];
            $user_result = $user_stmt->get_result();
            while ($row = $user_result->fetch_assoc()) {
                $users[$row['id']] = $row;
            }
            $user_stmt->close();

            foreach ($selected_user_ids as $user_id) {
                if (!isset($users[$user_id])) {
                    api_error(400, 'Selected user was not found.');
                }
                $user = $users[$user_id];
                if (($user['account_status'] ?? '') !== 'active') {
                    api_error(400, ($user['full_name'] ?? 'Selected user') . ' is not active.');
                }
                if (($user['district_id'] ?? '') !== $district_id) {
                    api_error(400, ($user['full_name'] ?? 'Selected user') . ' is outside the selected district.');
                }
                if (!empty($user['squad_id'])) {
                    api_error(400, ($user['full_name'] ?? 'Selected user') . ' is already assigned to ' . ($user['squad_name'] ?? 'another squad') . '.');
                }
            }
            if (($users[$head_user_id]['role'] ?? '') !== 'ketua_peronda') {
                api_error(400, 'Head patroller must have the Ketua Peronda role.');
            }
            foreach ($member_ids as $member_id) {
                if (($users[$member_id]['role'] ?? '') !== 'peronda') {
                    api_error(400, ($users[$member_id]['full_name'] ?? 'Selected user') . ' must have the Peronda role.');
                }
            }

            $id = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
                mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff),
                mt_rand(0, 0x0fff) | 0x4000, mt_rand(0, 0x3fff) | 0x8000,
                mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
            );

            $conn->begin_transaction();
            try {
                $stmt = $conn->prepare("INSERT INTO squads (id, name, state_id, district_id, zone_id) VALUES (?, ?, ?, ?, ?)");
                if (!$stmt) {
                    throw new Exception('Unable to create squad.');
                }
                $stmt->bind_param('sssss', $id, $name, $state_id, $district_id, $zone_id);
                if (!$stmt->execute()) {
                    throw new Exception('Unable to create squad.');
                }
                $stmt->close();

                $member_stmt = $conn->prepare("INSERT INTO squad_members (squad_id, user_id, role) VALUES (?, ?, ?)");
                if (!$member_stmt) {
                    throw new Exception('Unable to add squad members.');
                }
                $role = 'leader';
                $member_stmt->bind_param('sss', $id, $head_user_id, $role);
                if (!$member_stmt->execute()) {
                    throw new Exception('Unable to add head patroller.');
                }
                $role = 'member';
                foreach ($member_ids as $member_id) {
                    $member_stmt->bind_param('sss', $id, $member_id, $role);
                    if (!$member_stmt->execute()) {
                        throw new Exception('Unable to add patrollers.');
                    }
                }
                $member_stmt->close();
                $conn->commit();
            } catch (Exception $e) {
                $conn->rollback();
                api_error(500, $e->getMessage());
            }

            echo json_encode(['status' => 'success', 'message' => 'Squad created successfully', 'squad_id' => $id]);
        } elseif ($action === 'add_member') {
            require_role($actor, ['super_admin', 'ketua_krt']);
            $squad_id = trim($_POST['squad_id'] ?? '');
            $user_id = trim($_POST['user_id'] ?? '');
            $role = $_POST['role'] ?? 'member';

            if ($squad_id === '' || $user_id === '') {
                api_error(400, 'Squad ID and User ID are required.');
            }

            $squad = ensure_squad_allowed($conn, $actor, $squad_id);

            $user_stmt = $conn->prepare(
                "SELECT id, role, district_id, zone_id
                 FROM users
                 WHERE id = ? AND account_status = 'active'
                 LIMIT 1"
            );
            if (!$user_stmt) {
                api_error(500, 'Unable to verify user.');
            }
            $user_stmt->bind_param('s', $user_id);
            $user_stmt->execute();
            $user = $user_stmt->get_result()->fetch_assoc();
            $user_stmt->close();
            if (
                !$user ||
                !in_array($user['role'], ['peronda', 'ketua_peronda'], true) ||
                $user['district_id'] !== $squad['district_id']
            ) {
                api_error(403, 'User is outside this squad district.');
            }

            $check = $conn->prepare("SELECT sm.*, s.name AS squad_name FROM squad_members sm JOIN squads s ON sm.squad_id = s.id WHERE sm.user_id = ?");
            $check->bind_param('s', $user_id);
            $check->execute();
            $check_res = $check->get_result();
            if ($check_res->num_rows > 0) {
                $row = $check_res->fetch_assoc();
                $check->close();
                api_error(400, 'Peronda sudah ditugaskan ke kumpulan lain (' . $row['squad_name'] . ')');
            }
            $check->close();

            $stmt = $conn->prepare("INSERT INTO squad_members (squad_id, user_id, role) VALUES (?, ?, ?)");
            $stmt->bind_param('sss', $squad_id, $user_id, $role);
            if (!$stmt->execute()) {
                $stmt->close();
                api_error(500, 'Unable to add member.');
            }
            $stmt->close();

            echo json_encode(['status' => 'success', 'message' => 'Member added to squad']);
        } elseif ($action === 'delete_squad') {
            require_role($actor, ['super_admin', 'ketua_krt']);
            $squad_id = trim($_POST['squad_id'] ?? '');
            if ($squad_id === '') {
                api_error(400, 'Squad ID is required.');
            }
            ensure_squad_allowed($conn, $actor, $squad_id);

            $conn->begin_transaction();
            try {
                $stmt1 = $conn->prepare("DELETE FROM squad_members WHERE squad_id = ?");
                $stmt1->bind_param('s', $squad_id);
                $stmt1->execute();
                $stmt1->close();

                $stmt2 = $conn->prepare("DELETE FROM schedules WHERE squad_id = ?");
                $stmt2->bind_param('s', $squad_id);
                $stmt2->execute();
                $stmt2->close();

                $stmt3 = $conn->prepare("DELETE FROM squads WHERE id = ?");
                $stmt3->bind_param('s', $squad_id);
                $stmt3->execute();
                $stmt3->close();

                $conn->commit();
                echo json_encode(['status' => 'success', 'message' => 'Squad deleted successfully']);
            } catch (Exception $e) {
                $conn->rollback();
                api_error(500, 'Failed to delete squad: ' . $e->getMessage());
            }
        } elseif ($action === 'remove_member') {
            require_role($actor, ['super_admin', 'ketua_krt']);
            $squad_id = trim($_POST['squad_id'] ?? '');
            $user_id = trim($_POST['user_id'] ?? '');

            if ($squad_id === '' || $user_id === '') {
                api_error(400, 'Squad ID and User ID are required.');
            }
            ensure_squad_allowed($conn, $actor, $squad_id);

            $stmt = $conn->prepare("DELETE FROM squad_members WHERE squad_id = ? AND user_id = ?");
            $stmt->bind_param('ss', $squad_id, $user_id);
            if (!$stmt->execute()) {
                $stmt->close();
                api_error(500, 'Unable to remove member.');
            }
            $stmt->close();

            echo json_encode(['status' => 'success', 'message' => 'Member removed from squad']);
        } else {
            api_error(400, 'Invalid action.');
        }
    } else {
        api_error(405, 'Invalid request method.');
    }
} catch(Exception $e) {
    api_error(500, 'Database error: ' . $e->getMessage());
}
?>
