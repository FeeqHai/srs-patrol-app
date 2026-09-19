<?php
require_once __DIR__ . '/hosting.php';
// File: config/jwt_utils.php

// DO NOT leak this key in production.
$deployment_secret = srs_config('SRS_JWT_SECRET');
if (!is_string($deployment_secret) || strlen($deployment_secret) < 32) {
    http_response_code(503);
    header('Content-Type: application/json');
    echo json_encode(['status' => 'error', 'message' => 'Server configuration is incomplete.']);
    exit();
}
define('JWT_SECRET', $deployment_secret);
unset($deployment_secret);

function generate_jwt($user_id, $role, $zone, $state_id = null, $district_id = null, $zone_id = null) {
    $header = json_encode(['typ' => 'JWT', 'alg' => 'HS256']);
    $payload = json_encode([
        'user_id' => $user_id,
        'role' => $role,
        'zone' => $zone,
        'state_id' => $state_id,
        'district_id' => $district_id,
        'zone_id' => $zone_id,
        'exp' => time() + (86400 * 7) // Token expires in 7 days
    ]);

    $base64UrlHeader = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($header));
    $base64UrlPayload = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($payload));

    $signature = hash_hmac('sha256', $base64UrlHeader . "." . $base64UrlPayload, JWT_SECRET, true);
    $base64UrlSignature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($signature));

    return $base64UrlHeader . "." . $base64UrlPayload . "." . $base64UrlSignature;
}

function verify_jwt($jwt) {
    $tokenParts = explode('.', $jwt);
    if (count($tokenParts) != 3) return false;

    $header = base64_decode(str_replace(['-', '_'], ['+', '/'], $tokenParts[0]));
    $payload = base64_decode(str_replace(['-', '_'], ['+', '/'], $tokenParts[1]));
    $signature_provided = $tokenParts[2];

    // Re-create the signature
    $base64UrlHeader = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($header));
    $base64UrlPayload = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($payload));
    $signature = hash_hmac('sha256', $base64UrlHeader . "." . $base64UrlPayload, JWT_SECRET, true);
    $base64UrlSignature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($signature));

    // Verify signature and expiration
    if (hash_equals($base64UrlSignature, $signature_provided)) {
        $decoded_payload = json_decode($payload, true);
        if (is_array($decoded_payload) && isset($decoded_payload['exp']) && $decoded_payload['exp'] > time()) {
            return $decoded_payload; // Valid
        }
    }
    return false; // Invalid or expired
}

function get_bearer_token() {
    $headers = null;
    if (isset($_SERVER['Authorization'])) {
        $headers = trim($_SERVER["Authorization"]);
    } else if (isset($_SERVER['HTTP_AUTHORIZATION'])) { // Nginx or fast CGI
        $headers = trim($_SERVER["HTTP_AUTHORIZATION"]);
    } elseif (function_exists('apache_request_headers')) {
        $requestHeaders = apache_request_headers();
        $requestHeaders = array_combine(array_map('ucwords', array_keys($requestHeaders)), array_values($requestHeaders));
        if (isset($requestHeaders['Authorization'])) {
            $headers = trim($requestHeaders['Authorization']);
        }
    }

    if (!empty($headers)) {
        if (preg_match('/Bearer\s(\S+)/', $headers, $matches)) {
            return $matches[1];
        }
    }
    return null;
}
?>
