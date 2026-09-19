|  |  |  |
| - | - | - |

# DigitalOcean Demo Runtime

Historical reference, superseded on 2026-09-02 by `RASPBERRY_PI_DEPLOYMENT.md`.
The user selected the latest local XAMPP database for migration to the Raspberry Pi.
The Pi migration and local-network API checks have passed; public HTTPS and the
release APK remain pending. The instructions below describe the previous setup
and are not authorization to deploy changes to DigitalOcean.

## Flutter API Base URL

Default API base:

```text
http://157.245.53.82/srs_api/
```

Run against DigitalOcean:

```powershell
flutter run --dart-define=SRS_API_BASE_URL=http://157.245.53.82/srs_api/
```

Run against local XAMPP only when explicitly testing local backend changes:

```powershell
flutter run --dart-define=SRS_API_BASE_URL=http://<laptop-ip>/srs_api/
```

## Backend Locations

Local backend copy:

```text
C:\xampp\htdocs\srs_api
```

DigitalOcean backend:

```text
/var/www/html/srs_api
```

For any PHP backend fix:

1. Update the local source file under `C:\xampp\htdocs\srs_api`.
2. Deploy the same file to `/var/www/html/srs_api` on DigitalOcean.
3. Run PHP lint on the server.
4. Verify against the DigitalOcean API, not only localhost.

Do not copy the backend document root indiscriminately. Developer-only content
must remain outside the deployed web application, including:

```text
tests/
migrations/
backups/
local test assets
```

When deploying the full backend from WSL or another environment with `rsync`,
use explicit exclusions:

```bash
rsync -av \
  --exclude 'tests/' \
  --exclude 'migrations/' \
  --exclude 'backups/' \
  /mnt/c/xampp/htdocs/srs_api/ \
  root@157.245.53.82:/var/www/html/srs_api/
```

The local `tests/.htaccess` is an additional safeguard, not a replacement for
excluding developer tests from the production deployment.

Example deploy:

```powershell
scp "C:\xampp\htdocs\srs_api\auth\upload_profile_image.php" root@157.245.53.82:/var/www/html/srs_api/auth/
```

Example server verification:

```bash
chown www-data:www-data /var/www/html/srs_api/auth/upload_profile_image.php
chmod 755 /var/www/html/srs_api/auth/upload_profile_image.php
php -l /var/www/html/srs_api/auth/upload_profile_image.php
tail -n 100 /var/log/apache2/error.log
```

## Database

Production database:

```text
srs_db
```

The production MySQL/MariaDB server runs locally on the droplet. Use an SSH
tunnel for tools such as MySQL Workbench.

Before production SQL migrations:

```bash
mysqldump srs_db > /root/srs_db_backup_before_change.sql
```

Run production SQL on the droplet:

```bash
mysql srs_db -e "SELECT NOW();"
```

Do not expose or hardcode database passwords.

## Timezone

DigitalOcean server time and MySQL time are UTC. Malaysia display time is UTC+8.
For Today/Archive and dashboard buckets, avoid comparing raw UTC timestamps
directly against Malaysia calendar dates. Prefer app-side Malaysia time helpers
or SQL conversion such as:

```sql
CONVERT_TZ(created_at, '+00:00', '+08:00')
```

## Upload Paths

Server upload root:

```text
/var/www/html/srs_api/uploads
```

Profile pictures:

```text
/var/www/html/srs_api/uploads/profile_pictures
```

Incident images:

```text
/var/www/html/srs_api/uploads/incidents
```

Recommended ownership:

```bash
chown -R www-data:www-data /var/www/html/srs_api/uploads
chmod -R 775 /var/www/html/srs_api/uploads
```
