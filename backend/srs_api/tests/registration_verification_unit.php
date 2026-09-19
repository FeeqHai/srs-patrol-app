<?php
require_once __DIR__ . '/../config/registration_verification.php';
require_once __DIR__ . '/../config/privacy_utils.php';

function assert_same($expected, $actual, $name) {
    if ($expected !== $actual) {
        fwrite(STDERR, "FAIL {$name}: expected " . var_export($expected, true)
            . ', got ' . var_export($actual, true) . PHP_EOL);
        exit(1);
    }
    echo "PASS {$name}" . PHP_EOL;
}

assert_same('900101045678', verification_normalize_ic('900101-04-5678'), 'normalize_ic');
assert_same(true, verification_is_valid_ic('900101045678'), 'valid_ic');
assert_same(false, verification_is_valid_ic('90010104567'), 'short_ic_rejected');
assert_same(64, strlen(verification_hash('device-fixture')), 'hmac_hash_length');
assert_same('******-**-5678', privacy_mask_ic_number('900101-04-5678'), 'mask_formatted_ic');
assert_same('******-**-5678', privacy_mask_ic_number('900101045678'), 'mask_plain_ic');
assert_same('****', privacy_mask_ic_number(''), 'mask_missing_ic');
