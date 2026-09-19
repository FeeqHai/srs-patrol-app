<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

require_once '../config/db_connect.php';
require_once '../config/access_control.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$actor = get_current_actor($conn);
require_role($actor, ['ketua_krt', 'super_admin']);

$month_offset = isset($_GET['month_offset']) ? intval($_GET['month_offset']) : 0;
$level = trim($_GET['level'] ?? 'daerah');
$state_id = trim($_GET['state_id'] ?? '');
$district_id = trim($_GET['district_id'] ?? '');
$zone_id = trim($_GET['zone_id'] ?? '');
$requested_state_id = $state_id;
$requested_district_id = $district_id;
$requested_zone_id = $zone_id;

$target_timestamp = strtotime("-{$month_offset} months");
$target_month = date('m', $target_timestamp);
$target_year = date('Y', $target_timestamp);

function fetch_label($conn, $table, $id) {
    if ($id === '') {
        return null;
    }
    $allowed = ['states', 'districts', 'zones'];
    if (!in_array($table, $allowed, true)) {
        api_error(500, 'Invalid location label request.');
    }
    $stmt = $conn->prepare("SELECT name FROM {$table} WHERE id = ?");
    if (!$stmt) {
        api_error(500, 'Unable to resolve location label.');
    }
    $stmt->bind_param('s', $id);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $row['name'] ?? null;
}

function validate_filter_path($conn, $state_id, $district_id, $zone_id) {
    if ($zone_id !== '') {
        $stmt = $conn->prepare(
            "SELECT z.id
             FROM zones z
             JOIN districts d ON d.id = z.district_id
             JOIN states s ON s.id = d.state_id
             WHERE z.id = ? AND d.id = ? AND s.id = ?"
        );
        $stmt->bind_param('sss', $zone_id, $district_id, $state_id);
    } elseif ($district_id !== '') {
        $stmt = $conn->prepare("SELECT id FROM districts WHERE id = ? AND state_id = ?");
        $stmt->bind_param('ss', $district_id, $state_id);
    } elseif ($state_id !== '') {
        $stmt = $conn->prepare("SELECT id FROM states WHERE id = ?");
        $stmt->bind_param('s', $state_id);
    } else {
        return;
    }

    if (!$stmt) {
        api_error(500, 'Unable to validate location filter.');
    }
    $stmt->execute();
    $ok = $stmt->get_result()->num_rows === 1;
    $stmt->close();
    if (!$ok) {
        api_error(400, 'Invalid state, district or zone filter.');
    }
}

if ($actor['role'] === 'ketua_krt') {
    if ($requested_state_id !== '' && $requested_state_id !== ($actor['state_id'] ?? '')) {
        api_error(403, 'Ketua KRT cannot query another state.');
    }
    if ($requested_district_id !== '' && $requested_district_id !== ($actor['district_id'] ?? '')) {
        api_error(403, 'Ketua KRT cannot query another district.');
    }
    $state_id = $actor['state_id'] ?? '';
    $district_id = $actor['district_id'] ?? '';
    if ($state_id === '' || $district_id === '') {
        api_error(403, 'Ketua KRT account has no district scope.');
    }
    if ($requested_zone_id !== '') {
        validate_filter_path($conn, $state_id, $district_id, $zone_id);
    }
} else {
    if ($district_id !== '' && $state_id === '') {
        api_error(400, 'State filter is required before district filter.');
    }
    if ($zone_id !== '' && ($state_id === '' || $district_id === '')) {
        api_error(400, 'State and district filters are required before zone filter.');
    }
    validate_filter_path($conn, $state_id, $district_id, $zone_id);
}

$groups = [
    "A. JENAYAH KEKERASAN" => [
        "1. Pembunuhan" => "Jenayah Kekerasan - Pembunuhan",
        "2. Rogol" => "Jenayah Kekerasan - Rogol",
        "3. Cabul Kehormatan" => "Jenayah Kekerasan - Cabul Kehormatan",
        "4. Samun" => "Jenayah Kekerasan - Samun",
        "5. Peras Ugut" => "Jenayah Kekerasan - Peras Ugut",
        "6. Merusuh" => "Jenayah Kekerasan - Merusuh",
        "7. Mencedera / Penderaan" => "Jenayah Kekerasan - Mencedera / Penderaan"
    ],
    "B. JENAYAH HARTA BENDA" => [
        "1. Curi Kenderaan" => "Jenayah Harta Benda - Curi Kenderaan",
        "2. Curi Harta Benda" => "Jenayah Harta Benda - Curi Harta Benda",
        "3. Pecah Rumah" => "Jenayah Harta Benda - Pecah Rumah"
    ],
    "C. JENAYAH NARKOTIK" => [
        "1. Pengedaran Dadah" => "Jenayah Narkotik - Pengedaran Dadah",
        "2. Memiliki Dadah" => "Jenayah Narkotik - Memiliki Dadah"
    ],
    "D. GEJALA SOSIAL" => [
        "1. Pertengkaran" => "Gejala Sosial - Pertengkaran",
        "2. Lepak" => "Gejala Sosial - Lepak",
        "3. Vandalisme" => "Gejala Sosial - Vandalisme",
        "4. Khalwat / Maksiat" => "Gejala Sosial - Khalwat / Maksiat",
        "5. Pergaduhan" => "Gejala Sosial - Pergaduhan",
        "6. Pendatang Tanpa Izin" => "Gejala Sosial - Pendatang Tanpa Izin",
        "7. Lumba Haram" => "Gejala Sosial - Lumba Haram",
        "8. Penagihan Dadah" => "Gejala Sosial - Penagihan Dadah",
        "9. Masalah Rumah Tangga" => "Gejala Sosial - Masalah Rumah Tangga",
        "10. Ponteng" => "Gejala Sosial - Ponteng",
        "11. Kutu Rayau" => "Gejala Sosial - Kutu Rayau",
        "12. Buang Bayi" => "Gejala Sosial - Buang Bayi",
        "13. Lain-Lain Kes" => "Lain-lain"
    ]
];

