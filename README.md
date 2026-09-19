# iRonda

Flutter mobile application for KRT/SRS patrol operations, developed as a UTeM final-year project. Includes registration, account approval, patrol scheduling, QR attendance, incident reporting, SOS, equipment records and reports.

## Repository contents

- `lib/`, `assets/`, platform folders: Flutter application.
- `backend/srs_api/`: PHP API from the 8 September 2026 cPanel recovery package; uploaded files and private configuration excluded.
- `database/schema.sql`: 16-table schema from the database snapshot used by that package, with no records.
- `test/`: Flutter automated tests.
- `Testing/`: functional, performance and user-acceptance protocols.
- `load-tests/`: k6 scripts and an offline verification harness; account entries are demonstration fixtures, with no passwords.
- `docs/report/`: approved signed final report.
- `docs/`: project documentation. Dated deployment notes describe historical environments; use the backend instructions below for this packaged source.

## Run the app

Install Flutter compatible with `pubspec.yaml`, then run:

```sh
flutter pub get
flutter test
flutter run --dart-define=SRS_API_BASE_URL=https://your-api.example/srs_api/
```

The source defaults to the project's public demonstration API. Use your own backend for development and tests that create records. Configure the platform permissions and HTTPS appropriate to your device. Android release builds currently use debug signing: configure private release signing before distributing a production build.

## Backend and database

See [backend setup](backend/README.md). Raw database backups, server credentials, uploaded user images, report drafts and generated test output are intentionally kept outside this repository.

## Verification

```sh
flutter test --no-pub
flutter analyze --no-pub
php backend/srs_api/tests/account_validation_unit.php
node --experimental-vm-modules load-tests/offline-check.mjs
```

The registration-verification PHP unit test additionally needs private settings (see backend setup). Offline checks do not establish live server capacity, device camera/GPS behavior or user acceptance. Run live load/write tests only against prepared test accounts and data as described in `load-tests/README.md`.
