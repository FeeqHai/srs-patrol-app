# Final submission packaging — 19 September 2026

The submission includes the Flutter source, PHP backend, schema-only database setup, test scripts, setup instructions and the user-selected `B032410536_iRonda_corrected_final_student_signed.pdf`. The report was copied without modification and its SHA-256 matched the original.

Backend provenance and configuration differences are documented in `backend/README.md`. The database schema contains 16 tables from the snapshot used for the cPanel recovery package; it is not a fresh live-server export. No raw database records, credentials or uploaded images are included.

## Checks completed

- Flutter tests: 62 passed.
- Flutter analysis: no issues found.
- PHP syntax: all 56 API/test PHP files passed.
- PHP account validation: 63 assertions passed.
- PHP verification/privacy: 7 assertions passed using local dummy settings.
- Offline load-test harness: passed; all HTTP requests mocked.
- Staged whitespace check: passed.
- Credential-pattern review: flagged only test/example values. Private settings and uploaded files are excluded.

Live deployment, database restore, device acceptance and live load tests were not repeated for this packaging step. Android release signing still uses the debug configuration; this submission tag is a source archive, not a production-signed app release.

Old diagnostic outputs and development patch archives were removed from the current Git tree while retaining their local copies. Historical commits are unchanged. Unused FaceNet assets and local MyKad image samples are excluded; the application and automated tests do not reference them.
