#!/usr/bin/env bash
# Configure the existing iRonda installation as a Cloudflare Tunnel origin.
# Run on the Pi with: sudo bash configure-cloudflare-origin.sh
set -Eeuo pipefail
umask 077

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$EUID" -eq 0 ]] || fail 'Run this script with sudo bash.'
for command_name in apache2ctl a2enmod a2ensite a2dissite curl php ss mktemp; do
    command -v "$command_name" >/dev/null || fail "Missing command: $command_name"
done
[[ -f /etc/ironda/apache-env.conf && -d /srv/ironda/api/config ]] || fail 'The existing Pi migration must be installed first.'
[[ -f /etc/apache2/conf-enabled/ironda.conf ]] || fail 'The existing iRonda Apache configuration is not enabled.'
systemctl is-active --quiet apache2 || fail 'Apache must be running.'

origin_config=/etc/apache2/sites-available/ironda-tunnel.conf
[[ ! -e "$origin_config" && ! -L /etc/apache2/sites-enabled/ironda-tunnel.conf ]] || fail 'ironda-tunnel.conf already exists. Keep the existing configuration and share this message.'
[[ -z "$(ss -H -ltn 'sport = :8080')" ]] || fail 'Port 8080 is already in use. Share this message before continuing.'

dashboard_was_active=0
if systemctl is-active --quiet pi-dashboard; then dashboard_was_active=1; fi
work_dir="$(mktemp -d /tmp/ironda-tunnel-setup.XXXXXXXX)"
probe_file=''
origin_installed=0
success=0

cleanup() {
    result=$?
    trap - EXIT
    if [[ -n "$probe_file" ]]; then rm -f -- "$probe_file"; fi
    if [[ "$success" != 1 && "$origin_installed" == 1 ]]; then
        printf '%s\n' 'Removing the new tunnel configuration; preserving the existing LAN application.' >&2
        a2dissite ironda-tunnel >/dev/null 2>&1 || true
        rm -f -- "$origin_config"
        if apache2ctl configtest; then systemctl reload apache2 || true; fi
    fi
    rm -f -- "$work_dir/origin.conf" "$work_dir/response.json"
    rmdir -- "$work_dir" || true
    exit "$result"
}
trap cleanup EXIT

cat > "$work_dir/origin.conf" <<'APACHE'
# This listener is reachable only on the Pi. Cloudflared connects to it locally.
Listen 127.0.0.1:8080
<VirtualHost 127.0.0.1:8080>
    ServerName api.ironda.app
    ServerSignature Off
    DocumentRoot /srv/ironda/tunnel-empty

    RemoteIPHeader CF-Connecting-IP
    RemoteIPTrustedProxy 127.0.0.1

    ErrorLog ${APACHE_LOG_DIR}/ironda-tunnel-error.log
    CustomLog ${APACHE_LOG_DIR}/ironda-tunnel-access.log "%a %{c}a %t \"%r\" %>s"

    <Directory /srv/ironda/tunnel-empty>
        Require all denied
    </Directory>

    Alias /srs_api/ /srv/ironda/api/
    <Directory /srv/ironda/api>
        Options -Indexes -ExecCGI
        AllowOverride None
        # Authorize the actual connector, before its reported client IP.
        Require expr "%{CONN_REMOTE_ADDR} == '127.0.0.1'"
        Include /etc/ironda/apache-env.conf
        php_admin_flag display_errors Off
        php_admin_flag log_errors On
        php_admin_flag expose_php Off
        <FilesMatch "(^\.|\.(sql|log|bak|ini|env|sh|ps1|zip|tar|gz)$)">
            Require all denied
        </FilesMatch>
    </Directory>
    <Directory /srv/ironda/api/config>
        Require all denied
    </Directory>
    <Directory /srv/ironda/api/uploads>
        php_admin_flag engine Off
        <FilesMatch "(?i)^(?!.*\.(jpe?g|png|webp|gif)$)">
            Require all denied
        </FilesMatch>
    </Directory>
