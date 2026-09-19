<?php
require_once __DIR__ . '/../config/account_validation.php';

$checks = 0;
function check($condition, $label) {
    global $checks;
    if (!$condition) {
        fwrite(STDERR, "FAIL $label\n");
        exit(1);
    }
    $checks++;
}

foreach ([null, [], '', '        ', 'short', 'éééé', "password\n", "password\0", str_repeat('a', 73), str_repeat('é', 37)] as $value) {
    check(account_password_error($value) !== null, 'invalid password rejected');
}
foreach (['abcdefgh', 'P@ssword1', ' pass word ', 'éééééééé', str_repeat('a', 72), str_repeat('é', 36)] as $value) {
    check(account_password_error($value) === null, 'valid password accepted');
}
check(account_string(' pass word ') === ' pass word ', 'password spaces preserved');
foreach (['0123456789' => '0123456789', '01112345678' => '01112345678',
    '03-1234 5678' => '0312345678', '04-1234567' => '041234567',
    ' +60 12-345 6789 ' => '0123456789', '60123456789' => '0123456789'] as $value => $expected) {
    // Numeric array keys are converted to integers by PHP.
    $value = (string) $value;
    check(account_phone_error($value) === null, 'valid phone accepted');
    check(account_normalize_phone($value) === $expected, 'phone normalized');
}
foreach ([null, [], '', '01234', '012345678901', '012abc3456789', '0012345678',
    '+600123456789', '1234567890', '+6512345678', '012.3456789', "0123456789\n0", '٠١٢٣٤٥٦٧٨٩'] as $value) {
    check(account_phone_error($value) !== null, 'invalid phone rejected');
}
foreach (['900101045678', '900101-04-5678', ' 900101 04 5678 '] as $value) {
    check(account_ic_error($value) === null, 'valid IC accepted');
    check(account_normalize_ic($value) === '900101045678', 'IC normalized');
}
foreach ([null, [], '', '90010104567', '9001010456789', 'IC900101045678',
    '900101x04x5678', '90010-104-5678', '901301045678', '900100045678',
    '900431045678', '010229045678', '000000000000'] as $value) {
    check(account_ic_error($value) !== null, 'invalid IC rejected');
}
check(account_ic_error('000229045678') === null, 'year 00 leap day accepted');
check(account_ic_error('040229045678') === null, 'leap day accepted');
echo "PASS $checks account validation checks\n";