$summary = [];
foreach ($groups as $groupName => $subcats) {
    $summary[$groupName] = [];
    foreach ($subcats as $name => $key) {
        $summary[$groupName][$name] = [
            "total" => 0,
            "polis" => 0,
            "agama" => 0,
            "pbt" => 0,
            "obb" => 0,
            "lain" => 0
        ];
    }
}

$where = ["MONTH(i.created_at) = ?", "YEAR(i.created_at) = ?"];
$params = [$target_month, $target_year];
$types = "ss";

if ($state_id !== '') {
    $where[] = "COALESCE(i.state_id, u.state_id) = ?";
    $params[] = $state_id;
    $types .= "s";
}
if ($district_id !== '') {
    $where[] = "COALESCE(i.district_id, u.district_id) = ?";
    $params[] = $district_id;
    $types .= "s";
}
if ($zone_id !== '') {
    $where[] = "COALESCE(i.zone_id, u.zone_id) = ?";
    $params[] = $zone_id;
    $types .= "s";
}

$query = "
    SELECT i.category, i.reported_to
    FROM incidents i
    JOIN users u ON i.user_id = u.id
    WHERE " . implode(' AND ', $where);

$stmt = $conn->prepare($query);
if (!$stmt) {
    api_error(500, 'Database error while loading report summary.');
}
if (count($params) === 2) {
    $stmt->bind_param($types, $params[0], $params[1]);
} elseif (count($params) === 3) {
    $stmt->bind_param($types, $params[0], $params[1], $params[2]);
} elseif (count($params) === 4) {
    $stmt->bind_param($types, $params[0], $params[1], $params[2], $params[3]);
} elseif (count($params) === 5) {
    $stmt->bind_param($types, $params[0], $params[1], $params[2], $params[3], $params[4]);
}
$stmt->execute();
$res = $stmt->get_result();

while ($row = $res->fetch_assoc()) {
    $cat = $row['category'];
    $ref = $row['reported_to'];

    $ref_code = 'lain';
    if ($ref === 'Polis') {
        $ref_code = 'polis';
    } elseif ($ref === 'Jabatan Agama / JAKIM' || $ref === 'Jabatan Agama') {
        $ref_code = 'agama';
    } elseif ($ref === 'PBT') {
        $ref_code = 'pbt';
    } elseif ($ref === 'JKM' || $ref === 'OBB') {
        $ref_code = 'obb';
    }

    $matched = false;
    foreach ($groups as $groupName => $subcats) {
        foreach ($subcats as $name => $dbKey) {
            if ($dbKey === $cat) {
                $summary[$groupName][$name]['total']++;
                $summary[$groupName][$name][$ref_code]++;
                $matched = true;
                break 2;
            }
        }
    }

    if (!$matched) {
        $summary["D. GEJALA SOSIAL"]["13. Lain-Lain Kes"]['total']++;
        $summary["D. GEJALA SOSIAL"]["13. Lain-Lain Kes"][$ref_code]++;
    }
}

$month_names_my = ["Januari", "Februari", "Mac", "April", "Mei", "Jun", "Julai", "Ogos", "September", "Oktober", "November", "Disember"];
$month_str = $month_names_my[(int)$target_month - 1];

$state_label = fetch_label($conn, 'states', $state_id) ?? 'Semua Negeri';
$district_label = fetch_label($conn, 'districts', $district_id) ?? ($state_id === '' ? 'Semua Daerah' : 'Semua Daerah');
$zone_label = fetch_label($conn, 'zones', $zone_id) ?? ($district_id === '' ? 'Semua Zon' : 'Semua Zon');

echo json_encode([
    "status" => "success",
    "month_label" => $month_str,
    "year_label" => $target_year,
    "metadata" => [
        "negeri" => $state_label,
        "daerah" => $district_label,
        "zone" => $zone_label,
        "nama_srs" => $zone_id !== '' ? "KRT " . $zone_label : "Semua KRT",
        "admin_name" => $actor['full_name'],
        "level" => $level,
        "filters" => [
            "state_id" => $state_id,
            "district_id" => $district_id,
            "zone_id" => $zone_id,
            "state_label" => $state_label,
            "district_label" => $district_label,
            "zone_label" => $zone_label
        ]
    ],
    "data" => $summary
]);

$stmt->close();
$conn->close();
?>