</VirtualHost>
APACHE

install -d -o root -g root -m 0755 /srv/ironda/tunnel-empty
a2enmod remoteip >/dev/null
install -o root -g root -m 0644 "$work_dir/origin.conf" "$origin_config"
origin_installed=1
a2ensite ironda-tunnel >/dev/null
apache2ctl configtest
systemctl reload apache2

origin=http://127.0.0.1:8080
curl_args=(--noproxy '*' --silent --show-error --max-time 15 -H 'Host: api.ironda.app')
curl "${curl_args[@]}" --fail -H 'CF-Connecting-IP: 203.0.113.27' \
    "$origin/srs_api/auth/get_locations.php?level=states" > "$work_dir/response.json"
php -r '$v=json_decode(file_get_contents($argv[1]),true); if (($v["status"]??null)!=="success" || !is_array($v["data"]??null) || count($v["data"])===0) {fwrite(STDERR,"Location/database check failed.\n"); exit(1);}' "$work_dir/response.json"

check_status() {
    expected="$1"
    request_url="$2"
    actual="$(curl "${curl_args[@]}" -H 'CF-Connecting-IP: 203.0.113.27' --output /dev/null --write-out '%{http_code}' "$request_url")"
    [[ "$actual" == "$expected" ]] || fail "Expected HTTP $expected, received $actual at $request_url"
}
check_status 401 "$origin/srs_api/auth/get_profile.php"
check_status 403 "$origin/srs_api/config/db_connect.php"
check_status 403 "$origin/"
check_status 403 "$origin/srs_api/uploads/blocked-test.php"
check_status 200 'http://127.0.0.1/srs_api/auth/get_locations.php?level=states'

sample_image="$(find /srv/ironda/api/uploads -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' \) -print -quit)"
[[ -n "$sample_image" ]] || fail 'No uploaded image found for the migration check.'
check_status 200 "$origin/srs_api/${sample_image#/srv/ironda/api/}"

# This short-lived probe returns no credentials and is removed by the EXIT trap.
probe_file="$(mktemp /srv/ironda/api/tunnel_probe_XXXXXXXX.php)"
printf '%s\n' '<?php header("Content-Type: application/json"); echo json_encode(["client_ip" => $_SERVER["REMOTE_ADDR"] ?? null]);' > "$probe_file"
chown root:www-data "$probe_file"
chmod 0640 "$probe_file"
for test_ip in 203.0.113.27 198.51.100.88 2001:db8::27; do
    curl "${curl_args[@]}" --fail -H "CF-Connecting-IP: $test_ip" \
        "$origin/srs_api/$(basename -- "$probe_file")" > "$work_dir/response.json"
    php -r '$v=json_decode(file_get_contents($argv[1]),true); if (($v["client_ip"]??null)!==$argv[2]) {fwrite(STDERR,"Forwarded client-address check failed.\n"); exit(1);}' "$work_dir/response.json" "$test_ip"
done
curl "${curl_args[@]}" --fail -H 'CF-Connecting-IP: 203.0.113.27' \
    "http://127.0.0.1/srs_api/$(basename -- "$probe_file")" > "$work_dir/response.json"
php -r '$v=json_decode(file_get_contents($argv[1]),true); if (($v["client_ip"]??null)!=="127.0.0.1") {fwrite(STDERR,"LAN listener unexpectedly trusts forwarded headers.\n"); exit(1);}' "$work_dir/response.json"

if [[ "$dashboard_was_active" == 1 ]]; then systemctl is-active --quiet pi-dashboard; fi
success=1
printf '%s\n' \
    'PASS: API, database, authentication requirement, private files and uploaded image.' \
    'PASS: Distinct forwarded client addresses; LAN requests do not trust that header.' \
    'PASS: Existing LAN API and dashboard service preserved.' \
    'Cloudflare origin is ready at http://127.0.0.1:8080.' \
    'Set the published application hostname to api.ironda.app and its service URL to http://127.0.0.1:8080.'
