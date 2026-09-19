# Raspberry Pi deployment

Updated: 2026-09-03. Status: migration and local-network checks passed; `ironda.app` activated on Cloudflare; the user reports the tunnel is Connected/Healthy. The published application route has been created and public HTTPS API, authentication-boundary, private-configuration and image checks passed using fresh DNS. Mobile-data/full application testing and the lecturer's APK remain pending.

## Selected source and current destination

The user selected the current local XAMPP `srs_db` database because it contains the latest adjustments. DigitalOcean is no longer the intended demonstration host. Its older deployment notes are historical and must not trigger automatic deployment there.

- Source backend: `C:\xampp\htdocs\srs_api`.
- Source database at export: MariaDB 10.4.32, `srs_db`, 16 tables.
- Pi: Debian 12, arm64, local address `192.168.1.120`, user `syahmi`.
- Pi runtime reported by the user: Apache 2.4.68, PHP 8.2.33, MariaDB 10.11.18.
- Pi API files: `/srv/ironda/api`, served at `/srs_api/`.
- Pi database: `srs_db`; application account: `ironda_app` at localhost, with SELECT, INSERT, UPDATE and DELETE permissions.
- Private runtime configuration: `/etc/ironda/apache-env.conf`, root-only access.
- Apache application configuration: `/etc/apache2/conf-available/ironda.conf`.

The Pi is connected to the user's home internet. On 2026-09-03, the user provided Name.com's successful order confirmation for `ironda.app`, with domain registration and Domain Safe totaling $0.00. The public HTTPS plan is now the custom domain with Cloudflare Tunnel. Tailscale Funnel was considered before the student domain offer was found and has not been installed or enabled for this deployment.

The original Apache LAN configuration allows loopback and private IPv4 networks. The public API address is **`https://api.ironda.app/srs_api/`**. The user supplied Cloudflare's activation screen after changing the nameservers to the assigned pair, `daisy.ns.cloudflare.com` and `lennon.ns.cloudflare.com`. Registration remains with Name.com. No registry DNSSEC record was present during migration; the registrar's DNSSEC page also confirmed this.

Cloudflared installation initially failed with `NO_PUBKEY`. Refreshing the official `https://pkg.cloudflare.com/cloudflare-main.gpg` key and setting file mode 0644 resolved the installation, according to the user. The user subsequently confirmed that Connection Status shows Connected/Healthy after installing the service. The tunnel token stays private on the user's machine and Pi.

## Cloudflare origin setup

The prepared script is `deploy/raspberry-pi/configure-cloudflare-origin.sh` in the Flutter project. Transfer it to the Pi and run it with `sudo bash`. It configures a new Apache listener at **127.0.0.1:8080**, serving `/srs_api/` from the existing installation. It preserves the existing port-80 LAN configuration, application files, database and private runtime secrets.

The dedicated virtual host trusts `CF-Connecting-IP` only from the local connector and uses the actual connection address for its access rule. This restores the client's address in PHP's `REMOTE_ADDR` without making the existing private-address rule reject Internet users or trusting forwarded headers on the LAN listener. The document root, private configuration, backup files and executable uploads remain blocked. On setup failure, the script removes its newly installed virtual host and reloads the existing configuration.

The script performs Pi-side API/database, authentication, configuration-denial, uploaded-image, distinct forwarded-client-address and existing-service checks. Its Bash syntax passed locally. An isolated local Apache/PHP fixture using the actual generated virtual-host configuration passed IPv4/IPv6 address restoration, LAN header isolation, private-path rejection and image access. This fixture did not connect to a database and does not replace the Pi-side checks.

The route settings supplied to the user are:

| Field | Value |
| --- | --- |
| Subdomain | `api` |
| Domain | `ironda.app` |
| Path filter | Leave empty |
| Service URL | `http://127.0.0.1:8080` |

If the form separates type and address, choose HTTP and enter `127.0.0.1:8080`. Do not append `/srs_api/` to the origin address: the incoming URL path is preserved. The dashboard creates the DNS record for the published hostname. Verify `https://api.ironda.app/srs_api/auth/get_locations.php?level=states`, then HTTP 401 for an unauthenticated profile request, HTTP 403 for private configuration access and image retrieval before building the release APK.

