# Account validation

Updated: 2026-09-03.

The Flutter app and local PHP backend now share the following account rules:

| Field | Rule |
| --- | --- |
| New password | Required; at least 8 Unicode characters; no control characters; at most 72 UTF-8 bytes to avoid bcrypt truncation. Spaces are preserved exactly. |
| Confirm password | Required and must match exactly, including spaces. |
| Phone number | Accept a local number beginning with `0`, or a `+60`/`60` country code. Spaces and hyphens are allowed. Store local format with 9–11 digits and a nonzero second digit. |
| MyKad | Exactly 12 digits, optionally grouped as `YYMMDD-XX-NNNN` or with spaces. Reject letters and impossible dates, including invalid leap days. Store digits only. |

Phone validation is a basic format check, not a carrier or ownership check. MyKad
date validation does not infer age or replace the existing identity approval.
The two-digit year is checked using 2000–2099, so year `00` permits February 29.
Password complexity requirements beyond the existing eight-character minimum
have not been introduced. Existing login passwords are not checked against new
password length rules.

Registration, password changes and member profile editing show field errors in
English or Bahasa Melayu. Structured HTTP 4xx errors retain the server's message,
including an incorrect current password. Failed registration with a missing
message cannot be mistaken for success. Duplicate IC/email database failures are
returned as JSON errors. HTML failures and server failures display a generic
connection message in account forms.

## Implementation

- Flutter rules: `lib/core/utils/account_validation.dart`.
- PHP rules: `C:\xampp\htdocs\srs_api\config\account_validation.php`.
- MyKad extraction uses the same date checks as account forms.
- Passwords are no longer trimmed in registration, login, password change or
  administrator reset requests.

## Validation

Flutter checks cover field rules, normalization, error messages, password
confirmation, password preservation and the existing member dialog lifecycle.
The PHP unit test covers the same accepted and rejected formats. The local API
test uses randomly named accounts, exercises registration/profile/password
endpoints and removes its account and verification-session fixtures afterward.

Verified locally: 61 Flutter tests, 63 account-validation PHP assertions,
7 existing verification/privacy assertions, and 31 API integration checks passed.

From the Flutter project:

```powershell
flutter test test/features/auth test/features/post test/core
```

From `C:\xampp\htdocs\srs_api`:

```powershell
& C:\xampp\php\php.exe tests/account_validation_unit.php
& C:\xampp\php\php.exe tests/registration_verification_unit.php
& C:\xampp\php\php.exe tests/account_validation_integration.php
```

## Raspberry Pi rollout

These changes were applied and tested locally. The Pi deployment and installed
Android application have not been updated by this task. Deploy the following
PHP files together, preserving their directories, and rebuild the Flutter app:

- `config/account_validation.php` (new dependency)
- `config/registration_verification.php`
- `auth/register.php`
- `auth/login.php`
- `auth/change_password.php`
- `auth/verification/start.php`
- `admin/update_user.php`

No database schema change is required. Deploy the app and backend together so
passwords containing spaces are handled consistently throughout the flow.
