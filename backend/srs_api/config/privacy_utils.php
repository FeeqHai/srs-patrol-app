<?php

function privacy_mask_ic_number($value) {
    $digits = preg_replace('/[^0-9]/', '', (string) $value);
    if (strlen($digits) < 4) {
        return '****';
    }
    return '******-**-' . substr($digits, -4);
}