The user's route-success screenshot confirms a published application for `api.ironda.app` and its CNAME target `e4f9440e-cbd7-4446-845f-a8966a20750e.cfargotunnel.com`. The target identifies the tunnel and is not its secret token. The screenshot does not display the local service URL; the Pi setup script's PASS output has not been supplied in chat.

### Public HTTPS verification on 2026-09-03

The Windows system resolver initially returned the former parking IP, `91.195.240.94`, causing a TLS handshake failure. A fresh Cloudflare DNS-over-HTTPS lookup returned `172.67.184.95` and `104.21.19.7`. Requests using `curl --resolve` with the first current address and normal TLS certificate/hostname verification passed:

- Location endpoint: HTTP 200, JSON `status: success`, Johor and Melaka.
- Profile without a token: HTTP 401.
- Direct `config/db_connect.php`: HTTP 403.
- Sample uploaded incident image: HTTP 200.

The response was served by Cloudflare with `cf-cache-status: DYNAMIC`. These addresses were temporary diagnostic inputs only; do not hard-code them in the app or DNS configuration. Clients with cached parking records may need to wait for expiry or use a fresh resolver. These results do not establish mobile-data reachability or complete authenticated application acceptance.

## Migration package and changes

Package: `C:\Users\rafee\Documents\UTeM\FYP\local_backups\raspberry_pi\20260902_232047\ironda-pi-migration.tar.gz`.

The package contains 52 PHP files, 38 uploaded images and the selected SQL snapshot. Developer tests, old backups, migration scripts and Git metadata are excluded from the served application. The original SQL snapshot and installer stay outside the web application.

Nine stored image URLs referring to `192.168.1.109` were converted to portable upload paths in the Pi database. The original local database was not changed. The Pi generates its own database password, JWT signing key and registration pepper. Existing local login tokens do not work on the Pi; users must sign in again.

Only the packaged `config/jwt_utils.php` was changed to require `SRS_JWT_SECRET`, rejecting missing or short values. The local XAMPP file still uses its original development key. Future deployments must preserve the Pi's environment-based signing configuration; copying that local file verbatim would undo this deployment change.

Keep the package private because it contains account records, password hashes and uploaded images. Future server backups must include the database, uploads and `/etc/ironda`.

## Verification evidence

Preparation checks on Windows passed: PHP lint for all 52 files; installer Bash syntax; archive file checksums; signing and verification with a configured key; rejection of a missing key and a tampered token. A disposable local database restore matched all 16 table row counts, and the image-path updates preserved those counts. Local source file hashes and database row counts remained unchanged.

The user ran the installer on the Pi and provided successful output for:

- Import and exact row-count comparison across all 16 tables.
- PHP execution through Apache and application database access.
- Location API response.
- Unauthenticated profile rejection and blocked direct configuration access.
- Uploaded image retrieval and the existing dashboard service check.

Independent requests from this Windows computer to `192.168.1.120` also passed: the location API returned `status: success`; an unauthenticated profile request returned HTTP 401; direct access to `config/db_connect.php` returned HTTP 403.

Apache emitted AH00558 because no global ServerName is configured. Configuration validation returned `Syntax OK`, reload succeeded, and the API checks passed. Set the appropriate name when configuring the final public host.

## Remaining work

Local XAMPP and Pi development launch profiles are now configured in
`.vscode/launch.json`; see [Development environments](DEVELOPMENT_ENVIRONMENTS.md).
Both location APIs passed a read-only check on 2026-09-03, including the public Pi
hostname using ordinary DNS and TLS validation. Device launches and login remain
to be checked.

1. Retain the Pi setup script's PASS output to document its origin/client-address checks. The public route and baseline HTTPS checks have passed.
2. Verify access from mobile data. Ordinary DNS resolution and HTTPS access now pass on the Windows laptop.
3. Verify application workflows, including authentication, registration, approval, patrol operations and images.
4. Configure private Android release signing. `android/app/build.gradle.kts` currently uses the debug signing configuration for release.
5. Build and test the APK with the final HTTPS `SRS_API_BASE_URL`. The app's current default remains the old DigitalOcean hostname, and release builds reject cleartext HTTP.
6. Verify reboot recovery and a server backup restore; collect system, load and user-acceptance test evidence separately. The deployment checks above do not establish concurrent-user capacity or complete application acceptance.
