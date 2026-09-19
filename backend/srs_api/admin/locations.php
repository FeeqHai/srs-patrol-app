<?php
header('Content-Type: application/json');
require_once '../config/db_connect.php';
require_once '../config/access_control.php';

$actor = get_current_actor($conn);
require_role($actor, ['super_admin']);

$action = trim($_GET['action'] ?? $_POST['action'] ?? 'list');

function location_response($payload) {
    echo json_encode($payload);
    exit();
}

function ensure_non_empty($value, $message) {
    if (trim($value) === '') {
        api_error(400, $message);
    }
}

function duplicate_location_message($type) {
    if ($type === 'state') {
        return 'State code or state name already exists.';
    }
    if ($type === 'district') {
        return 'District name already exists in this state.';
    }
    if ($type === 'zone') {
        return 'Zone name already exists in this district.';
    }
    return 'Location already exists.';
}

function execute_location_stmt($stmt, $success_message, $failure_message, $duplicate_type) {
    try {
        if ($stmt->execute()) {
            location_response(["status" => "success", "message" => $success_message]);
        }
        location_response(["status" => "error", "message" => $failure_message]);
    } catch (mysqli_sql_exception $e) {
        if ((int)$e->getCode() === 1062) {
            location_response([
                "status" => "error",
                "message" => duplicate_location_message($duplicate_type)
            ]);
        }
        error_log('Location management DB error: ' . $e->getMessage());
        location_response(["status" => "error", "message" => $failure_message]);
    }
}

function execute_simple_location_stmt($stmt, $success_message, $failure_message) {
    try {
        if ($stmt->execute()) {
            location_response(["status" => "success", "message" => $success_message]);
        }
        location_response(["status" => "error", "message" => $failure_message]);
    } catch (mysqli_sql_exception $e) {
        error_log('Location management DB error: ' . $e->getMessage());
        location_response(["status" => "error", "message" => $failure_message]);
    }
}

function location_has_usage($conn, $table, $column, $id) {
    $allowed_tables = ['users', 'incidents', 'attendance', 'squads'];
    $allowed_columns = ['state_id', 'district_id', 'zone_id'];
    if (!in_array($table, $allowed_tables, true) || !in_array($column, $allowed_columns, true)) {
        api_error(500, 'Invalid usage check.');
    }
    $sql = "SELECT COUNT(*) AS count FROM {$table} WHERE {$column} = ?";
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        api_error(500, 'Unable to check location usage.');
    }
    $stmt->bind_param('s', $id);
    $stmt->execute();
    $count = (int)($stmt->get_result()->fetch_assoc()['count'] ?? 0);
    $stmt->close();
    return $count > 0;
}

function location_usage_count($conn, $column, $id) {
    $total = 0;
    foreach (['users', 'incidents', 'attendance', 'squads'] as $table) {
        $sql = "SELECT COUNT(*) AS count FROM {$table} WHERE {$column} = ?";
        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            api_error(500, 'Unable to check location usage.');
        }
        $stmt->bind_param('s', $id);
        $stmt->execute();
        $total += (int)($stmt->get_result()->fetch_assoc()['count'] ?? 0);
        $stmt->close();
    }
    return $total;
}

if ($action === 'list') {
    $states = [];
    $result = $conn->query("SELECT id, code, name, is_active FROM states ORDER BY name ASC");
    while ($row = $result->fetch_assoc()) {
        $row['districts'] = [];
        $row['usage_count'] = location_usage_count($conn, 'state_id', $row['id']);
        $states[$row['id']] = $row;
    }

    $districts = [];
    $result = $conn->query("SELECT id, state_id, name, is_active FROM districts ORDER BY name ASC");
    while ($row = $result->fetch_assoc()) {
        $row['zones'] = [];
        $row['usage_count'] = location_usage_count($conn, 'district_id', $row['id']);
        $districts[$row['id']] = $row;
        if (isset($states[$row['state_id']])) {
            $states[$row['state_id']]['districts'][] = &$districts[$row['id']];
        }
    }
    unset($row);

    $result = $conn->query("SELECT id, district_id, name, is_active FROM zones ORDER BY name ASC");
    while ($row = $result->fetch_assoc()) {
        $row['usage_count'] = location_usage_count($conn, 'zone_id', $row['id']);
        if (isset($districts[$row['district_id']])) {
            $districts[$row['district_id']]['zones'][] = $row;
        }
    }

    location_response(["status" => "success", "data" => array_values($states)]);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_error(405, 'Invalid request method.');
}

if ($action === 'create_state') {
    $name = trim($_POST['name'] ?? '');
    $code = strtoupper(trim($_POST['code'] ?? ''));
    ensure_non_empty($name, 'State name is required.');
    ensure_non_empty($code, 'State code is required.');

    $stmt = $conn->prepare("INSERT INTO states (id, code, name, is_active) VALUES (UUID(), ?, ?, 1)");
    $stmt->bind_param('ss', $code, $name);
    execute_location_stmt($stmt, "State created.", "Unable to create state.", "state");
}

if ($action === 'create_district') {
    $state_id = trim($_POST['state_id'] ?? '');
    $name = trim($_POST['name'] ?? '');
    ensure_non_empty($state_id, 'State is required.');
    ensure_non_empty($name, 'District name is required.');

    $stmt = $conn->prepare("INSERT INTO districts (id, state_id, name, is_active) VALUES (UUID(), ?, ?, 1)");
    $stmt->bind_param('ss', $state_id, $name);
    execute_location_stmt($stmt, "District created.", "Unable to create district.", "district");
}

