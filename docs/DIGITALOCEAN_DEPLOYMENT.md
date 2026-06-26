|  |  |  |
| - | - | - |

# DigitalOcean Demo Runtime

This project now treats DigitalOcean as the production/demo source of truth.
XAMPP is only a local development or staging copy.

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
