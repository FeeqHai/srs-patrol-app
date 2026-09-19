<?php

// Keep these rules and messages in sync with AccountValidation in the app.
function account_string($value) {
    return is_string($value) ? $value : '';
}

function account_password_error($value) {
    if (!is_string($value) || preg_match('/\A\s*\z/u', $value) === 1) {
        return 'Ruangan ini wajib diisi';
    }
    if (preg_match('/[\x00-\x1F\x7F]/', $value)) {
        return 'Kata laluan tidak boleh mengandungi aksara kawalan.';
    }
    $length = preg_match_all('/./us', $value);
    if ($length === false) {
        return 'Kata laluan mengandungi aksara tidak sah.';
    }
    if ($length < 8) {
        return 'Kata laluan mesti sekurang-kurangnya 8 aksara.';
    }
    // bcrypt only covers the first 72 bytes; reject instead of truncating.
    if (strlen($value) > 72) {
        return 'Kata laluan terlalu panjang. Sila gunakan kurang aksara.';
    }
    return null;
}

function account_normalize_phone($value) {
    $compact = str_replace([' ', '-'], '', trim(account_string($value)));
    if (strpos($compact, '+60') === 0) return '0' . substr($compact, 3);
    if (strpos($compact, '60') === 0) return '0' . substr($compact, 2);
    return $compact;
}

function account_phone_error($value) {
    $value = trim(account_string($value));
    if ($value === '') return 'Ruangan ini wajib diisi';
    if (preg_match('/\A(?:\+?60|0)[0-9 -]+\z/', $value) !== 1
        || preg_match('/\A0[1-9][0-9]{7,9}\z/', account_normalize_phone($value)) !== 1) {
        return 'Masukkan nombor telefon yang sah bermula dengan 0 atau +60 (9 hingga 11 digit dalam format tempatan).';
    }
    return null;
}

function account_normalize_ic($value) {
    $value = trim(account_string($value));
    if (preg_match('/\A[0-9]{6}[ -]?[0-9]{2}[ -]?[0-9]{4}\z/', $value) !== 1) {
        return $value;
    }
    return str_replace([' ', '-'], '', $value);
}

function account_ic_error($value) {
    $value = account_normalize_ic($value);
    if ($value === '') return 'Ruangan ini wajib diisi';
    if (preg_match('/\A[0-9]{12}\z/', $value) !== 1) {
        return 'Nombor MyKad mesti mengandungi 12 digit.';
    }
    // Validate the calendar date, without inferring age from the two-digit year.
    if (!checkdate((int) substr($value, 2, 2), (int) substr($value, 4, 2), 2000 + (int) substr($value, 0, 2))) {
        return 'Tarikh lahir dalam nombor MyKad tidak sah.';
    }
    return null;
}