if ($action === 'create_zone') {
    $district_id = trim($_POST['district_id'] ?? '');
    $name = trim($_POST['name'] ?? '');
    ensure_non_empty($district_id, 'District is required.');
    ensure_non_empty($name, 'Zone name is required.');

    $stmt = $conn->prepare("INSERT INTO zones (id, district_id, name, is_active) VALUES (UUID(), ?, ?, 1)");
    $stmt->bind_param('ss', $district_id, $name);
    execute_location_stmt($stmt, "Zone created.", "Unable to create zone.", "zone");
}

if ($action === 'update') {
    $type = trim($_POST['type'] ?? '');
    $id = trim($_POST['id'] ?? '');
    $name = trim($_POST['name'] ?? '');
    $code = strtoupper(trim($_POST['code'] ?? ''));
    ensure_non_empty($id, 'Location id is required.');
    ensure_non_empty($name, 'Location name is required.');

    if ($type === 'state') {
        ensure_non_empty($code, 'State code is required.');
        $stmt = $conn->prepare("UPDATE states SET code = ?, name = ? WHERE id = ?");
        $stmt->bind_param('sss', $code, $name, $id);
    } elseif ($type === 'district') {
        $stmt = $conn->prepare("UPDATE districts SET name = ? WHERE id = ?");
        $stmt->bind_param('ss', $name, $id);
    } elseif ($type === 'zone') {
        $stmt = $conn->prepare("UPDATE zones SET name = ? WHERE id = ?");
        $stmt->bind_param('ss', $name, $id);
    } else {
        api_error(400, 'Invalid location type.');
    }

    execute_location_stmt($stmt, "Location updated.", "Unable to update location.", $type);
}

if ($action === 'deactivate') {
    $type = trim($_POST['type'] ?? '');
    $id = trim($_POST['id'] ?? '');
    ensure_non_empty($id, 'Location id is required.');

    if ($type === 'state') {
        try {
            $conn->begin_transaction();
            $stmt = $conn->prepare("UPDATE states SET is_active = 0 WHERE id = ?");
            $stmt->bind_param('s', $id);
            $stmt->execute();
            $stmt = $conn->prepare("UPDATE districts SET is_active = 0 WHERE state_id = ?");
            $stmt->bind_param('s', $id);
            $stmt->execute();
            $stmt = $conn->prepare("UPDATE zones z JOIN districts d ON d.id = z.district_id SET z.is_active = 0 WHERE d.state_id = ?");
            $stmt->bind_param('s', $id);
            $stmt->execute();
            $conn->commit();
            location_response(["status" => "success", "message" => "Location deactivated. Linked records are preserved."]);
        } catch (mysqli_sql_exception $e) {
            $conn->rollback();
            error_log('Location management DB error: ' . $e->getMessage());
            location_response(["status" => "error", "message" => "Unable to deactivate location."]);
        }
    } elseif ($type === 'district') {
        try {
            $conn->begin_transaction();
            $stmt = $conn->prepare("UPDATE districts SET is_active = 0 WHERE id = ?");
            $stmt->bind_param('s', $id);
            $stmt->execute();
            $stmt = $conn->prepare("UPDATE zones SET is_active = 0 WHERE district_id = ?");
            $stmt->bind_param('s', $id);
            $stmt->execute();
            $conn->commit();
            location_response(["status" => "success", "message" => "Location deactivated. Linked records are preserved."]);
        } catch (mysqli_sql_exception $e) {
            $conn->rollback();
            error_log('Location management DB error: ' . $e->getMessage());
            location_response(["status" => "error", "message" => "Unable to deactivate location."]);
        }
    } elseif ($type === 'zone') {
        $stmt = $conn->prepare("UPDATE zones SET is_active = 0 WHERE id = ?");
    } else {
        api_error(400, 'Invalid location type.');
    }
    $stmt->bind_param('s', $id);
    execute_simple_location_stmt($stmt, "Location deactivated.", "Unable to deactivate location.");
}

if ($action === 'activate') {
    $type = trim($_POST['type'] ?? '');
    $id = trim($_POST['id'] ?? '');
    ensure_non_empty($id, 'Location id is required.');

    if ($type === 'state') {
        $stmt = $conn->prepare("UPDATE states SET is_active = 1 WHERE id = ?");
    } elseif ($type === 'district') {
        $parent = $conn->prepare("SELECT st.is_active FROM districts d JOIN states st ON st.id = d.state_id WHERE d.id = ?");
        $parent->bind_param('s', $id);
        $parent->execute();
        $row = $parent->get_result()->fetch_assoc();
        $parent->close();
        if (!$row || (int)$row['is_active'] !== 1) {
            location_response(["status" => "error", "message" => "Activate the parent state first."]);
        }
        $stmt = $conn->prepare("UPDATE districts SET is_active = 1 WHERE id = ?");
    } elseif ($type === 'zone') {
        $parent = $conn->prepare("SELECT d.is_active AS district_active, st.is_active AS state_active FROM zones z JOIN districts d ON d.id = z.district_id JOIN states st ON st.id = d.state_id WHERE z.id = ?");
        $parent->bind_param('s', $id);
        $parent->execute();
        $row = $parent->get_result()->fetch_assoc();
        $parent->close();
        if (!$row || (int)$row['district_active'] !== 1 || (int)$row['state_active'] !== 1) {
            location_response(["status" => "error", "message" => "Activate the parent state and district first."]);
        }
        $stmt = $conn->prepare("UPDATE zones SET is_active = 1 WHERE id = ?");
    } else {
        api_error(400, 'Invalid location type.');
    }
    $stmt->bind_param('s', $id);
    execute_simple_location_stmt($stmt, "Location activated.", "Unable to activate location.");
}

api_error(400, 'Invalid location action.');
?>
