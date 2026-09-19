# PHP backend setup

This source is copied from the cPanel recovery package prepared on 8 September 2026, based on the 2 September database snapshot. It is not a fresh download of the running server. The configuration loader was made portable for this repository; the newer local account-validation changes listed in `docs/ACCOUNT_VALIDATION.md` and the current patroller-list implementation are included to match the Flutter app. Runtime secrets still come only from private settings.

1. Use PHP 8.2 with mysqli/mysqlnd and fileinfo, MariaDB, and Apache with the supplied `.htaccess` files enabled.
2. Create a new empty database and import `../database/schema.sql`. This contains no location, account, patrol or other records. Provision your own location hierarchy and administrator securely before using registration; no default administrator credentials are supplied. The schema already includes the historical migrations, so do not reapply old migrations blindly.
3. Copy `settings.example.php` to `backend/private/settings.php`, or set `SRS_SETTINGS_PATH` to an absolute private settings file. Keep this file outside the web document root. Replace all example values and generate separate random signing and verification secrets of at least 32 characters.
4. Serve only `backend/srs_api/` at `/srs_api/`, retaining its `.htaccess` and `.user.ini` files. Do not serve the repository root. If you relocate the API, set `SRS_SETTINGS_PATH` explicitly.
5. Give the PHP process write access to the uploads directory as needed. Uploaded records are not included. Configure HTTPS and point the app at the new API URL.
6. Check the location endpoint, unauthenticated profile rejection and denial of direct `config/` access before testing authenticated workflows.

The `tests/` folder contains CLI unit tests and denies web access. Run `php backend/srs_api/tests/registration_verification_unit.php` from the repository root with private settings configured; it uses the verification pepper but does not connect to the database. Use separate test settings, not production secrets.

Existing Pi/cPanel installations have their own configuration paths and keys. This repository packaging does not deploy to or alter them.
